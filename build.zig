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
    module.linkSystemLibrary("freetype", .{});
}

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const math = b.addModule("math", .{
    	.root_source_file = b.path("src/math/root.zig")
    });

    const util = b.addModule("util", .{
        .root_source_file = b.path("src/utils/util.zig")
    });

    const color = b.addModule("color", .{
    	.root_source_file = b.path("src/utils/color.zig"),
        .imports = &.{
            .{ .name = "math", .module = math }
        }
    });

    const style = b.addModule("style", .{
    	.root_source_file = b.path("src/elements/style.zig"),
        .imports = &.{
            .{ .name = "color", .module = color }
        }
    });

    const font = b.addModule("font", .{
    	.root_source_file = b.path("src/font/root.zig"),
        .target = target
    });

    font.addIncludePath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/freetype/2.13.3/include/freetype2/" });
    font.addLibraryPath(Build.LazyPath{ .cwd_relative = "/opt/homebrew/Cellar/freetype/2.13.3/lib" });

    font.addIncludePath(b.path("./deps"));

    font.linkSystemLibrary("freetype", .{});

    const cellui = b.addModule("cellui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "math", .module = math },
            .{ .name = "util", .module = util },
            .{ .name = "color", .module = color },
            .{ .name = "style", .module = style },
            .{ .name = "font", .module = font }
        }
    });

    attachDependenciesToModule(b, cellui);

    const options = b.addOptions();
    cellui.addOptions("build", options);
    
    const main = b.addExecutable(.{
    	.name = "cellui",
     	.root_source_file = b.path("src/main.zig"),
      	.target = target, .optimize = optimize
    });

    main.root_module.addImport("util", util);
    main.root_module.addImport("math", math);
    main.root_module.addImport("color", color);
    main.root_module.addImport("style", style);
    main.root_module.addImport("font", font);
    attachDependencies(b, main);
    b.installArtifact(main);

    const run_exe = b.addRunArtifact(main);
    const run_step = b.step("run", "Test rendering");
    run_step.dependOn(&run_exe.step);
}
