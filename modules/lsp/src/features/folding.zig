const std = @import("std");
const lsp = @import("lsp");
const workspace = @import("../workspace/root.zig");
const util = @import("../util.zig");

pub fn foldingRanges(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    encoding: lsp.offsets.Encoding,
) !?[]lsp.types.FoldingRange {
    const state = store.get(uri) orelse return null;

    var ranges: std.ArrayList(lsp.types.FoldingRange) = .empty;
    errdefer ranges.deinit(arena);

    for (state.parsed.ast.templates) |template| {
        try appendFold(arena, source, template.range, encoding, &ranges);
    }

    for (state.parsed.ast.for_loops) |loop_item| {
        try appendFold(arena, source, loop_item.range, encoding, &ranges);
    }

    if (ranges.items.len == 0) {
        return null;
    }

    return try ranges.toOwnedSlice(arena);
}

pub fn documentLinks(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    encoding: lsp.offsets.Encoding,
) !?[]lsp.types.DocumentLink {
    const state = store.get(uri) orelse return null;

    var links: std.ArrayList(lsp.types.DocumentLink) = .empty;
    errdefer links.deinit(arena);

    for (state.parsed.ast.injects) |inject| {
        if (try @import("../semantic/includes.zig").resolveInclude(&store.index, arena, uri, inject.path)) |resolved| {
            try links.append(arena, .{
                .range = byteRange(source, inject.range, encoding),
                .target = resolved.uri,
            });
        }
    }

    for (state.parsed.ast.uses) |use_item| {
        if (try @import("../semantic/includes.zig").resolveInclude(&store.index, arena, uri, use_item.path)) |resolved| {
            try links.append(arena, .{
                .range = byteRange(source, use_item.range, encoding),
                .target = resolved.uri,
            });
        }
    }

    if (links.items.len == 0) {
        return null;
    }

    return try links.toOwnedSlice(arena);
}

fn appendFold(
    arena: std.mem.Allocator,
    source: []const u8,
    range: util.ByteRange,
    encoding: lsp.offsets.Encoding,
    out: *std.ArrayList(lsp.types.FoldingRange),
) !void {
    _ = encoding;
    const start = util.indexToPoint(source, range.start);
    const end = util.indexToPoint(source, range.end);

    try out.append(arena, .{
        .startLine = @intCast(start.line),
        .endLine = @intCast(end.line),
        .startCharacter = @intCast(start.column),
        .endCharacter = @intCast(end.column),
    });
}

fn byteRange(source: []const u8, range: util.ByteRange, encoding: lsp.offsets.Encoding) lsp.types.Range {
    _ = encoding;
    const start = util.indexToPoint(source, range.start);
    const end = util.indexToPoint(source, range.end);

    return .{
        .start = .{ .line = start.line, .character = start.column },
        .end = .{ .line = end.line, .character = end.column },
    };
}
