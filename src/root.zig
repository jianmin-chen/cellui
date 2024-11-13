const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const elements = @import("element/root.zig");
const math = @import("math");
const util = @import("util");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Node = elements.Node;
const View = elements.View;

const color = util.color;
const ColorPrimitive = color.ColorPrimitive;

const Matrix = math.Matrix;
const Matrix4x4 = math.Matrix4x4;

const Self = @This();

pub const Error = error{ InitializationError };

pub const Projection = enum { ortho };

pub const InitialOptions = struct {
    initial_width: c_int = 1024,
    initial_height: c_int = 768,
    background: []const u8 = "#000000",
    title: ?[]const u8,

    projection: Projection = .ortho,
    debug: bool = false,
    extend_render_stack: ?fn(
        allocator: Allocator,
        render_stack: *ArrayList(View) 
    ) anyerror!void = null
};

debug: bool = false,
fps: isize = 0,

allocator: Allocator,
window: ?*c.GLFWwindow,
keys: StringHashMap(bool),

width: usize,
height: usize,

projection: Matrix4x4,

clear_background: ColorPrimitive,
root: *Node = undefined,

// While a render stack is unnecessary since orthographic projection supports depth buffering,
// I'm keeping this intact until I'm completely sure there's no situations
// where this would come in handy.
render_stack: ArrayList(View),

pub fn from(
    allocator: Allocator,
    options: InitialOptions,
    paint_root: fn (app: *Self) anyerror!*Node
) !Self {
    if (c.glfwInit() == c.GL_FALSE) return Error.InitializationError;
    errdefer c.glfwTerminate();

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
        return Error.InitializationError;
    }

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == c.GL_FALSE)
        return Error.InitializationError;

    c.glEnable(c.GL_CULL_FACE);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    var self: Self = .{
        .debug = options.debug, 

        .allocator = allocator,
        .window = window,
        .keys = StringHashMap(bool).init(allocator),

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

        .clear_background = try color.parse(options.background),

        .render_stack = ArrayList(View).init(allocator)
    };

    if (options.extend_render_stack) |extend_render_stack| {
        try extend_render_stack(self.allocator, &self.render_stack);
    } else try View.defaults(self.allocator, &self.render_stack);

    self.root = try paint_root(&self);

    return self;
}

pub fn deinit(self: *Self) void {
    self.root.deinit();
    self.keys.deinit();
    self.render_stack.deinit();
}

pub fn render(self: *Self) !void {
    _ = self;
}

pub fn launch(self: *Self) !void {
    var prev = c.glfwGetTime();
    var frames: isize = 0;

    c.glClearColor(
        self.clear_background[0],
        self.clear_background[1],
        self.clear_background[2],
        1.0
    );
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    c.glfwSwapBuffers(self.window);

    while (c.glfwWindowShouldClose(self.window) == c.GL_FALSE) {
        if (self.debug) {
            const timestamp = c.glfwGetTime();
            frames += 1;
            if (timestamp - prev >= 1.0) {
                self.fps = frames;
                frames = 0;
                prev = timestamp;
            }
        }

        // c.glfwSwapBuffers(@ptrCast(self.window));
        // c.glfwPollEvents();
        c.glfwWaitEvents();
    }
}