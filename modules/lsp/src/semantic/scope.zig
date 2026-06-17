const std = @import("std");
const util = @import("../util.zig");
const ast = @import("../parser/ast.zig");
const config = @import("../config.zig");
const front_matter = @import("../parser/front_matter.zig");

pub const SymbolKind = enum {
    use_alias,
    for_variable,
    host_root,
    host_property,
    template_export,
};

pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    detail: ?[]const u8 = null,
    source_uri: ?[]const u8 = null,
    range: util.ByteRange,
};

pub const Scope = struct {
    symbols: std.StringArrayHashMapUnmanaged(Symbol),

    pub fn init(allocator: std.mem.Allocator) Scope {
        _ = allocator;
        return .{ .symbols = .empty };
    }

    pub fn deinit(self: *Scope, allocator: std.mem.Allocator) void {
        var iterator = self.symbols.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.name);
            if (entry.value_ptr.detail) |detail| {
                allocator.free(detail);
            }
            if (entry.value_ptr.source_uri) |uri| {
                allocator.free(uri);
            }
        }
        self.symbols.deinit(allocator);
        self.* = undefined;
    }

    pub fn insert(self: *Scope, allocator: std.mem.Allocator, symbol: Symbol) !void {
        const key = try allocator.dupe(u8, symbol.name);
        errdefer allocator.free(key);
        const gop = try self.symbols.getOrPut(allocator, key);
        if (gop.found_existing) {
            allocator.free(gop.value_ptr.name);
            allocator.free(key);
            if (gop.value_ptr.detail) |detail| allocator.free(detail);
            if (gop.value_ptr.source_uri) |uri| allocator.free(uri);
        } else {
            gop.key_ptr.* = key;
        }
        gop.value_ptr.* = symbol;
    }

    pub fn get(self: *const Scope, name: []const u8) ?Symbol {
        return self.symbols.get(name);
    }

    pub fn names(self: *const Scope, allocator: std.mem.Allocator) ![]const []const u8 {
        var list: std.ArrayList([]const u8) = .empty;
        errdefer list.deinit(allocator);

        var iterator = self.symbols.iterator();
        while (iterator.next()) |entry| {
            try list.append(allocator, entry.key_ptr.*);
        }

        return try list.toOwnedSlice(allocator);
    }
};

pub fn buildDocumentScope(allocator: std.mem.Allocator, document: *const ast.Document) !Scope {
    var scope = Scope.init(allocator);
    errdefer scope.deinit(allocator);

    for (document.uses) |use_item| {
        try scope.insert(allocator, .{
            .name = try allocator.dupe(u8, use_item.alias),
            .kind = .use_alias,
            .detail = try std.fmt.allocPrint(allocator, "module {s}", .{use_item.path}),
            .range = use_item.range,
        });
    }

    for (document.for_loops) |loop_item| {
        try scope.insert(allocator, .{
            .name = try allocator.dupe(u8, loop_item.variable),
            .kind = .for_variable,
            .detail = try std.fmt.allocPrint(allocator, "for {s} in {s}", .{ loop_item.variable, loop_item.iterable }),
            .range = loop_item.range,
        });
    }

    return scope;
}

pub fn mergeHostSymbols(allocator: std.mem.Allocator, scope: *Scope, host_symbols: []const Symbol) !void {
    for (host_symbols) |symbol| {
        try scope.insert(allocator, symbol);
    }
}

pub fn isDefined(scope: *const Scope, root: []const u8) bool {
    return scope.get(root) != null;
}

pub fn propertyPathExists(scope: *const Scope, root: []const u8, properties: []const []const u8) bool {
    if (!isDefined(scope, root)) {
        return false;
    }

    if (properties.len == 0) {
        return true;
    }

    var path = root;
    for (properties) |property| {
        const full = std.fmt.allocPrint(std.heap.page_allocator, "{s}.{s}", .{ path, property }) catch return false;
        defer std.heap.page_allocator.free(full);
        if (scope.get(full) == null) {
            return false;
        }
        path = full;
    }

    return true;
}
