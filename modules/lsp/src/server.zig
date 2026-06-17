const std = @import("std");
const lsp = @import("lsp");
const workspace = @import("workspace/root.zig");
const features = @import("features/root.zig");
const util = @import("util.zig");

pub const Server = struct {
    allocator: std.mem.Allocator,
    store: workspace.Store,
    offset_encoding: lsp.offsets.Encoding = .@"utf-16",
    workspace_roots: []const []const u8,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !Server {
        return .{
            .allocator = allocator,
            .store = try workspace.Store.init(allocator, io),
            .workspace_roots = &.{},
        };
    }

    pub fn deinit(self: *Server) void {
        for (self.workspace_roots) |root| {
            self.allocator.free(root);
        }
        self.allocator.free(self.workspace_roots);
        self.store.deinit();
        self.* = undefined;
    }

    pub fn initialize(
        self: *Server,
        arena: std.mem.Allocator,
        request: lsp.types.InitializeParams,
    ) lsp.types.InitializeResult {
        _ = arena;

        if (request.capabilities.general) |general| {
            for (general.positionEncodings orelse &.{}) |encoding| {
                self.offset_encoding = switch (encoding) {
                    .@"utf-8" => .@"utf-8",
                    .@"utf-16" => .@"utf-16",
                    .@"utf-32" => .@"utf-32",
                    .custom_value => continue,
                };
                break;
            }
        }

        if (request.workspaceFolders) |folders| {
            var roots: std.ArrayList([]const u8) = .empty;
            for (folders) |folder| {
                const path = util.pathFromFileUri(self.allocator, folder.uri) catch continue;
                roots.append(self.allocator, path) catch {
                    self.allocator.free(path);
                    continue;
                };
            }
            self.workspace_roots = roots.toOwnedSlice(self.allocator) catch &[_][]const u8{};
            self.store.setWorkspaceRoots(self.workspace_roots) catch {};
        } else if (request.rootUri) |root_uri| {
            if (util.pathFromFileUri(self.allocator, root_uri)) |path| {
                if (self.allocator.alloc([]const u8, 1)) |roots_slice| {
                    roots_slice[0] = path;
                    self.workspace_roots = roots_slice;
                    self.store.setWorkspaceRoots(self.workspace_roots) catch {};
                } else |_| {
                    self.allocator.free(path);
                }
            } else |_| {}
        }

        if (request.initializationOptions) |options| {
            self.store.config.applySettings(self.allocator, options) catch {};
        }

        const capabilities: lsp.types.ServerCapabilities = .{
            .positionEncoding = switch (self.offset_encoding) {
                .@"utf-8" => .@"utf-8",
                .@"utf-16" => .@"utf-16",
                .@"utf-32" => .@"utf-32",
            },
            .textDocumentSync = .{
                .text_document_sync_options = .{
                    .openClose = true,
                    .change = .Incremental,
                },
            },
            .completionProvider = .{
                .triggerCharacters = &.{ "$", ".", "\"", "'", "[", "@" },
            },
            .hoverProvider = .{ .bool = true },
            .definitionProvider = .{ .bool = true },
            .referencesProvider = .{ .bool = true },
            .renameProvider = .{ .bool = true },
            .documentSymbolProvider = .{ .bool = true },
            .workspaceSymbolProvider = .{ .bool = true },
            .semanticTokensProvider = .{
                .semantic_tokens_options = .{
                    .legend = .{
                        .tokenTypes = &features.semantic_tokens.token_types,
                        .tokenModifiers = &features.semantic_tokens.token_modifiers,
                    },
                    .full = .{ .bool = true },
                },
            },
            .foldingRangeProvider = .{ .bool = true },
            .documentLinkProvider = .{ .resolveProvider = false },
            .codeActionProvider = .{ .bool = true },
        };

        return .{
            .serverInfo = .{
                .name = "openprompt-lsp",
                .version = "0.1.0",
            },
            .capabilities = capabilities,
        };
    }

    pub fn initialized(self: *Server, arena: std.mem.Allocator, _: lsp.types.InitializedParams) !void {
        _ = self;
        _ = arena;
    }

    pub fn shutdown(self: *Server, arena: std.mem.Allocator, _: void) !?void {
        _ = self;
        _ = arena;
        return null;
    }

    pub fn exit(self: *Server, arena: std.mem.Allocator, _: void) !void {
        _ = self;
        _ = arena;
    }

    pub fn onResponse(self: *Server, arena: std.mem.Allocator, _: lsp.JsonRPCMessage.Response) !void {
        _ = self;
        _ = arena;
    }

    pub fn @"textDocument/didOpen"(
        self: *Server,
        arena: std.mem.Allocator,
        notification: lsp.types.TextDocument.DidOpenParams,
    ) !void {
        _ = arena;
        try self.store.openDocument(
            notification.textDocument.uri,
            notification.textDocument.text,
            notification.textDocument.version,
        );
    }

    pub fn @"textDocument/didChange"(
        self: *Server,
        arena: std.mem.Allocator,
        notification: lsp.types.TextDocument.DidChangeParams,
    ) !void {
        _ = arena;

        const state = self.store.get(notification.textDocument.uri) orelse return;

        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(self.allocator);
        try buffer.appendSlice(self.allocator, state.parsed.source);

        for (notification.contentChanges) |change| {
            switch (change) {
                .text_document_content_change_whole_document => |whole| {
                    buffer.clearRetainingCapacity();
                    try buffer.appendSlice(self.allocator, whole.text);
                },
                .text_document_content_change_partial => |partial| {
                    const loc = lsp.offsets.rangeToLoc(buffer.items, partial.range, self.offset_encoding);
                    try buffer.replaceRange(self.allocator, loc.start, loc.end - loc.start, partial.text);
                },
            }
        }

        const new_text = try buffer.toOwnedSlice(self.allocator);
        defer self.allocator.free(new_text);
        try self.store.updateDocument(notification.textDocument.uri, new_text, notification.textDocument.version);
    }

    pub fn @"textDocument/didClose"(
        self: *Server,
        arena: std.mem.Allocator,
        notification: lsp.types.TextDocument.DidCloseParams,
    ) !void {
        _ = arena;
        try self.store.closeDocument(notification.textDocument.uri);
    }

    pub fn @"textDocument/completion"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.completion.Params,
    ) !?lsp.types.completion.Result {
        const state = self.store.get(params.textDocument.uri) orelse return null;
        const items = try features.completion.completion(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            params.position,
            self.offset_encoding,
        ) orelse return null;

        return .{ .completion_items = items };
    }

    pub fn @"textDocument/hover"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.Hover.Params,
    ) !?lsp.types.Hover {
        const state = self.store.get(params.textDocument.uri) orelse return null;

        return features.hover.hover(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            params.position,
            self.offset_encoding,
        );
    }

    pub fn @"textDocument/definition"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.DefinitionParams,
    ) !?lsp.types.Definition.Result {
        const state = self.store.get(params.textDocument.uri) orelse return null;
        const locations = try features.definition.definition(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            params.position,
            self.offset_encoding,
        ) orelse return null;

        return .{ .definition = .{ .locations = locations } };
    }

    pub fn @"textDocument/references"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.ReferenceParams,
    ) !?[]const lsp.types.Location {
        const state = self.store.get(params.textDocument.uri) orelse return null;

        const locations = try features.references.references(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            params.position,
            self.offset_encoding,
        ) orelse return null;

        return locations;
    }

    pub fn @"textDocument/rename"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.RenameParams,
    ) !?lsp.types.WorkspaceEdit {
        const state = self.store.get(params.textDocument.uri) orelse return null;

        return features.references.rename(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            params.position,
            params.newName,
            self.offset_encoding,
        );
    }

    pub fn @"textDocument/documentSymbol"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.DocumentSymbolParams,
    ) !?lsp.types.DocumentSymbol.Result {
        const state = self.store.get(params.textDocument.uri) orelse return null;

        const symbols = try features.document_symbols.documentSymbols(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            self.offset_encoding,
        ) orelse return null;

        return .{ .document_symbols = symbols };
    }

    pub fn @"workspace/symbol"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.WorkspaceSymbolParams,
    ) !?lsp.types.workspace.Symbol.Result {
        const symbols = try features.document_symbols.workspaceSymbols(arena, &self.store, params.query) orelse return null;

        return .{ .symbol_informations = symbols };
    }

    pub fn @"textDocument/foldingRange"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.FoldingRangeParams,
    ) !?[]const lsp.types.FoldingRange {
        const state = self.store.get(params.textDocument.uri) orelse return null;

        const ranges = try features.folding.foldingRanges(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            self.offset_encoding,
        ) orelse return null;

        return ranges;
    }

    pub fn @"textDocument/documentLink"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.DocumentLinkParams,
    ) !?[]const lsp.types.DocumentLink {
        const state = self.store.get(params.textDocument.uri) orelse return null;

        const links = try features.folding.documentLinks(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            self.offset_encoding,
        ) orelse return null;

        return links;
    }

    pub fn @"textDocument/semanticTokens/full"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.SemanticTokensParams,
    ) !?lsp.types.semantic_tokens.Result {
        const state = self.store.get(params.textDocument.uri) orelse return null;
        const data = try features.semantic_tokens.semanticTokens(
            arena,
            &self.store,
            params.textDocument.uri,
            state.parsed.source,
            self.offset_encoding,
        ) orelse return null;

        return .{ .data = data };
    }

    pub fn @"textDocument/codeAction"(
        self: *Server,
        arena: std.mem.Allocator,
        params: lsp.types.flat.CodeActionParams,
    ) !?[]const lsp.types.CodeAction.Result {
        const actions = try features.code_actions.codeActions(arena, &self.store, params.textDocument.uri) orelse return null;

        const results = try arena.alloc(lsp.types.CodeAction.Result, actions.len);
        for (actions, 0..) |action, index| {
            results[index] = .{ .code_action = action };
        }

        return results;
    }

    pub fn @"workspace/didChangeConfiguration"(
        self: *Server,
        arena: std.mem.Allocator,
        notification: lsp.types.flat.DidChangeConfigurationParams,
    ) !void {
        _ = arena;
        try self.store.config.applySettings(self.allocator, notification.settings);
    }

    pub fn @"workspace/didChangeWatchedFiles"(
        self: *Server,
        arena: std.mem.Allocator,
        _: lsp.types.flat.DidChangeWatchedFilesParams,
    ) !void {
        _ = arena;
        try self.store.setWorkspaceRoots(self.workspace_roots);
    }

    pub fn buildDiagnostics(
        self: *Server,
        arena: std.mem.Allocator,
        uri: []const u8,
        source: []const u8,
    ) ![]lsp.types.Diagnostic {
        const raw = try self.store.diagnosticsFor(uri);
        defer {
            for (raw) |item| self.allocator.free(item.message);
            self.allocator.free(raw);
        }

        var diagnostics: std.ArrayList(lsp.types.Diagnostic) = .empty;
        errdefer diagnostics.deinit(arena);

        for (raw) |item| {
            const start = util.indexToPoint(source, item.range.start);
            const end = util.indexToPoint(source, item.range.end);
            try diagnostics.append(arena, .{
                .range = .{
                    .start = .{ .line = start.line, .character = start.column },
                    .end = .{ .line = end.line, .character = end.column },
                },
                .severity = switch (item.severity) {
                    .@"error" => .Error,
                    .warning => .Warning,
                    .information => .Information,
                },
                .source = "openprompt-lsp",
                .message = try arena.dupe(u8, item.message),
            });
        }

        return try diagnostics.toOwnedSlice(arena);
    }
};
