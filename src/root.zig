const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const math = @import("math/root.zig");

const Allocator = std.mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator(.{});
const panic = std.debug.panic;

const Matrix = math.Matrix;
const Matrix4x4 = Matrix.Matrix4x4;

const Self = @This();
pub const App = @This();

pub const Projection = enum { ortho };

pub const Callback = fn(self: *Self) anyerror!void;

pub const Options = struct {
    initial_width: c_int = 800,
    initial_height: c_int = 600,
    title: ?[]const u8,

    projection: Projection = .ortho,

    debug: bool = false
};

debug: bool = false,
fps: isize = 0,

gpa: GeneralPurposeAllocator,
default_allocator: Allocator,
window: ?*c.GLFWwindow,

width: usize,
height: usize,

projection: Matrix4x4,

fn error_callback(err: c_int, description: [*c]const u8) callconv(.C) void {
    _ = err;
    panic("Crashed: {s}\n", .{description});
}

pub fn setup(options: Options, callback: Callback) !Self {
    _ = c.glfwSetErrorCallback(error_callback);

    if (c.glfwInit() == c.GL_FALSE) return error.InitializationError;
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    if (comptime @import("builtin").os.tag == .macos)
        c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    const window = c.glfwCreateWindow(
        options.initial_width,
        options.initial_height,
        if (options.title) |t| @ptrCast(t) else "",
        null,
        null
    );

    if (window == null) {
        c.glfwTerminate();
        return error.InitializationError;
    }

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == c.GL_FALSE) return error.InitializationError;

    c.glEnable(c.GL_CULL_FACE);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    var self: Self = .{
        .gpa = GeneralPurposeAllocator{},
        .window = window,

        .width = @intCast(options.initial_width),
        .height = @intCast(options.initial_height),

        .projection = switch (options.projection) {
            .ortho => Matrix.ortho(
                0,
                @floatFromInt(options.initial_width),
                @floatFromInt(options.initial_height),
                0
            )
        },

        .debug = options.debug
    };
    self.default_allocator = self.gpa.allocator();

    try callback(&self);

    return self;
}

pub fn deinit(self: *Self) void {
    std.debug.assert(self.gpa.deinit() == .ok);
}

pub fn loop(self: *Self, callback: Callback) !void {
    var prev = c.glfwGetTime();
    var frames: isize = 0;
    while (c.glfwWindowShouldClose(self.window) == c.GL_FALSE) {
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        self.processInput();
        try callback(self);

        if (self.debug) {
            const timestamp = c.glfwGetTime();
            frames += 1;
            if (timestamp - prev >= 1.0) {
                self.fps = frames;
                frames = 0;
                prev = timestamp;
            }
        }

        c.glfwSwapBuffers(@ptrCast(self.window));
        c.glfwPollEvents();
    }
}

fn processInput(self: *Self) void {
    _ = self;
}
