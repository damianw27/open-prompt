const std = @import("std");
const util = @import("../util.zig");
const ast = @import("../parser/ast.zig");
const scope_mod = @import("scope.zig");
const includes = @import("includes.zig");

pub const Diagnostic = struct {
    message: []const u8,
    range: util.ByteRange,
    severity: Severity = .@"error",

    pub const Severity = enum {
        @"error",
        warning,
        information,
    };
};

pub fn collect(
    allocator: std.mem.Allocator,
    document: *const ast.Document,
    scope: *const scope_mod.Scope,
    index: *const includes.Index,
    current_uri: []const u8,
) ![]Diagnostic {
    var list: std.ArrayList(Diagnostic) = .empty;
    errdefer {
        for (list.items) |item| allocator.free(item.message);
        list.deinit(allocator);
    }

    if (document.has_errors) {
        try list.append(allocator, .{
            .message = try allocator.dupe(u8, "Syntax error in template"),
            .range = .{ .start = 0, .end = @min(@as(u32, 1), @as(u32, @intCast(document.variable_refs.len))) },
        });
    }

    for (document.variable_refs) |reference| {
        if (!scope_mod.isDefined(scope, reference.root)) {
            const message = try std.fmt.allocPrint(allocator, "Undefined variable '${s}'", .{reference.root});
            try list.append(allocator, .{
                .message = message,
                .range = reference.range,
            });
        }
    }

    for (document.injects) |inject| {
        const resolved = try includes.resolveInclude(index, allocator, current_uri, inject.path);
        if (resolved) |match| {
            if (match.ambiguous) {
                const message = try std.fmt.allocPrint(allocator, "Ambiguous include path '{s}'", .{inject.path});
                try list.append(allocator, .{
                    .message = message,
                    .range = inject.range,
                    .severity = .warning,
                });
            }
            allocator.free(match.uri);
            allocator.free(match.path);
        } else {
            const message = try std.fmt.allocPrint(allocator, "Include file not found: '{s}'", .{inject.path});
            try list.append(allocator, .{
                .message = message,
                .range = inject.range,
            });
        }
    }

    for (document.uses) |use_item| {
        const resolved = try includes.resolveInclude(index, allocator, current_uri, use_item.path);
        if (resolved) |match| {
            if (match.ambiguous) {
                const message = try std.fmt.allocPrint(allocator, "Ambiguous use path '{s}'", .{use_item.path});
                try list.append(allocator, .{
                    .message = message,
                    .range = use_item.range,
                    .severity = .warning,
                });
            }
            allocator.free(match.uri);
            allocator.free(match.path);
        } else {
            const message = try std.fmt.allocPrint(allocator, "Use file not found: '{s}'", .{use_item.path});
            try list.append(allocator, .{
                .message = message,
                .range = use_item.range,
            });
        }
    }

    return try list.toOwnedSlice(allocator);
}
