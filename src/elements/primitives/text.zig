const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;

const Self = @This();

const INDICES_SIZE = 6;
const VERTEX_SIZE = 7;
const VERTICES_SIZE = VERTEX_SIZE * 4;
const MAX_TEXT_NODES = std.math.maxInt(c_int);
const TEXT_BUFFER_SIZE = VERTICES_SIZE * MAX_TEXT_NODES;

pub const vertex =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec2 position;
    \\layout (location = 1) in vec2 texcoords;
    \\layout (location = 2) in vec3 color;
    \\
    \\out vec2 tex_coords;
    \\out vec3 text_color;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  gl_Position = projection * vec4(position, 0.0, 1.0);
    \\  tex_coords = texcoords;
    \\  text_color = color;
    \\}
;

pub const fragment =
    \\#version 330 core
    \\
    \\in vec2 tex_coords;
    \\in vec3 text_color;
    \\
    \\out vec4 color;
    \\
    \\uniform sampler2D text;
    \\
    \\void main() {
    \\  vec4 sampled = vec4(1.0, 1.0, 1.0, texture(text, tex_coords).r);
    \\  color = vec4(text_color, 1.0) * sampled;
    \\}
;

pub const Styles = struct {
    top: ?f32 = null,
    left: ?f32 = null,
    width: ?f32 = null,
    height: ?f32 = null,
    color: ?Color = null
};

pub var shader: Shader = undefined;
pub var vao: c_uint = undefined;
pub var vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub var text_node_count: usize = 0;

pub fn init(_: Allocator) !void {
    shader = try Shader.init(vertex, fragment);

    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(c.GLfloat) * TEXT_BUFFER_SIZE,
        null,
        c.GL_DYNAMIC_DRAW
    );

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        @sizeOf(c.GLint) * INDICES_SIZE * MAX_TEXT_NODES,
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

    // Texcoords
    const texcoords_offset: *const anyopaque = @ptrFromInt(2 * @sizeOf(c.GLfloat));
    c.glVertexAttribPointer(
        1,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        VERTEX_SIZE * @sizeOf(c.GLfloat),
        texcoords_offset
    );
    c.glEnableVertexAttribArray(1);

    // Color
    const color_offset: *const anyopaque = @ptrFromInt(4 * @sizeOf(c.GLfloat));
    c.glVertexAttribPointer(
        2,
        3,
        c.GL_FLOAT,
        c.GL_FALSE,
        VERTEX_SIZE * @sizeOf(c.GLfloat),
        color_offset
    );
    c.glEnableVertexAttribArray(2);
}

pub fn deinit() void {
    c.glDeleteVertexArrays(1, &vao);
    shader.deinit();
}

pub fn paint(styles: Styles) !void {
    shader.use();

    c.glBindVertexArray(vao);

    _ = styles;
}

pub fn render() !void {
    shader.use();

    c.glBindVertexArray(vao);
}
