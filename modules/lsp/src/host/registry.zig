const std = @import("std");
const ts = @import("tree-sitter");
const util = @import("../util.zig");
const cst = @import("../parser/cst.zig");
const language = @import("../parser/language.zig");
const scope_mod = @import("../semantic/scope.zig");

pub const Registry = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.* = undefined;
    }

    pub fn extractFromPaths(
        self: *Registry,
        allocator: std.mem.Allocator,
        io: std.Io,
        prompt_uri: []const u8,
        paths: []const []const u8,
    ) ![]scope_mod.Symbol {
        _ = self;

        var symbols: std.ArrayList(scope_mod.Symbol) = .empty;
        errdefer {
            for (symbols.items) |symbol| {
                allocator.free(symbol.name);
                if (symbol.detail) |detail| allocator.free(detail);
                if (symbol.source_uri) |uri| allocator.free(uri);
            }
            symbols.deinit(allocator);
        }

        const prompt_path = try util.pathFromFileUri(allocator, prompt_uri);
        defer allocator.free(prompt_path);
        const prompt_dir = try util.dirname(allocator, prompt_path);
        defer allocator.free(prompt_dir);

        for (paths) |context_path| {
            const resolved = if (std.fs.path.isAbsolute(context_path))
                try allocator.dupe(u8, context_path)
            else
                try util.joinPath(allocator, &.{ prompt_dir, context_path });
            defer allocator.free(resolved);

            const host_lang = language.HostLanguage.fromPath(resolved) orelse continue;
            const source = std.Io.Dir.cwd().readFileAlloc(
                io,
                resolved,
                allocator,
                std.Io.Limit.limited(1024 * 1024),
            ) catch continue;
            defer allocator.free(source);

            const uri = try util.fileUriFromPath(allocator, resolved);
            defer allocator.free(uri);

            try extractFromSource(allocator, host_lang, source, uri, &symbols);
        }

        return try symbols.toOwnedSlice(allocator);
    }
};

fn extractFromSource(
    allocator: std.mem.Allocator,
    host_lang: language.HostLanguage,
    source: []const u8,
    uri: []const u8,
    out: *std.ArrayList(scope_mod.Symbol),
) !void {
    const lang = if (std.mem.endsWith(u8, uri, ".tsx"))
        language.tsxLanguage()
    else
        host_lang.treeSitterLanguage();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(lang);

    const tree = parser.parseString(source, null) orelse return;
    defer tree.destroy();

    const query_source = queryForLanguage(host_lang);
    var error_offset: u32 = 0;
    const query = ts.Query.create(lang, query_source, &error_offset) catch return;
    defer query.destroy();

    const cursor = ts.QueryCursor.create();
    defer cursor.destroy();
    cursor.exec(query, tree.rootNode());

    var seen: std.StringHashMapUnmanaged(void) = .empty;
    defer seen.deinit(allocator);

    while (cursor.nextMatch()) |match| {
        for (match.captures) |capture| {
            const capture_name = query.captureNameForId(capture.index) orelse continue;
            if (!std.mem.eql(u8, capture_name, "name")) {
                continue;
            }

            const symbol_name = cst.nodeText(source, capture.node);
            if (symbol_name.len == 0) {
                continue;
            }

            if (seen.contains(symbol_name)) {
                continue;
            }
            try seen.put(allocator, try allocator.dupe(u8, symbol_name), {});

            const owned_uri = try allocator.dupe(u8, uri);
            errdefer allocator.free(owned_uri);
            try out.append(allocator, .{
                .name = try allocator.dupe(u8, symbol_name),
                .kind = .host_root,
                .detail = try std.fmt.allocPrint(allocator, "host symbol from {s}", .{uri}),
                .source_uri = owned_uri,
                .range = .{
                    .start = capture.node.startByte(),
                    .end = capture.node.endByte(),
                },
            });
        }
    }
}

fn queryForLanguage(host_lang: language.HostLanguage) []const u8 {
    return switch (host_lang) {
        .cpp => @embedFile("../queries/host/cpp.scm"),
        .java => @embedFile("../queries/host/java.scm"),
        .javascript => @embedFile("../queries/host/javascript.scm"),
        .typescript => @embedFile("../queries/host/typescript.scm"),
        .lua => @embedFile("../queries/host/lua.scm"),
        .zig => @embedFile("../queries/host/zig.scm"),
    };
}
