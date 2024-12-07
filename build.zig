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
    exe.addCSourceFile(.{
        .file = b.path("./deps/stb.c"),
        .flags = &.{}
    });

    exe.linkFramework("OpenGL");
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("freetype");
}

fn attachDependenciesToModule(b: *Build, module: *Build.Module) void {
    module.addIncludePath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/include" });
    module.addLibraryPath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/lib" });

    module.addIncludePath(b.path("./deps"));
    module.addCSourceFile(.{
        .file = b.path("./deps/glad.c"),
        .flags = &.{}
    });
    module.addCSourceFile(.{
        .file = b.path("./deps/stb.c"),
        .flags = &.{}
    });

    module.linkFramework("OpenGL", .{});
    module.linkSystemLibrary("glfw", .{});
}

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cellui = b.addModule("cellui", .{
        .root_source_file = b.path("src/entry.zig"),
        .target = target
    });

    cellui.addIncludePath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/include" });
    cellui.addLibraryPath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/glfw/3.4/lib" });

    cellui.addIncludePath(b.path("./deps"));
    cellui.addCSourceFile(.{
        .file = b.path("./deps/glad.c"),
        .flags = &.{}
    });

    cellui.linkFramework("OpenGL", .{});
    cellui.linkSystemLibrary("glfw", .{});
    cellui.linkSystemLibrary("freetype", .{});

    const math = b.addModule("math", .{
        .root_source_file = b.path("src/math/root.zig")
    });

    cellui.addImport("math", math);

    const util = b.addModule("util", .{
        .root_source_file = b.path("src/util/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "math", .module = math }
        }
    });

    util.addIncludePath(b.path("./deps"));

    cellui.addImport("util", util);

    const style = b.addModule("style", .{
        .root_source_file = b.path("src/element/style.zig"),
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "util", .module = util }
        }
    });

    cellui.addImport("style", style);

    const font = b.addModule("font", .{
        .root_source_file = b.path("src/font/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "math", .module = math }
        }
    });

    font.addIncludePath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/freetype/2.13.3/include/freetype2/" });
    font.addLibraryPath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/freetype/2.13.3/lib" });

    font.addIncludePath(b.path("./deps"));

    font.linkSystemLibrary("freetype", .{});

    cellui.addImport("font", font);

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize
    });

    exe.root_module.addImport("cellui", cellui);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Test rendering");
    run_step.dependOn(&run_exe.step);
}