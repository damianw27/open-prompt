const std = @import("std");
const lsp = @import("lsp");
const workspace = @import("../workspace/root.zig");

pub fn codeActions(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
) !?[]lsp.types.CodeAction {
    const state = store.get(uri) orelse return null;

    if (!state.parsed.ast.has_errors) {
        return null;
    }

    const actions = try arena.alloc(lsp.types.CodeAction, 1);
    actions[0] = .{
        .title = try arena.dupe(u8, "OpenPrompt: review syntax around cursor"),
        .kind = .quickfix,
        .diagnostics = &.{},
        .edit = null,
    };

    return actions;
}
