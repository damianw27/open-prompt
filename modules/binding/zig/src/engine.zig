const std = @import("std");
const c = @cImport({
    @cInclude("openprompt.h");
});

pub const Error = error{
    Parse,
    Render,
    NotFound,
    Io,
    InvalidArg,
    OutOfMemory,
};

pub const Engine = struct {
    handle: ?*c.op_engine,
    vfs: ?*c.op_vfs,
    owns_vfs: bool,
    allocator: std.mem.Allocator,

    pub fn initMemory(allocator: std.mem.Allocator) Engine {
        const vfs = c.op_vfs_memory();
        const handle = c.op_engine_create(vfs);

        return .{
            .handle = handle,
            .vfs = vfs,
            .owns_vfs = true,
            .allocator = allocator,
        };
    }

    pub fn initStdio(allocator: std.mem.Allocator, search_paths: []const []const u8) !Engine {
        const joined = try std.mem.join(allocator, ":", search_paths);
        defer allocator.free(joined);

        const vfs = c.op_vfs_stdio(joined.ptr);
        const handle = c.op_engine_create(vfs);

        return .{
            .handle = handle,
            .vfs = vfs,
            .owns_vfs = true,
            .allocator = allocator,
        };
    }

    pub fn registerModules(self: *Engine, modules: []const struct { path: []const u8, source: []const u8 }) Error!void {
        for (modules) |entry| {
            try self.registerModule(entry.path, entry.source);
        }
    }

    pub fn deinit(self: *Engine) void {
        if (self.handle) |handle| {
            c.op_engine_destroy(handle);
            self.handle = null;
            self.vfs = null;
            self.owns_vfs = false;
        }
    }

    pub fn registerModule(self: *Engine, path: []const u8, source: []const u8) Error!void {
        const status = c.op_engine_register_module(self.handle, path.ptr, source.ptr, source.len);

        return statusToError(status);
    }

    pub fn loadString(self: *Engine, source: []const u8, base_path: []const u8) Error!void {
        const status = c.op_engine_load_string(self.handle, source.ptr, source.len, base_path.ptr);

        return statusToError(status);
    }

    pub fn loadFile(self: *Engine, path: []const u8) Error!void {
        const status = c.op_engine_load_file(self.handle, path.ptr);

        return statusToError(status);
    }

    pub fn setContextJson(self: *Engine, json: []const u8) Error!void {
        const status = c.op_engine_set_context_json(self.handle, json.ptr, json.len);

        return statusToError(status);
    }

    pub fn render(self: *Engine) Error![]u8 {
        var output: ?[*]u8 = null;
        var output_len: usize = 0;
        const status = c.op_engine_render(self.handle, &output, &output_len);
        errdefer if (output) |ptr| c.op_string_free(ptr);

        try statusToError(status);

        const slice = output.?[0..output_len];
        const copy = try self.allocator.dupe(u8, slice);
        c.op_string_free(output.?);

        return copy;
    }

    fn statusToError(status: c.op_status) Error!void {
        return switch (status) {
            c.OP_OK => {},
            c.OP_ERR_PARSE => error.Parse,
            c.OP_ERR_RENDER => error.Render,
            c.OP_ERR_NOT_FOUND => error.NotFound,
            c.OP_ERR_IO => error.Io,
            c.OP_ERR_INVALID_ARG => error.InvalidArg,
            else => error.Render,
        };
    }
};
