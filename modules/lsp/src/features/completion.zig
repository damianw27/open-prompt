const std = @import("std");
const lsp = @import("lsp");
const util = @import("../util.zig");
const semantic = @import("../semantic/root.zig");
const includes = @import("../semantic/includes.zig");
const workspace = @import("../workspace/root.zig");

pub fn completion(
    arena: std.mem.Allocator,
    store: *workspace.Store,
    uri: []const u8,
    source: []const u8,
    position: lsp.types.Position,
    encoding: lsp.offsets.Encoding,
) !?[]lsp.types.completion.Item {
    const state = store.get(uri) orelse return null;
    const index = lsp.offsets.positionToIndex(source, position, encoding);
    const context = semantic.position.contextAt(source, @intCast(index));

    var items: std.ArrayList(lsp.types.completion.Item) = .empty;
    errdefer items.deinit(arena);

    switch (context.kind) {
        .use_path, .inject_path => {
            const paths = try store.index.allPromptPaths(store.allocator);
            defer {
                for (paths) |path| store.allocator.free(path);
                store.allocator.free(paths);
            }
            for (paths) |path| {
                if (includes.pathMatchesPrefix(context.prefix, path)) {
                    try items.append(arena, .{
                        .label = try arena.dupe(u8, path),
                        .kind = lsp.types.completion.Item.Kind.File,
                        .detail = try arena.dupe(u8, "prompt file"),
                    });
                }
            }
            const base = util.basename(context.prefix);
            if (base.len > 0 and base.len == context.prefix.len) {
                for (paths) |path| {
                    if (std.mem.eql(u8, util.basename(path), base)) {
                        try appendPathCompletion(arena, &items, path);
                    }
                }
            }
        },
        .variable => {
            const names = try state.scope.names(arena);
            for (names) |name| {
                if (context.prefix.len == 0 or std.mem.startsWith(u8, name, context.prefix)) {
                    const label = try std.fmt.allocPrint(arena, "${s}", .{name});
                    try items.append(arena, .{
                        .label = label,
                        .kind = lsp.types.completion.Item.Kind.Variable,
                    });
                }
            }
        },
        .property => {
            if (context.root) |root| {
                var iterator = state.scope.symbols.iterator();
                while (iterator.next()) |entry| {
                    const prefix = try std.fmt.allocPrint(arena, "{s}.", .{root});
                    if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                        const property = entry.key_ptr.*[prefix.len..];
                        if (context.prefix.len == 0 or std.mem.startsWith(u8, property, context.prefix)) {
                            try items.append(arena, .{
                                .label = try arena.dupe(u8, property),
                                .kind = lsp.types.completion.Item.Kind.Property,
                            });
                        }
                    }
                }
            }
        },
        .prompt_selection => {
            for (state.parsed.ast.uses) |use_item| {
                const resolved = try includes.resolveInclude(&store.index, arena, uri, use_item.path) orelse continue;
                defer {
                    arena.free(resolved.uri);
                    arena.free(resolved.path);
                }

                if (store.get(resolved.uri)) |included_state| {
                    try appendTemplateCompletions(arena, &items, included_state.parsed.ast.templates, context.prefix);
                } else {
                    var parsed = store.parseIncludedFile(resolved.uri) catch continue;
                    defer parsed.deinit(store.allocator);
                    try appendTemplateCompletions(arena, &items, parsed.ast.templates, context.prefix);
                }
            }
        },
        .directive => {
            for (directives) |directive| {
                try items.append(arena, .{
                    .label = try arena.dupe(u8, directive),
                    .kind = lsp.types.completion.Item.Kind.Keyword,
                });
            }
        },
        .for_iterable => {
            const names = try state.scope.names(arena);
            for (names) |name| {
                if (context.prefix.len == 0 or std.mem.startsWith(u8, name, context.prefix)) {
                    try items.append(arena, .{
                        .label = try arena.dupe(u8, name),
                        .kind = lsp.types.completion.Item.Kind.Variable,
                    });
                }
            }
        },
        else => {},
    }

    if (items.items.len == 0) {
        return null;
    }

    return try items.toOwnedSlice(arena);
}

const directives = [_][]const u8{
    "use",   "inject", "template", "if",  "elseif",
    "else",  "for",    "end",
};

fn appendPathCompletion(
    arena: std.mem.Allocator,
    items: *std.ArrayList(lsp.types.completion.Item),
    path: []const u8,
) !void {
    for (items.items) |item| {
        if (std.mem.eql(u8, item.label, path)) {
            return;
        }
    }

    try items.append(arena, .{
        .label = try arena.dupe(u8, path),
        .kind = lsp.types.completion.Item.Kind.File,
        .detail = try arena.dupe(u8, "prompt file"),
    });
}

fn appendTemplateCompletions(
    arena: std.mem.Allocator,
    items: *std.ArrayList(lsp.types.completion.Item),
    templates: []const ast.Template,
    prefix: []const u8,
) !void {
    for (templates) |template| {
        if (prefix.len == 0 or std.mem.startsWith(u8, template.name, prefix)) {
            try items.append(arena, .{
                .label = try arena.dupe(u8, template.name),
                .kind = lsp.types.completion.Item.Kind.Snippet,
                .detail = try arena.dupe(u8, "exported template"),
            });
        }
    }
}

const ast = @import("../parser/ast.zig");

const _ = util;
