const std = @import("std");

pub const ByteRange = struct {
    start: u32,
    end: u32,
};

pub const Position = struct {
    line: u32,
    column: u32,
};

pub const SourceLocation = struct {
    range: ByteRange,
};

pub fn decodeString(raw: []const u8) []const u8 {
    if (raw.len < 2) {
        return raw;
    }

    const quote = raw[0];
    if (quote != '"' and quote != '\'') {
        return raw;
    }

    if (raw[raw.len - 1] != quote) {
        return raw;
    }

    return raw[1 .. raw.len - 1];
}

pub fn indexToPoint(source: []const u8, index: u32) Position {
    var line: u32 = 0;
    var column: u32 = 0;
    var offset: u32 = 0;

    while (offset < index and offset < source.len) : (offset += 1) {
        if (source[offset] == '\n') {
            line += 1;
            column = 0;
        } else {
            column += 1;
        }
    }

    return .{ .line = line, .column = column };
}

pub fn pointToIndex(source: []const u8, point: Position) u32 {
    var line: u32 = 0;
    var column: u32 = 0;
    var offset: u32 = 0;

    while (offset < source.len) : (offset += 1) {
        if (line == point.line and column == point.column) {
            return offset;
        }

        if (source[offset] == '\n') {
            line += 1;
            column = 0;
        } else {
            column += 1;
        }
    }

    return offset;
}

pub fn fileUriFromPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (std.mem.startsWith(u8, path, "file://")) {
        return try allocator.dupe(u8, path);
    }

    if (std.fs.path.isAbsolute(path)) {
        return try std.fmt.allocPrint(allocator, "file://{s}", .{path});
    }

    return try std.fmt.allocPrint(allocator, "file:///{s}", .{path});
}

pub fn pathFromFileUri(allocator: std.mem.Allocator, uri: []const u8) ![]u8 {
    const prefix = "file://";
    if (!std.mem.startsWith(u8, uri, prefix)) {
        return try allocator.dupe(u8, uri);
    }

    const path_part = uri[prefix.len..];
    if (path_part.len > 0 and path_part[0] == '/') {
        return try allocator.dupe(u8, path_part);
    }

    return try std.fmt.allocPrint(allocator, "/{s}", .{path_part});
}

pub fn promptExtensions() [3][]const u8 {
    return .{ ".op", ".openprompt", ".prompt" };
}

pub fn isPromptPath(path: []const u8) bool {
    for (promptExtensions()) |ext| {
        if (std.mem.endsWith(u8, path, ext)) {
            return true;
        }
    }

    return false;
}

pub fn basename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

pub fn dirname(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const dir = std.fs.path.dirname(path) orelse return try allocator.dupe(u8, ".");

    return try allocator.dupe(u8, dir);
}

pub fn joinPath(allocator: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    if (parts.len == 0) {
        return try allocator.dupe(u8, "");
    }

    var result = try allocator.dupe(u8, parts[0]);
    errdefer allocator.free(result);

    var index: usize = 1;
    while (index < parts.len) : (index += 1) {
        const joined = try std.fs.path.join(allocator, &.{ result, parts[index] });
        allocator.free(result);
        result = joined;
    }

    return result;
}
