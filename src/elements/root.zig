const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const math = @import("math");

pub const Element = @import("element.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn setup(allocator: Allocator, width: usize, height: usize) !void {
    try Element.Rectangle.init(allocator);
    viewport(width, height);
}

pub fn viewport(width: usize, height: usize) void {
    const projection = math.Matrix.ortho(
        0,
        @floatFromInt(width),
        @floatFromInt(height),
        0
    );
    c.glUniformMatrix4fv(
        Element.Rectangle.shader.uniform("projection"),
        1,
        c.GL_FALSE,
        @ptrCast(&projection)
    );
}

pub fn cleanup() void {
    Element.Rectangle.deinit();
}
