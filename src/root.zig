const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
pub const element = @import("element/root.zig");
pub const font = @import("font");
pub const math = @import("math");
pub const layout = @import("layout/root.zig");
pub const style = @import("style");
pub const util = @import("util");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

pub const Node = element.Node;
pub const Element = element.Element;
pub const View = element.View;

pub const Rectangle = element.Rectangle;

pub const color = util.color;
const ColorPrimitive = color.ColorPrimitive;

const Float = math.Float;
const Matrix = math.Matrix;
const Matrix4x4 = math.Matrix4x4;

const Self = @This();

pub const Error = error{ InitializationError, InvalidRoot };

pub const Projection = enum { ortho };

pub const InitialOptions = struct {
    initial_width: c_int = 1024,
    initial_height: c_int = 768,
    background: []const u8 = "#000000",
    title: ?[]const u8,

    projection: Projection = .ortho,
    debug: bool = false,

    // If user wants to use a custom render stack,
    // they can pass a callback function here.
    // 
    // The function can do whatever,
    // but ideally it should append views to `render_stack`.
    //
    // For an example, take a look at `defaultRenderStack()`.
    render_stack: fn(
        app: *const Self,
        render_stack: *ArrayList(View)
    ) anyerror!void = defaultRenderStack
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

// While we don't need a stack for rendering,
// we need some kind of ArrayList to keep track of what we're rendering.
//
// Not sure if there's a case where having a ordered stack might be useful,
// since we do already have access to a depth buffer to draw elements with z-index.
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

    const width: Float = @floatFromInt(options.initial_width);
    const height: Float = @floatFromInt(options.initial_height);

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
                width,
                height,
                0
            )
        },

        .clear_background = try color.parse(options.background),

        .render_stack = ArrayList(View).init(allocator)
    };

    errdefer {
        self.keys.deinit();
        self.render_stack.deinit();
    }

    try options.render_stack(&self, &self.render_stack);

    self.root = try Element(Rectangle).from(
        self.allocator,
        .{
            .styles = .{
                .top = 0,
                .left = 0,
                .width = width,
                .height = height,
                .position = .absolute
            }
        },
        .{
            paint_root(&self) catch {
                return Error.InvalidRoot;
            }
        }
    );
    try layout.calculate(self.allocator, self.root);
    try self.root.paint();

    return self;
}

pub fn deinit(self: *Self) void {
    self.root.deinit();
    self.keys.deinit();
    self.render_stack.deinit();
}

fn defaultRenderStack(self: *const Self, render_stack: *ArrayList(View)) !void {
    try Rectangle.init(self.allocator);

    c.glUniformMatrix4fv(
        Rectangle.shader.uniform("projection"),
        1,
        c.GL_FALSE,
        @ptrCast(&self.projection)
    );

    try render_stack.append(try View.from(Rectangle));
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

    while (c.glfwWindowShouldClose(self.window) == c.GL_FALSE) {
        if (self.debug) {
            const timestamp = c.glfwGetTime();
            frames += 1;
            if (timestamp - prev >= 1.0) {
                self.fps = frames;
                frames = 0;
                prev = timestamp;
                std.debug.print("{any} fps\n", .{self.fps});
            }
        }

        for (self.render_stack.items) |view| {
            try view.render();
        }

        c.glfwSwapBuffers(self.window);
        c.glfwPollEvents();
        // c.glfwWaitEvents();
    }
}