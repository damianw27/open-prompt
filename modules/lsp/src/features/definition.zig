const std = @import("std");
const lsp = @import("lsp");
const semantic = @import("../semantic/root.zig");
const includes = @import("../semantic/includes.zig");
const workspace = @import("../workspace/root.zig");
const util = @import("../util.zig");

pub fn definition(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    position: lsp.types.Position,
    encoding: lsp.offsets.Encoding,
) !?[]lsp.types.Location {
    const state = store.get(uri) orelse return null;
    const index = lsp.offsets.positionToIndex(source, position, encoding);
    const context = semantic.position.contextAt(source, @intCast(index));

    switch (context.kind) {
        .use_path, .inject_path => {
            for (state.parsed.ast.injects) |inject| {
                if (index >= inject.range.start and index <= inject.range.end) {
                    if (try includes.resolveInclude(&store.index, arena, uri, inject.path)) |resolved| {
                        return try singleLocation(arena, .{
                            .uri = resolved.uri,
                            .range = zeroRange(),
                        });
                    }
                }
            }
            for (state.parsed.ast.uses) |use_item| {
                if (index >= use_item.range.start and index <= use_item.range.end) {
                    if (try includes.resolveInclude(&store.index, arena, uri, use_item.path)) |resolved| {
                        return try singleLocation(arena, .{
                            .uri = resolved.uri,
                            .range = zeroRange(),
                        });
                    }
                }
            }
        },
        .variable, .property => {
            const root = context.root orelse context.prefix;
            if (state.scope.get(root)) |symbol| {
                if (symbol.source_uri) |source_uri| {
                    return try singleLocation(arena, .{
                        .uri = try arena.dupe(u8, source_uri),
                        .range = byteRangeToLsp(source, symbol.range, encoding),
                    });
                }

                return try singleLocation(arena, .{
                    .uri = try arena.dupe(u8, uri),
                    .range = byteRangeToLsp(source, symbol.range, encoding),
                });
            }
        },
        else => {},
    }

    return null;
}

fn singleLocation(arena: std.mem.Allocator, location: lsp.types.Location) ![]lsp.types.Location {
    const slice = try arena.alloc(lsp.types.Location, 1);
    slice[0] = location;

    return slice;
}

fn zeroRange() lsp.types.Range {
    return .{
        .start = .{ .line = 0, .character = 0 },
        .end = .{ .line = 0, .character = 0 },
    };
}

fn byteRangeToLsp(source: []const u8, range: util.ByteRange, encoding: lsp.offsets.Encoding) lsp.types.Range {
    _ = encoding;
    const start = util.indexToPoint(source, range.start);
    const end = util.indexToPoint(source, range.end);

    return .{
        .start = .{ .line = start.line, .character = start.column },
        .end = .{ .line = end.line, .character = end.column },
    };
}
