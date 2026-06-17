const std = @import("std");
const lsp = @import("lsp");
const workspace = @import("../workspace/root.zig");
const util = @import("../util.zig");

pub const token_types = [_][]const u8{
    "keyword", "variable", "string", "operator", "property",
};
pub const token_modifiers = [_][]const u8{ "declaration", "readonly" };

const TokenSpan = struct {
    range: util.ByteRange,
    token_type: u32,
};

pub fn semanticTokens(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    encoding: lsp.offsets.Encoding,
) !?[]const u32 {
    const state = store.get(uri) orelse return null;

    var spans: std.ArrayList(TokenSpan) = .empty;
    errdefer spans.deinit(arena);

    for (state.parsed.ast.uses) |item| {
        try spans.append(arena, .{ .range = item.range, .token_type = 0 });
    }
    for (state.parsed.ast.injects) |item| {
        try spans.append(arena, .{ .range = item.range, .token_type = 0 });
    }
    for (state.parsed.ast.variable_refs) |item| {
        try spans.append(arena, .{ .range = item.range, .token_type = 1 });
    }

    if (spans.items.len == 0) {
        return null;
    }

    std.mem.sort(TokenSpan, spans.items, {}, struct {
        fn less(_: void, left: TokenSpan, right: TokenSpan) bool {
            return left.range.start < right.range.start;
        }
    }.less);

    var data: std.ArrayList(u32) = .empty;
    errdefer data.deinit(arena);

    var last_line: u32 = 0;
    var last_col: u32 = 0;

    for (spans.items) |item| {
        try pushToken(arena, source, item.range, item.token_type, &last_line, &last_col, encoding, &data);
    }

    return try data.toOwnedSlice(arena);
}

fn pushToken(
    arena: std.mem.Allocator,
    source: []const u8,
    range: util.ByteRange,
    token_type: u32,
    last_line: *u32,
    last_col: *u32,
    encoding: lsp.offsets.Encoding,
    out: *std.ArrayList(u32),
) !void {
    _ = encoding;
    const start = util.indexToPoint(source, range.start);
    const length = range.end - range.start;

    const delta_line = start.line - last_line.*;
    const delta_col = if (delta_line == 0) start.column - last_col.* else start.column;

    try out.append(arena, delta_line);
    try out.append(arena, delta_col);
    try out.append(arena, length);
    try out.append(arena, token_type);
    try out.append(arena, 0);

    last_line.* = start.line;
    last_col.* = start.column;
}
