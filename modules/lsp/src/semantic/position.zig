const std = @import("std");
const util = @import("../util.zig");

pub const ContextKind = enum {
    unknown,
    directive,
    use_path,
    inject_path,
    variable,
    property,
    prompt_selection,
    for_iterable,
    front_matter,
    markdown,
};

pub const Context = struct {
    kind: ContextKind,
    prefix: []const u8,
    root: ?[]const u8 = null,
};

pub fn contextAt(source: []const u8, index: u32) Context {
    if (index > source.len) {
        return .{ .kind = .unknown, .prefix = "" };
    }

    const before = source[0..index];
    const after = source[index..];

    if (isInsideString(before, "[[@use")) {
        return .{ .kind = .use_path, .prefix = stringPrefix(before) };
    }
    if (isInsideString(before, "[[@inject")) {
        return .{ .kind = .inject_path, .prefix = stringPrefix(before) };
    }
    if (isInsideInterpolation(before, after)) {
        return interpolationContext(before, index, source);
    }
    if (std.mem.endsWith(u8, before, "[[@") or std.mem.endsWith(u8, before, "[[@")) {
        return .{ .kind = .directive, .prefix = "" };
    }
    if (isInsideBlock(before, "---")) {
        return .{ .kind = .front_matter, .prefix = linePrefix(before) };
    }
    if (std.mem.indexOf(u8, before, "[[@for") != null and std.mem.indexOf(u8, before, " in ") != null and std.mem.indexOf(u8, before, "]]") == null) {
        return .{ .kind = .for_iterable, .prefix = iterablePrefix(before) };
    }

    return .{ .kind = .markdown, .prefix = "" };
}

fn interpolationContext(before: []const u8, index: u32, source: []const u8) Context {
    _ = index;
    _ = source;

    const open = std.mem.lastIndexOf(u8, before, "{{") orelse return .{ .kind = .variable, .prefix = "" };
    const segment = before[open + 2 ..];

    if (std.mem.indexOf(u8, segment, "[") != null and std.mem.indexOf(u8, segment, "]") == null) {
        return .{ .kind = .prompt_selection, .prefix = stringPrefix(segment) };
    }

    if (std.mem.lastIndexOf(u8, segment, ".") != null) {
        const dot = std.mem.lastIndexOf(u8, segment, ".").?;
        const root_part = std.mem.trim(u8, segment[0..dot], " \t");
        const root = if (root_part.len > 0 and root_part[0] == '$') root_part[1..] else root_part;
        const prefix = std.mem.trim(u8, segment[dot + 1 ..], " \t");

        return .{
            .kind = .property,
            .prefix = prefix,
            .root = root,
        };
    }

    const trimmed = std.mem.trim(u8, segment, " \t");
    const prefix = if (trimmed.len > 0 and trimmed[0] == '$') trimmed[1..] else trimmed;

    return .{ .kind = .variable, .prefix = prefix };
}

fn isInsideInterpolation(before: []const u8, after: []const u8) bool {
    const open = std.mem.lastIndexOf(u8, before, "{{") orelse return false;
    const close_before = std.mem.lastIndexOf(u8, before, "}}");
    if (close_before) |close_index| {
        if (close_index > open) {
            return false;
        }
    }

    const close_after = std.mem.indexOf(u8, after, "}}");
    return close_after != null;
}

fn isInsideString(before: []const u8, marker: []const u8) bool {
    const marker_index = std.mem.lastIndexOf(u8, before, marker) orelse return false;
    const tail = before[marker_index..];
    var quote: ?u8 = null;
    for (tail) |byte| {
        if (byte == '"' or byte == '\'') {
            quote = byte;
            break;
        }
    }

    if (quote == null) {
        return false;
    }

    const quote_char = quote.?;
    var count: usize = 0;
    for (tail) |byte| {
        if (byte == quote_char) {
            count += 1;
        }
    }

    return count % 2 == 1;
}

fn stringPrefix(before: []const u8) []const u8 {
    const quote_index = std.mem.lastIndexOfScalar(u8, before, '"') orelse
        std.mem.lastIndexOfScalar(u8, before, '\'') orelse return "";
    const tail = before[quote_index + 1 ..];

    return tail;
}

fn linePrefix(before: []const u8) []const u8 {
    const line_start = std.mem.lastIndexOfScalar(u8, before, '\n') orelse 0;
    return std.mem.trim(u8, before[line_start..], " \t");
}

fn iterablePrefix(before: []const u8) []const u8 {
    const in_index = std.mem.lastIndexOf(u8, before, " in ") orelse return "";
    return std.mem.trim(u8, before[in_index + 4 ..], " \t");
}

fn isInsideBlock(before: []const u8, delimiter: []const u8) bool {
    const first = std.mem.indexOf(u8, before, delimiter) orelse return false;
    const second = std.mem.indexOf(u8, before[first + delimiter.len ..], delimiter);
    return second == null;
}

const _ = util;
