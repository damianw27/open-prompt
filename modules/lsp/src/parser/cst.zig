const std = @import("std");
const ts = @import("tree-sitter");

pub fn childByFieldName(node: ts.Node, name: []const u8) ?ts.Node {
    return node.childByFieldName(name);
}

pub fn namedChildren(node: ts.Node, allocator: std.mem.Allocator) ![]ts.Node {
    var list: std.ArrayList(ts.Node) = .empty;
    errdefer list.deinit(allocator);

    var cursor = node.walk();
    defer cursor.destroy();

    if (cursor.gotoFirstChild()) {
        while (true) {
            const child = cursor.node();
            if (child.isNamed()) {
                try list.append(allocator, child);
            }
            if (!cursor.gotoNextSibling()) {
                break;
            }
        }
    }

    return try list.toOwnedSlice(allocator);
}

pub fn findChildren(node: ts.Node, kind: []const u8, allocator: std.mem.Allocator) ![]ts.Node {
    var list: std.ArrayList(ts.Node) = .empty;
    errdefer list.deinit(allocator);
    try walk(node, kind, allocator, &list);

    return try list.toOwnedSlice(allocator);
}

fn walk(node: ts.Node, kind: []const u8, allocator: std.mem.Allocator, list: *std.ArrayList(ts.Node)) !void {
    if (std.mem.eql(u8, node.kind(), kind)) {
        try list.append(allocator, node);
    }

    var cursor = node.walk();
    defer cursor.destroy();

    if (cursor.gotoFirstChild()) {
        while (true) {
            try walk(cursor.node(), kind, allocator, list);
            if (!cursor.gotoNextSibling()) {
                break;
            }
        }
    }
}

pub fn nodeText(source: []const u8, node: ts.Node) []const u8 {
    const start = node.startByte();
    const end = node.endByte();
    if (start >= source.len or end > source.len or start > end) {
        return "";
    }

    return source[start..end];
}

pub fn hasError(node: ts.Node) bool {
    if (node.isError()) {
        return true;
    }

    var cursor = node.walk();
    defer cursor.destroy();

    if (cursor.gotoFirstChild()) {
        while (true) {
            if (hasError(cursor.node())) {
                return true;
            }
            if (!cursor.gotoNextSibling()) {
                break;
            }
        }
    }

    return false;
}
