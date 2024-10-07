const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const Color = @import("color").ColorPrimitive;
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

pub const vertex: []const u8 =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec2 pos;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  gl_Position = projection * vec4(pos, 0.0, 1.0);
    \\}
;

pub const fragment: []const u8 =
    \\#version 330 core
    \\
    \\out vec4 color;
    \\
    \\uniform vec3 box_color;
    \\
    \\void main() {
    \\  color = vec4(box_color, 1.0);
    \\}
;

const indices = [_]c.GLint{
    3, 1, 0,
    3, 2, 1
};

pub var shader: Shader = undefined;

pub fn init(_: Allocator) !void {
    shader = try Shader.init(vertex, fragment);

    c.glBindVertexArray(shader.vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, shader.vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(c.GLfloat) * 8, null, c.GL_DYNAMIC_DRAW);

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, shader.ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(c.GLint) * indices.len, @ptrCast(&indices[0]), c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(c.GLfloat), null);
    c.glEnableVertexAttribArray(0);
}

pub fn deinit() void {
    shader.deinit();
}

pub fn render(styles: anytype) !void {
    shader.use();

    c.glUniform3fv(shader.uniform("box_color"), 1, @ptrCast(&styles.color[0]));

    const vertices = [_]c.GLfloat{
        styles.x, styles.y + styles.height,
        styles.x, styles.y,
        styles.x + styles.width, styles.y,
        styles.x + styles.width, styles.y + styles.height
    };

    c.glBindBuffer(shader.vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, shader.vbo);
    c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @sizeOf(c.GLfloat) * vertices.len, @ptrCast(&vertices[0]));

    c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
}
