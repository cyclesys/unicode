const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_module = b.addModule("unicode", .{ .source_file = .{ .path = "src/lib.zig" } });
    _ = lib_module;

    const lib_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(lib_tests);
    const run_tests_step = b.step("test", "Run tests");
    run_tests_step.dependOn(&run_tests.step);

    const gen_exe = b.addExecutable(.{
        .name = "gen",
        .root_source_file = .{ .path = "gen/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(gen_exe);

    const gen_cmd = b.addRunArtifact(gen_exe);
    gen_cmd.step.dependOn(b.getInstallStep());
    const gen_step = b.step("gen", "Generate src/ucd");
    gen_step.dependOn(&gen_cmd.step);
}
