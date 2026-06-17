const std = @import("std");
const lsp = @import("lsp");
const workspace = @import("../workspace/root.zig");
const util = @import("../util.zig");

pub fn references(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    position: lsp.types.Position,
    encoding: lsp.offsets.Encoding,
) !?[]lsp.types.Location {
    const state = store.get(uri) orelse return null;
    const index = lsp.offsets.positionToIndex(source, position, encoding);
    const context = @import("../semantic/position.zig").contextAt(source, @intCast(index));

    const root = context.root orelse context.prefix;
    if (root.len == 0) {
        return null;
    }

    var locations: std.ArrayList(lsp.types.Location) = .empty;
    errdefer locations.deinit(arena);

    for (state.parsed.ast.variable_refs) |reference| {
        if (std.mem.eql(u8, reference.root, root)) {
            try locations.append(arena, .{
                .uri = try arena.dupe(u8, uri),
                .range = byteRange(source, reference.range, encoding),
            });
        }
    }

    if (locations.items.len == 0) {
        return null;
    }

    return try locations.toOwnedSlice(arena);
}

pub fn rename(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    position: lsp.types.Position,
    new_name: []const u8,
    encoding: lsp.offsets.Encoding,
) !?lsp.types.WorkspaceEdit {
    const state = store.get(uri) orelse return null;
    const index = lsp.offsets.positionToIndex(source, position, encoding);
    const context = @import("../semantic/position.zig").contextAt(source, @intCast(index));
    const root = context.root orelse context.prefix;
    if (root.len == 0) {
        return null;
    }

    var edits: std.ArrayList(lsp.types.TextEdit) = .empty;
    errdefer edits.deinit(arena);

    for (state.parsed.ast.variable_refs) |reference| {
        if (!std.mem.eql(u8, reference.root, root)) {
            continue;
        }

        const replacement = if (new_name[0] == '$')
            try arena.dupe(u8, new_name)
        else
            try std.fmt.allocPrint(arena, "${s}", .{new_name});

        try edits.append(arena, .{
            .range = byteRange(source, reference.range, encoding),
            .newText = replacement,
        });
    }

    if (edits.items.len == 0) {
        return null;
    }

    var changes: std.json.ArrayHashMap([]const lsp.types.TextEdit) = .{};
    try changes.map.put(arena, try arena.dupe(u8, uri), try edits.toOwnedSlice(arena));

    return .{ .changes = changes };
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
