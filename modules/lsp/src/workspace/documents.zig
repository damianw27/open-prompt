const std = @import("std");
const util = @import("../util.zig");
const parser_tree = @import("../parser/tree.zig");
const ast = @import("../parser/ast.zig");
const config = @import("../config.zig");
const scope_mod = @import("../semantic/scope.zig");
const includes = @import("../semantic/includes.zig");
const diagnostics = @import("../semantic/diagnostics.zig");
const host = @import("../host/root.zig");

pub const DocumentState = struct {
    uri: []const u8,
    version: i32,
    parsed: parser_tree.ParsedDocument,
    scope: scope_mod.Scope,
    host_symbols: []scope_mod.Symbol,

    pub fn deinit(self: *DocumentState, allocator: std.mem.Allocator) void {
        allocator.free(self.uri);
        self.parsed.deinit(allocator);
        self.scope.deinit(allocator);
        for (self.host_symbols) |symbol| {
            allocator.free(symbol.name);
            if (symbol.detail) |detail| allocator.free(detail);
            if (symbol.source_uri) |uri| allocator.free(uri);
        }
        allocator.free(self.host_symbols);
        self.* = undefined;
    }
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    parser: parser_tree.Parser,
    documents: std.StringHashMapUnmanaged(*DocumentState),
    index: includes.Index,
    config: config.Config,
    host_registry: host.Registry,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !Store {
        return .{
            .allocator = allocator,
            .io = io,
            .parser = try parser_tree.Parser.init(),
            .documents = .empty,
            .index = includes.Index.init(allocator),
            .config = config.Config.init(allocator),
            .host_registry = host.Registry.init(allocator),
        };
    }

    pub fn deinit(self: *Store) void {
        var iterator = self.documents.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.documents.deinit(self.allocator);
        self.index.deinit(self.allocator);
        self.config.deinit(self.allocator);
        self.host_registry.deinit();
        self.parser.deinit();
        self.* = undefined;
    }

    pub fn setWorkspaceRoots(self: *Store, roots: []const []const u8) !void {
        try self.index.rebuild(self.allocator, self.io, roots);
    }

    pub fn openDocument(self: *Store, uri: []const u8, text: []const u8, version: i32) !void {
        try self.closeDocument(uri);

        var parsed = try self.parser.parse(self.allocator, text, null);
        errdefer parsed.deinit(self.allocator);

        var scope = try scope_mod.buildDocumentScope(self.allocator, &parsed.ast);
        errdefer scope.deinit(self.allocator);

        const host_symbols = try self.loadHostSymbols(&parsed.ast, uri);
        errdefer {
            for (host_symbols) |symbol| {
                self.allocator.free(symbol.name);
                if (symbol.detail) |detail| self.allocator.free(detail);
                if (symbol.source_uri) |source_uri| self.allocator.free(source_uri);
            }
            self.allocator.free(host_symbols);
        }
        try self.mergeUseExports(&scope, uri, &parsed.ast);
        try scope_mod.mergeHostSymbols(self.allocator, &scope, host_symbols);

        const state = try self.allocator.create(DocumentState);
        errdefer self.allocator.destroy(state);

        state.* = .{
            .uri = try self.allocator.dupe(u8, uri),
            .version = version,
            .parsed = parsed,
            .scope = scope,
            .host_symbols = host_symbols,
        };

        const key = try self.allocator.dupe(u8, uri);
        errdefer self.allocator.free(key);
        try self.documents.put(self.allocator, key, state);
    }

    pub fn updateDocument(self: *Store, uri: []const u8, text: []const u8, version: i32) !void {
        if (self.documents.get(uri)) |state| {
            var parsed = try self.parser.parse(self.allocator, text, state.parsed.tree);
            errdefer {
                parsed.tree.destroy();
                parsed.ast.deinit(self.allocator);
                self.allocator.free(parsed.source);
            }

            state.parsed.tree.destroy();
            state.parsed.ast.deinit(self.allocator);
            self.allocator.free(state.parsed.source);
            state.scope.deinit(self.allocator);
            for (state.host_symbols) |symbol| {
                if (symbol.detail) |detail| self.allocator.free(detail);
                if (symbol.source_uri) |source_uri| self.allocator.free(source_uri);
                self.allocator.free(symbol.name);
            }
            self.allocator.free(state.host_symbols);

            state.parsed = parsed;
            state.version = version;
            state.scope = try scope_mod.buildDocumentScope(self.allocator, &state.parsed.ast);
            state.host_symbols = try self.loadHostSymbols(&state.parsed.ast, uri);
            try self.mergeUseExports(&state.scope, uri, &state.parsed.ast);
            try scope_mod.mergeHostSymbols(self.allocator, &state.scope, state.host_symbols);
            return;
        }

        try self.openDocument(uri, text, version);
    }

    pub fn closeDocument(self: *Store, uri: []const u8) !void {
        const removed = self.documents.fetchRemove(uri) orelse return;
        removed.value.deinit(self.allocator);
        self.allocator.destroy(removed.value);
        self.allocator.free(removed.key);
    }

    pub fn get(self: *Store, uri: []const u8) ?*DocumentState {
        return self.documents.get(uri);
    }

    pub fn diagnosticsFor(self: *Store, uri: []const u8) ![]diagnostics.Diagnostic {
        const state = self.get(uri) orelse return &[_]diagnostics.Diagnostic{};
        return diagnostics.collect(self.allocator, &state.parsed.ast, &state.scope, &self.index, uri);
    }

    fn loadHostSymbols(self: *Store, document: *const ast.Document, uri: []const u8) ![]scope_mod.Symbol {
        if (!self.config.host_context_enabled) {
            return &[_]scope_mod.Symbol{};
        }

        var paths: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (paths.items) |path| self.allocator.free(path);
            paths.deinit(self.allocator);
        }

        for (document.context_paths) |path| {
            try paths.append(self.allocator, path);
        }

        for (self.config.contextPathsForUri(uri)) |path| {
            try paths.append(self.allocator, try self.allocator.dupe(u8, path));
        }

        return try self.host_registry.extractFromPaths(self.allocator, self.io, uri, paths.items);
    }

    pub fn documentAst(self: *Store, uri: []const u8) ?*const ast.Document {
        if (self.get(uri)) |state| {
            return &state.parsed.ast;
        }

        return null;
    }

    pub fn parseIncludedFile(self: *Store, uri: []const u8) !parser_tree.ParsedDocument {
        return self.parseUri(uri);
    }

    fn parseUri(self: *Store, uri: []const u8) !parser_tree.ParsedDocument {
        const path = try util.pathFromFileUri(self.allocator, uri);
        defer self.allocator.free(path);

        const source = try std.Io.Dir.cwd().readFileAlloc(
            self.io,
            path,
            self.allocator,
            std.Io.Limit.limited(1024 * 1024),
        );
        defer self.allocator.free(source);

        return try self.parser.parse(self.allocator, source, null);
    }

    fn mergeUseExports(
        self: *Store,
        scope: *scope_mod.Scope,
        current_uri: []const u8,
        document: *const ast.Document,
    ) !void {
        for (document.uses) |use_item| {
            const resolved = try includes.resolveInclude(&self.index, self.allocator, current_uri, use_item.path) orelse continue;
            defer {
                self.allocator.free(resolved.uri);
                self.allocator.free(resolved.path);
            }

            if (self.get(resolved.uri)) |state| {
                try appendUseExports(self.allocator, scope, use_item, resolved.uri, &state.parsed.ast);
            } else {
                var parsed = self.parseUri(resolved.uri) catch continue;
                defer parsed.deinit(self.allocator);
                try appendUseExports(self.allocator, scope, use_item, resolved.uri, &parsed.ast);
            }
        }
    }
};

fn appendUseExports(
    allocator: std.mem.Allocator,
    scope: *scope_mod.Scope,
    use_item: ast.UseDirective,
    included_uri: []const u8,
    included: *const ast.Document,
) !void {
    for (included.templates) |template| {
        const symbol_name = try std.fmt.allocPrint(
            allocator,
            "{s}.{s}",
            .{ use_item.alias, template.name },
        );
        errdefer allocator.free(symbol_name);

        try scope.insert(allocator, .{
            .name = symbol_name,
            .kind = .template_export,
            .detail = try std.fmt.allocPrint(
                allocator,
                "template '{s}' from {s}",
                .{ template.name, use_item.path },
            ),
            .source_uri = try allocator.dupe(u8, included_uri),
            .range = template.range,
        });
    }
}
