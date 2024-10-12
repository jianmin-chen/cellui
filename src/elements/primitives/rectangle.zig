const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const style = @import("style");
const Color = @import("color").ColorPrimitive;
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

const INDICES_SIZE = 6; // Two triangles, three vertices each.
const VERTEX_SIZE = 5;  // vec2 pos + vec3 color
const VERTICES_SIZE = VERTEX_SIZE * 4;
pub const MAX_RECTANGLES = std.math.maxInt(c_int);
const RECTANGLE_BUFFER_SIZE = VERTICES_SIZE * MAX_RECTANGLES;

pub const vertex =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec2 pos;
    \\layout (location = 1) in vec3 color;
    \\
    \\out vec3 box_color;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  gl_Position = projection * vec4(pos, 0.0, 1.0);
    \\  box_color = color;
    \\}
;

pub const fragment =
    \\#version 330 core
    \\
    \\in vec3 box_color;
    \\
    \\out vec4 color;
    \\
    \\float rounded(vec2 p, vec2 b, vec4 r) {
    \\  // r = { top-right, bottom-right, top-left, bottom-left }
    \\  r.xy = (p.x > 0.0) ? r.xy : r.zw;
    \\  r.x = (p.y > 0.0) ? r.x : r.y;
    \\  vec2 sl = abs(p) - b + r.x;
    \\  return min(max(sl.x, sl.y), 0.0) + length(max(sl, 0.0)) - r.x;
    \\}
    \\
    \\void main() {
    \\  color = vec4(box_color, 1.0);
    \\}
;

pub const Styles = style.merge(
    style.ViewStyles,
    struct {}
);

pub var shader: Shader = undefined;
pub var vao: c_uint = undefined;
pub var vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub var rectangle_count: usize = 0;

pub fn init(_: Allocator) !void {
    shader = try Shader.init(vertex, fragment);

    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(c.GLfloat) * RECTANGLE_BUFFER_SIZE,
        null,
        c.GL_DYNAMIC_DRAW
    );

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        @sizeOf(c.GLint) * INDICES_SIZE * MAX_RECTANGLES,
        null,
        c.GL_DYNAMIC_DRAW
    );

    // Position
    c.glVertexAttribPointer(
        0,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        VERTEX_SIZE * @sizeOf(c.GLfloat),
        null
    );
    c.glEnableVertexAttribArray(0);

    // Color
    const color_offset: *const anyopaque = @ptrFromInt(2 * @sizeOf(c.GLfloat));
    c.glVertexAttribPointer(
        1,
        3,
        c.GL_FLOAT,
        c.GL_FALSE,
        VERTEX_SIZE * @sizeOf(c.GLfloat),
        color_offset
    );
    c.glEnableVertexAttribArray(1);
    c.glVertexAttribDivisor(1, 3);
}

pub fn deinit() void {
    // c.glDeleteBuffers(1, &vbo);
    // c.glDeleteBuffers(1, &ebo);
    c.glDeleteVertexArrays(1, &vao);
    shader.deinit();
}

pub fn paint(styles: Styles) !void {
    shader.use();

    c.glBindVertexArray(vao);

    const background_color = styles.background_color orelse unreachable;
    const top = styles.top orelse unreachable;
    const left = styles.left orelse unreachable;
    const width = styles.width orelse unreachable;
    const height = styles.height orelse unreachable;

    const vertices = [_]c.GLfloat{
        left, top + height, background_color[0], background_color[1], background_color[2],
        left, top, background_color[0], background_color[1], background_color[2],
        left + width, top, background_color[0], background_color[1], background_color[2],
        left + width, top + height, background_color[0], background_color[1], background_color[2]
    };

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferSubData(
        c.GL_ARRAY_BUFFER,
        @as(c.GLint, @intCast(rectangle_count * VERTICES_SIZE)) * @sizeOf(c.GLfloat),
        @sizeOf(c.GLfloat) * VERTICES_SIZE,
        @ptrCast(&vertices[0])
    );

    const index_offset: c_int = @as(c_int, @intCast(rectangle_count)) * 4;
    const indices = [_]c.GLint{
        3 + index_offset, 1 + index_offset, index_offset,
        3 + index_offset, 2 + index_offset, 1 + index_offset
    };

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferSubData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        @as(c.GLint, @intCast(rectangle_count * INDICES_SIZE)) * @sizeOf(c.GLint),
        @sizeOf(c.GLint) * INDICES_SIZE,
        @ptrCast(&indices[0])
    );

    rectangle_count += 1;
}

pub fn render() !void {
    shader.use();

    c.glBindVertexArray(vao);

    c.glDrawElements(
        c.GL_TRIANGLES,
        @intCast(rectangle_count * 6),
        c.GL_UNSIGNED_INT,
        null
    );
}
