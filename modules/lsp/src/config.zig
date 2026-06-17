const std = @import("std");

pub const Config = struct {
    host_context_enabled: bool = true,
    context_sources: std.StringHashMapUnmanaged([]const []const u8),

    pub fn init(allocator: std.mem.Allocator) Config {
        _ = allocator;
        return .{
            .context_sources = .empty,
        };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        var iterator = self.context_sources.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.*) |path| {
                allocator.free(path);
            }
            allocator.free(entry.value_ptr.*);
        }
        self.context_sources.deinit(allocator);
        self.* = undefined;
    }

    pub fn applySettings(self: *Config, allocator: std.mem.Allocator, settings: ?std.json.Value) !void {
        const value = settings orelse return;
        const object = switch (value) {
            .object => |obj| obj,
            else => return,
        };

        if (object.get("openprompt.hostContextEnabled")) |enabled| {
            switch (enabled) {
                .bool => |flag| self.host_context_enabled = flag,
                else => {},
            }
        }

        if (object.get("openprompt.contextSources")) |sources| {
            try self.loadContextSources(allocator, sources);
        }
    }

    fn loadContextSources(self: *Config, allocator: std.mem.Allocator, value: std.json.Value) !void {
        const object = switch (value) {
            .object => |obj| obj,
            else => return,
        };

        var iterator = object.iterator();
        while (iterator.next()) |entry| {
            const paths = switch (entry.value_ptr.*) {
                .array => |array| array.items,
                else => continue,
            };

            var path_list: std.ArrayList([]const u8) = .empty;
            errdefer {
                for (path_list.items) |path| allocator.free(path);
                path_list.deinit(allocator);
            }

            for (paths) |path_value| {
                const path = switch (path_value) {
                    .string => |text| text,
                    else => continue,
                };
                try path_list.append(allocator, try allocator.dupe(u8, path));
            }

            const key = try allocator.dupe(u8, entry.key_ptr.*);
            errdefer allocator.free(key);
            const owned_paths = try path_list.toOwnedSlice(allocator);
            try self.context_sources.put(allocator, key, owned_paths);
        }
    }

    pub fn contextPathsForUri(self: *const Config, uri: []const u8) []const []const u8 {
        if (self.context_sources.get(uri)) |paths| {
            return paths;
        }

        if (self.context_sources.get("default")) |paths| {
            return paths;
        }

        return &.{};
    }
};
