const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const Color = @import("color").ColorPrimitive;
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

pub const vertex =
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

pub const fragment =
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

pub const Styles = struct {
    top: ?f32 = null,
    left: ?f32 = null,
    width: ?f32 = null,
    height: ?f32 = null,
    color: ?Color = null
};

pub var shader: Shader = undefined;

pub fn init(_: Allocator) !void {
    shader = try Shader.init(vertex, fragment, true);

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

pub fn render(styles: Styles) !void {
    shader.use();

    const color = styles.color orelse unreachable;
    const top = styles.top orelse unreachable;
    const left = styles.left orelse unreachable;
    const width = styles.width orelse unreachable;
    const height = styles.height orelse unreachable;

    c.glUniform3fv(shader.uniform("box_color"), 1, @ptrCast(&color[0]));

    const vertices = [_]c.GLfloat{
        left, top + height,
        left, top,
        left + width, top,
        left + width, top + height
    };

    c.glBindVertexArray(shader.vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, shader.vbo);
    c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @sizeOf(c.GLfloat) * vertices.len, @ptrCast(&vertices[0]));

    c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
}
