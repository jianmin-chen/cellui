const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");

pub const Element = @import("element.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn setup(allocator: Allocator, width: usize, height: usize) !void {
    try Element.Rectangle.init(allocator);
}
