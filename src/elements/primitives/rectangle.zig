const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const style = @import("style");
const util = @import("util");
const Color = @import("color").ColorPrimitive;
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

const VERTEX_SIZE = 2;
const VERTICES_SIZE = VERTEX_SIZE * 4;

const RECTANGLE_SIZE = 4;
const COLOR_SIZE = 4;
const RADII_SIZE = 4;
const BORDER_SIZE = 4;
const INSTANCE_SIZE = RECTANGLE_SIZE + COLOR_SIZE + RADII_SIZE + BORDER_SIZE * 5;

const INDICES_SIZE = 6;

const MAX_RECTANGLES = std.math.maxInt(c_int);

pub const vertex = 
    \\#version 330 core
    \\
    \\layout (location = 0) in vec2 base;
    \\layout (location = 1) in vec4 rectangle;
    \\layout (location = 2) in vec4 color;
    \\layout (location = 3) in vec4 radii;
    \\layout (location = 4) in vec4 borders;
    \\layout (location = 5) in vec4 border_top;
    \\layout (location = 6) in vec4 border_right;
    \\layout (location = 7) in vec4 border_bottom;
    \\layout (location = 8) in vec4 border_left;
    \\
    \\out vec4 rect_dim;
    \\out vec4 rect_color;
    \\out vec4 rect_radii;
    \\out mat4 proj;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  vec2 xy = base * rectangle.zw + rectangle.xy;
    \\  gl_Position = projection * vec4(xy, 0.0, 1.0);
    \\  rect_dim = rectangle;
    \\  rect_color = color;
    \\  rect_radii = radii;
    \\  proj = projection;
    \\}
;

pub const fragment = 
    \\#version 330 core
    \\
    \\in vec4 rect_dim;
    \\in vec4 rect_color;
    \\in vec4 rect_radii;
    \\in mat4 proj;
    \\
    \\out vec4 out_color;
    \\
    \\float rounded(vec2 p, vec2 b, vec4 r) {
    \\  r.xy = (p.x > 0.0) ? r.xy : r.zw;
    \\  r.x = (p.y > 0.0) ? r.x : r.y;
    \\  vec2 sl = abs(p) - b + r.x;
    \\  return min(max(sl.x, sl.y), 0.0) + length(max(sl, 0.0)) - r.x;
    \\}
    \\
    \\void main() {
    \\  out_color = rect_color;
    \\}
;

pub const Styles = style.merge(
    style.ViewStyles,
    struct {}
);

pub const Attributes = struct {
    styles: Styles
};

pub var shader: Shader = undefined;
pub var vao: c_uint = undefined;
pub var base_vbo: c_uint = undefined;
pub var instanced_vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub var rectangle_count: usize = 0;

pub fn init(_: Allocator) !void {
    shader = try Shader.init(vertex, fragment);

    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &base_vbo);
    c.glGenBuffers(1, &instanced_vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    // Base rectangle: 1x1 pixel in top-left corner.
    const base_vertices = [_]c.GLfloat{
        0, 1,
        0, 0,
        1, 0,
        1, 1
    };

    c.glBindBuffer(c.GL_ARRAY_BUFFER, base_vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(c.GLfloat) * VERTICES_SIZE,
        @ptrCast(&base_vertices[0]),
        c.GL_STATIC_DRAW
    );

    // Base
    c.glVertexAttribPointer(
        0,
        VERTEX_SIZE,
        c.GL_FLOAT,
        c.GL_FALSE,
        VERTEX_SIZE * @sizeOf(c.GLfloat),
        null
    );
    c.glEnableVertexAttribArray(0);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, instanced_vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(c.GLfloat) * INSTANCE_SIZE * MAX_RECTANGLES,
        null,
        c.GL_DYNAMIC_DRAW
    );

    // Rectangle = { x, y, width, height }
    c.glVertexAttribPointer(
        1,
        RECTANGLE_SIZE,
        c.GL_FLOAT,
        c.GL_FALSE,
        INSTANCE_SIZE * @sizeOf(c.GLfloat),
        null
    );
    c.glEnableVertexAttribArray(1);
    c.glVertexAttribDivisor(1, 1);

    // Color
    const color_offset: *const anyopaque = @ptrFromInt(RECTANGLE_SIZE * @sizeOf(c.GLfloat));
    c.glVertexAttribPointer(
        2,
        COLOR_SIZE,
        c.GL_FLOAT,
        c.GL_FALSE,
        INSTANCE_SIZE * @sizeOf(c.GLfloat),
        color_offset
    );
    c.glEnableVertexAttribArray(2);
    c.glVertexAttribDivisor(2, 1);

    // Radii
    const radii_offset: *const anyopaque = @ptrFromInt((RECTANGLE_SIZE + COLOR_SIZE) * @sizeOf(c.GLfloat));
    c.glVertexAttribPointer(
        3,
        RADII_SIZE,
        c.GL_FLOAT,
        c.GL_FALSE,
        INSTANCE_SIZE * @sizeOf(c.GLfloat),
        radii_offset
    );
    c.glEnableVertexAttribArray(3);
    c.glVertexAttribDivisor(3, 1);

    // Border
    for (0..5) |offset| {
        const border_offset: *const anyopaque = @ptrFromInt((RECTANGLE_SIZE + COLOR_SIZE + RADII_SIZE + BORDER_SIZE * offset) * @sizeOf(c.GLfloat));
        c.glVertexAttribPointer(
            @intCast(4 + offset),
            BORDER_SIZE,
            c.GL_FLOAT,
            c.GL_FALSE,
            BORDER_SIZE * @sizeOf(c.GLfloat),
            border_offset
        );
        c.glEnableVertexAttribArray(@intCast(4 + offset));
        c.glVertexAttribDivisor(@intCast(4 + offset), 1);
    }

    const indices = [_]c.GLuint{
        3, 1, 0,
        3, 2, 1
    };

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        @sizeOf(c.GLuint) * INDICES_SIZE,
        @ptrCast(&indices[0]),
        c.GL_STATIC_DRAW
    );
}

pub fn deinit() void {
    c.glDeleteVertexArrays(1, &vao);
    shader.deinit();
}

pub fn paint(attributes: Attributes) !void {
    shader.use();

    c.glBindVertexArray(vao);

    const styles = attributes.styles;

    const background_color = styles.background_color orelse unreachable;
	const border_radii = styles.border_radius orelse unreachable;
	const border_width = styles.border_width orelse unreachable;
	const border_color = styles.border_color orelse unreachable;
	const border_top = border_color[0];
	const border_right = border_color[1];
	const border_bottom = border_color[2];
	const border_left = border_color[3];
	const left = styles.left orelse unreachable;
	const top = styles.top orelse unreachable;
	const width = styles.width orelse unreachable;
	const height = styles.height orelse unreachable;

	const instance = [_]c.GLfloat{
	    left, top, width, height,
		background_color[0], background_color[1], background_color[2], background_color[3],
		border_radii[0], border_radii[1], border_radii[2], border_radii[3],
		border_width[0], border_width[1], border_width[2], border_width[3],
		border_top[0], border_top[1], border_top[2], border_top[3],
		border_right[0], border_right[1], border_right[2], border_right[3],
		border_bottom[0], border_bottom[1], border_bottom[2], border_bottom[3],
		border_left[0], border_left[1], border_left[2], border_left[3],
	};

	c.glBindBuffer(c.GL_ARRAY_BUFFER, instanced_vbo);
	c.glBufferSubData(
	    c.GL_ARRAY_BUFFER,
		@as(c.GLint, @intCast(rectangle_count * INSTANCE_SIZE)) * @sizeOf(c.GLfloat),
		@sizeOf(c.GLfloat) * INSTANCE_SIZE,
		@ptrCast(&instance[0])
	);

	rectangle_count += 1;
}

pub fn render() !void {
	shader.use();

	c.glBindVertexArray(vao);

	c.glDrawElementsInstanced(
		c.GL_TRIANGLES,
		@intCast(INDICES_SIZE),
		c.GL_UNSIGNED_INT,
		null,
		@intCast(rectangle_count)
	);
}
