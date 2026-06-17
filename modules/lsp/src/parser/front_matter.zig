const std = @import("std");
const util = @import("../util.zig");

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
    line: u32,
};

pub const Document = struct {
    entries: []Entry,

    pub fn deinit(self: *Document, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| {
            allocator.free(entry.key);
            allocator.free(entry.value);
        }
        allocator.free(self.entries);
        self.* = undefined;
    }

    pub fn contextPaths(self: Document, allocator: std.mem.Allocator) ![]const []const u8 {
        var values: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (values.items) |value| allocator.free(value);
            values.deinit(allocator);
        }

        for (self.entries) |entry| {
            if (!isContextKey(entry.key)) {
                continue;
            }

            var tokens = std.mem.tokenizeAny(u8, entry.value, " ,\t");
            while (tokens.next()) |token| {
                const trimmed = std.mem.trim(u8, token, " \t\"'");
                if (trimmed.len == 0) {
                    continue;
                }
                try values.append(allocator, try allocator.dupe(u8, trimmed));
            }
        }

        return try values.toOwnedSlice(allocator);
    }

    pub fn getValues(self: Document, key: []const u8) []const []const u8 {
        var values: std.ArrayList([]const u8) = .empty;
        for (self.entries) |entry| {
            if (std.ascii.eqlIgnoreCase(entry.key, key)) {
                values.appendAssumeCapacity(entry.value);
            }
        }

        return values.items;
    }
};

pub fn parseLines(allocator: std.mem.Allocator, lines: []const []const u8) !Document {
    var entries: std.ArrayList(Entry) = .empty;
    errdefer {
        for (entries.items) |entry| {
            allocator.free(entry.key);
            allocator.free(entry.value);
        }
        entries.deinit(allocator);
    }

    var line_number: u32 = 0;
    for (lines) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '#') {
            line_number += 1;
            continue;
        }

        if (try parseLine(allocator, trimmed, line_number)) |entry| {
            try entries.append(allocator, entry);
        }
        line_number += 1;
    }

    return .{ .entries = try entries.toOwnedSlice(allocator) };
}

pub fn parseLine(allocator: std.mem.Allocator, line: []const u8, line_number: u32) !?Entry {
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse {
        return parseSpaceSeparated(allocator, line, line_number);
    };

    const key = std.mem.trim(u8, line[0..colon], " \t");
    const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
    if (key.len == 0) {
        return null;
    }

    return .{
        .key = try allocator.dupe(u8, key),
        .value = try allocator.dupe(u8, value),
        .line = line_number,
    };
}

fn parseSpaceSeparated(allocator: std.mem.Allocator, line: []const u8, line_number: u32) !?Entry {
    var parts = std.mem.tokenizeScalar(u8, line, ' ');
    const key = parts.next() orelse return null;
    var value_builder: std.ArrayList(u8) = .empty;
    defer value_builder.deinit(allocator);

    while (parts.next()) |part| {
        if (value_builder.items.len > 0) {
            try value_builder.append(allocator, ' ');
        }
        try value_builder.appendSlice(allocator, part);
    }

    return .{
        .key = try allocator.dupe(u8, key),
        .value = try value_builder.toOwnedSlice(allocator),
        .line = line_number,
    };
}

pub fn isContextKey(key: []const u8) bool {
    return std.ascii.eqlIgnoreCase(key, "context") or std.ascii.eqlIgnoreCase(key, "contexts");
}

pub fn collectContextPaths(allocator: std.mem.Allocator, document: Document) ![]const []const u8 {
    var paths: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }

    for (document.entries) |entry| {
        if (!isContextKey(entry.key)) {
            continue;
        }

        var tokens = std.mem.tokenizeAny(u8, entry.value, " ,\t");
        while (tokens.next()) |token| {
            const trimmed = std.mem.trim(u8, token, " \t\"'");
            if (trimmed.len == 0) {
                continue;
            }
            try paths.append(allocator, try allocator.dupe(u8, trimmed));
        }
    }

    return try paths.toOwnedSlice(allocator);
}

test "parse front matter line" {
    const allocator = std.testing.allocator;
    const entry = (try parseLine(allocator, "context: ./User.ts", 0)).?;
    defer allocator.free(entry.key);
    defer allocator.free(entry.value);
    try std.testing.expectEqualStrings("context", entry.key);
    try std.testing.expectEqualStrings("./User.ts", entry.value);
}

test "parse space separated meta" {
    const allocator = std.testing.allocator;
    const entry = (try parseLine(allocator, "title Review", 0)).?;
    defer allocator.free(entry.key);
    defer allocator.free(entry.value);
    try std.testing.expectEqualStrings("title", entry.key);
    try std.testing.expectEqualStrings("Review", entry.value);
}

const _ = util;
