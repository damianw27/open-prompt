const std = @import("std");
const lsp = @import("lsp");
const semantic = @import("../semantic/root.zig");
const includes = @import("../semantic/includes.zig");
const workspace = @import("../workspace/root.zig");

pub fn hover(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    position: lsp.types.Position,
    encoding: lsp.offsets.Encoding,
) !?lsp.types.Hover {
    const state = store.get(uri) orelse return null;
    const index = lsp.offsets.positionToIndex(source, position, encoding);
    const context = semantic.position.contextAt(source, @intCast(index));

    const text = switch (context.kind) {
        .variable, .property => blk: {
            const name = context.root orelse context.prefix;
            if (state.scope.get(name)) |symbol| {
                break :blk symbol.detail orelse try std.fmt.allocPrint(arena, "${s}", .{name});
            }
            break :blk try std.fmt.allocPrint(arena, "Unknown variable '${s}'", .{name});
        },
        .use_path, .inject_path => try std.fmt.allocPrint(arena, "Include prompt file", .{}),
        .prompt_selection => try arena.dupe(u8, "Select exported template from @use module"),
        .directive => try arena.dupe(u8, "OpenPrompt directive"),
        .for_iterable => try arena.dupe(u8, "Iterable root identifier"),
        .front_matter => try arena.dupe(u8, "Document front matter"),
        else => return null,
    };

    return .{
        .contents = .{
            .markup_content = .{
                .kind = .markdown,
                .value = text,
            },
        },
    };
}
