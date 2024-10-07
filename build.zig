const std = @import("std");

const Build = std.Build;

fn attachDependencies(b: *Build, exe: *Build.Step.Compile) void {
    exe.addIncludePath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/include" });
    exe.addLibraryPath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/lib" });

    exe.addIncludePath(b.path("./deps"));
    exe.addCSourceFile(.{
        .file = b.path("./deps/glad.c"),
        .flags = &.{}
    });

    exe.linkFramework("OpenGL");
    exe.linkSystemLibrary("glfw");
}

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const color = b.addModule("color", .{
        .root_source_file = b.path("src/color.zig"),
        .target = target
    });

    const math = b.addModule("math", .{
        .root_source_file = b.path("src/math/root.zig"),
        .target = target
    });

    const main = b.addExecutable(.{
        .name = "cellui",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize
    });

    main.root_module.addImport("color", color);
    main.root_module.addImport("math", math);
    attachDependencies(b, main);
    b.installArtifact(main);

    const run_exe = b.addRunArtifact(main);
    const run_step = b.step("run", "Test rendering");
    run_step.dependOn(&run_exe.step);
}
