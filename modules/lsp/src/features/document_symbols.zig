const std = @import("std");
const lsp = @import("lsp");
const workspace = @import("../workspace/root.zig");
const util = @import("../util.zig");

pub fn documentSymbols(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    encoding: lsp.offsets.Encoding,
) !?[]lsp.types.DocumentSymbol {
    const state = store.get(uri) orelse return null;

    var symbols: std.ArrayList(lsp.types.DocumentSymbol) = .empty;
    errdefer symbols.deinit(arena);

    for (state.parsed.ast.templates) |template| {
        try symbols.append(arena, .{
            .name = try arena.dupe(u8, template.name),
            .detail = try arena.dupe(u8, "template"),
            .kind = .Namespace,
            .range = byteRange(source, template.range, encoding),
            .selectionRange = byteRange(source, template.range, encoding),
        });
    }

    for (state.parsed.ast.uses) |use_item| {
        const name = try std.fmt.allocPrint(arena, "${s}", .{use_item.alias});
        try symbols.append(arena, .{
            .name = name,
            .detail = try std.fmt.allocPrint(arena, "use {s}", .{use_item.path}),
            .kind = .Module,
            .range = byteRange(source, use_item.range, encoding),
            .selectionRange = byteRange(source, use_item.range, encoding),
        });
    }

    if (symbols.items.len == 0) {
        return null;
    }

    return try symbols.toOwnedSlice(arena);
}

pub fn workspaceSymbols(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    query: []const u8,
) !?[]lsp.types.SymbolInformation {
    var symbols: std.ArrayList(lsp.types.SymbolInformation) = .empty;
    errdefer symbols.deinit(arena);

    var iterator = store.documents.iterator();
    while (iterator.next()) |entry| {
        for (entry.value_ptr.*.parsed.ast.templates) |template| {
            if (query.len == 0 or std.mem.indexOf(u8, template.name, query) != null) {
                try symbols.append(arena, .{
                    .name = try arena.dupe(u8, template.name),
                    .kind = .Namespace,
                    .location = .{
                        .uri = try arena.dupe(u8, entry.key_ptr.*),
                        .range = .{
                            .start = .{ .line = 0, .character = 0 },
                            .end = .{ .line = 0, .character = 0 },
                        },
                    },
                });
            }
        }
    }

    if (symbols.items.len == 0) {
        return null;
    }

    return try symbols.toOwnedSlice(arena);
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
