const std = @import("std");
const util = @import("../util.zig");
const ast = @import("../parser/ast.zig");

pub const ResolvedPath = struct {
    uri: []const u8,
    path: []const u8,
    ambiguous: bool,
};

pub const Index = struct {
    by_basename: std.StringHashMapUnmanaged([]const []const u8),
    by_relative: std.StringHashMapUnmanaged([]const u8),
    workspace_roots: []const []const u8,

    pub fn init(allocator: std.mem.Allocator) Index {
        _ = allocator;
        return .{
            .by_basename = .empty,
            .by_relative = .empty,
            .workspace_roots = &.{},
        };
    }

    pub fn deinit(self: *Index, allocator: std.mem.Allocator) void {
        var base_it = self.by_basename.iterator();
        while (base_it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.*) |uri| allocator.free(uri);
            allocator.free(entry.value_ptr.*);
        }
        self.by_basename.deinit(allocator);

        var rel_it = self.by_relative.iterator();
        while (rel_it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.by_relative.deinit(allocator);

        for (self.workspace_roots) |root| allocator.free(root);
        allocator.free(self.workspace_roots);
        self.* = undefined;
    }

    pub fn rebuild(self: *Index, allocator: std.mem.Allocator, io: std.Io, roots: []const []const u8) !void {
        self.deinit(allocator);
        self.* = Index.init(allocator);

        var owned_roots: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (owned_roots.items) |root| allocator.free(root);
            owned_roots.deinit(allocator);
        }

        for (roots) |root| {
            try owned_roots.append(allocator, try allocator.dupe(u8, root));
            try self.scanDirectory(allocator, io, root);
        }

        self.workspace_roots = try owned_roots.toOwnedSlice(allocator);
    }

    fn scanDirectory(self: *Index, allocator: std.mem.Allocator, io: std.Io, root: []const u8) !void {
        const dir = std.Io.Dir.openDirAbsolute(io, root, .{ .iterate = true }) catch return;
        defer dir.close(io);

        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next(io)) |entry| {
            if (entry.kind != .file) {
                continue;
            }

            if (!util.isPromptPath(entry.path)) {
                continue;
            }

            const full_path = try util.joinPath(allocator, &.{ root, entry.path });
            errdefer allocator.free(full_path);
            const uri = try util.fileUriFromPath(allocator, full_path);
            errdefer allocator.free(uri);

            const base = util.basename(entry.path);
            try self.addBasename(allocator, base, uri);

            const normalized = try normalizeRelative(allocator, entry.path);
            errdefer allocator.free(normalized);
            try self.addRelative(allocator, normalized, uri);

            allocator.free(normalized);
            allocator.free(full_path);
        }
    }

    fn addBasename(self: *Index, allocator: std.mem.Allocator, base: []const u8, uri: []const u8) !void {
        const gop = try self.by_basename.getOrPut(allocator, try allocator.dupe(u8, base));
        errdefer allocator.free(gop.key_ptr.*);

        if (!gop.found_existing) {
            gop.value_ptr.* = &.{};
        }

        const new_uri = try allocator.dupe(u8, uri);
        const old = gop.value_ptr.*;
        const expanded = try allocator.alloc([]const u8, old.len + 1);
        @memcpy(expanded[0..old.len], old);
        expanded[old.len] = new_uri;
        allocator.free(old);
        gop.value_ptr.* = expanded;
    }

    fn addRelative(self: *Index, allocator: std.mem.Allocator, relative: []const u8, uri: []const u8) !void {
        const key = try allocator.dupe(u8, relative);
        errdefer allocator.free(key);
        const value = try allocator.dupe(u8, uri);
        const result = try self.by_relative.fetchPut(allocator, key, value);
        if (result) |existing| {
            allocator.free(existing.key);
            allocator.free(existing.value);
        }
    }

    pub fn resolve(self: *const Index, allocator: std.mem.Allocator, current_path: []const u8, include_path: []const u8) !?ResolvedPath {
        const dir = try util.dirname(allocator, current_path);
        defer allocator.free(dir);

        const joined = try util.joinPath(allocator, &.{ dir, include_path });
        defer allocator.free(joined);

        if (try self.resolveAbsolutePath(allocator, joined)) |resolved| {
            return resolved;
        }

        const base = util.basename(include_path);
        const matches = self.by_basename.get(base) orelse return null;
        if (matches.len == 0) {
            return null;
        }

        for (matches) |uri| {
            const path = try util.pathFromFileUri(allocator, uri);
            defer allocator.free(path);
            const match_dir = try util.dirname(allocator, path);
            defer allocator.free(match_dir);

            if (std.mem.eql(u8, match_dir, dir)) {
                return .{
                    .uri = try allocator.dupe(u8, uri),
                    .path = try allocator.dupe(u8, path),
                    .ambiguous = false,
                };
            }
        }

        if (matches.len == 1) {
            const path = try util.pathFromFileUri(allocator, matches[0]);
            return .{
                .uri = try allocator.dupe(u8, matches[0]),
                .path = path,
                .ambiguous = false,
            };
        }

        const path = try util.pathFromFileUri(allocator, matches[0]);
        return .{
            .uri = try allocator.dupe(u8, matches[0]),
            .path = path,
            .ambiguous = true,
        };
    }

    fn resolveAbsolutePath(self: *const Index, allocator: std.mem.Allocator, absolute_path: []const u8) !?ResolvedPath {
        const relative_key = try self.relativeKeyFromAbsolute(allocator, absolute_path);
        defer if (relative_key) |key| allocator.free(key);

        if (relative_key) |key| {
            if (self.by_relative.get(key)) |uri| {
                return .{
                    .uri = try allocator.dupe(u8, uri),
                    .path = try allocator.dupe(u8, absolute_path),
                    .ambiguous = false,
                };
            }
        }

        return null;
    }

    fn relativeKeyFromAbsolute(self: *const Index, allocator: std.mem.Allocator, absolute_path: []const u8) !?[]const u8 {
        for (self.workspace_roots) |root| {
            if (absolute_path.len < root.len) {
                continue;
            }

            if (!std.mem.startsWith(u8, absolute_path, root)) {
                continue;
            }

            var suffix = absolute_path[root.len..];
            if (suffix.len > 0 and suffix[0] == '/') {
                suffix = suffix[1..];
            }

            if (suffix.len == 0) {
                continue;
            }

            return try normalizeRelative(allocator, suffix);
        }

        return null;
    }

    pub fn allPromptPaths(self: *const Index, allocator: std.mem.Allocator) ![]const []const u8 {
        var list: std.ArrayList([]const u8) = .empty;
        errdefer list.deinit(allocator);

        var iterator = self.by_relative.iterator();
        while (iterator.next()) |entry| {
            try list.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
        }

        return try list.toOwnedSlice(allocator);
    }
};

pub fn resolveInclude(
    index: *const Index,
    allocator: std.mem.Allocator,
    current_uri: []const u8,
    include_path: []const u8,
) !?ResolvedPath {
    const current_path = try util.pathFromFileUri(allocator, current_uri);
    defer allocator.free(current_path);

    return index.resolve(allocator, current_path, include_path);
}

pub fn pathMatchesPrefix(prefix: []const u8, candidate: []const u8) bool {
    if (prefix.len == 0) {
        return true;
    }

    if (std.mem.startsWith(u8, candidate, prefix)) {
        return true;
    }

    if (std.mem.endsWith(u8, candidate, prefix)) {
        return true;
    }

    const base = util.basename(candidate);
    if (std.mem.startsWith(u8, base, prefix)) {
        return true;
    }

    if (std.mem.indexOf(u8, candidate, prefix) != null) {
        return true;
    }

    return false;
}

pub fn exportsFromDocument(document: *const ast.Document) []const ast.Template {
    return document.templates;
}

fn normalizeRelative(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const copy = try allocator.dupe(u8, path);
    for (copy) |*byte| {
        if (byte.* == '\\') {
            byte.* = '/';
        }
    }

    return copy;
}
