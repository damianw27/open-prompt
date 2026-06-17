const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cpp_build = b.addSystemCommand(&.{ "cmake", "--build", "../cpp/build" });
    cpp_build.step.dependOn(configureCpp(b, target, optimize));

    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    mod.addIncludePath(b.path("../cpp/include"));
    mod.addObjectFile(b.path("../cpp/build/libopenprompt_core.a"));
    mod.addLibraryPath(b.path("../cpp/build"));
    mod.link_libc = true;
    mod.link_objects.append(b.allocator, .{
        .system_lib = .{
            .name = b.dupe("stdc++"),
            .needed = true,
            .weak = false,
            .use_pkg_config = .no,
            .preferred_link_mode = .dynamic,
            .search_strategy = .paths_first,
        },
    }) catch @panic("OOM");

    const tests = b.addTest(.{
        .root_module = mod,
    });
    tests.step.dependOn(&cpp_build.step);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run Zig binding tests");
    test_step.dependOn(&run_tests.step);
}

fn configureCpp(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const optimize_flag = switch (optimize) {
        .Debug => "Debug",
        .ReleaseSafe => "RelWithDebInfo",
        .ReleaseFast => "Release",
        .ReleaseSmall => "MinSizeRel",
    };

    const cmd = b.addSystemCommand(&.{
        "cmake",
        "-S",
        "../cpp",
        "-B",
        "../cpp/build",
        b.fmt("-DCMAKE_BUILD_TYPE={s}", .{optimize_flag}),
    });

    _ = target;

    return &cmd.step;
}
