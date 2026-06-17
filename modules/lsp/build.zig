const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tree_sitter_pkg = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });
    const ts_module = tree_sitter_pkg.module("tree_sitter");

    const lsp_kit = b.dependency("lsp_kit", .{
        .target = target,
        .optimize = optimize,
    });
    const lsp_module = lsp_kit.module("lsp");

    const openprompt_lsp_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lsp", .module = lsp_module },
            .{ .name = "tree-sitter", .module = ts_module },
        },
    });

    addGrammarSources(b, openprompt_lsp_mod, .{
        .src_dir = "../tree-sitter/src",
        .scanner = "../tree-sitter/src/scanner.c",
    });

    const grammars = [_]struct {
        src_dir: []const u8,
        scanner: ?[]const u8,
    }{
        .{ .src_dir = "vendor/tree-sitter-javascript/src", .scanner = "vendor/tree-sitter-javascript/src/scanner.c" },
        .{ .src_dir = "vendor/tree-sitter-java/src", .scanner = null },
        .{ .src_dir = "vendor/tree-sitter-cpp/src", .scanner = "vendor/tree-sitter-cpp/src/scanner.c" },
        .{ .src_dir = "vendor/tree-sitter-typescript/typescript/src", .scanner = "vendor/tree-sitter-typescript/typescript/src/scanner.c" },
        .{ .src_dir = "vendor/tree-sitter-typescript/tsx/src", .scanner = "vendor/tree-sitter-typescript/tsx/src/scanner.c" },
        .{ .src_dir = "vendor/tree-sitter-lua/src", .scanner = "vendor/tree-sitter-lua/src/scanner.c" },
        .{ .src_dir = "vendor/tree-sitter-zig/src", .scanner = null },
    };
    for (grammars) |grammar| {
        addGrammarSources(b, openprompt_lsp_mod, .{
            .src_dir = grammar.src_dir,
            .scanner = grammar.scanner,
        });
    }

    const exe = b.addExecutable(.{
        .name = "openprompt-lsp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "openprompt_lsp", .module = openprompt_lsp_mod },
                .{ .name = "lsp", .module = lsp_module },
            },
        }),
    });
    b.installArtifact(exe);

    const mod_tests = b.addTest(.{
        .root_module = openprompt_lsp_mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run OpenPrompt LSP tests");
    test_step.dependOn(&run_mod_tests.step);
}

fn addGrammarSources(
    b: *std.Build,
    module: *std.Build.Module,
    opts: struct {
        src_dir: []const u8,
        scanner: ?[]const u8,
    },
) void {
    module.addCSourceFile(.{
        .file = b.path(b.fmt("{s}/parser.c", .{opts.src_dir})),
        .flags = &.{"-std=c11"},
    });
    if (opts.scanner) |scanner_path| {
        module.addCSourceFile(.{
            .file = b.path(scanner_path),
            .flags = &.{"-std=c11"},
        });
    }
    module.addIncludePath(b.path(opts.src_dir));
}
