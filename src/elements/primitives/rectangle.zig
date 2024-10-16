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
	\\
	\\uniform mat4 projection;
	\\
	\\void main() {
	\\  vec2 xy = base * rectangle.zw + rectangle.xy;
	\\  gl_Position = projection * vec4(xy, 0.0, 1.0);
	\\  rect_dim = projection * vec4(xy, rectangle.zw);
	\\  rect_color = color;
	\\  rect_radii = radii;
	\\}
;

pub const fragment =
	\\#version 330 core
	\\
	\\in vec4 rect_dim;
	\\in vec4 rect_color;
	\\in vec4 rect_radii;
	\\
	\\out vec4 out_color;
	\\
	\\float rounded(vec2 p, vec2 b, vec4 r) {
	\\  // r = { top-right, bottom-right, top-left, bottom-left }
	\\  r.xy = (p.x > 0.0) ? r.xy : r.zw;
	\\  r.x = (p.y > 0.0) ? r.x : r.y;
	\\  vec2 sl = abs(p) - b + r.x;
	\\  return min(max(sl.x, sl.y), 0.0) + length(max(sl, 0.0)) - r.x;
	\\}
	\\
	\\vec3 border(
	\\  vec3 background
	\\) {
	\\  return background;
	\\}
	\\
	\\void main() {
	\\  float alpha = step(
	\\      0.0,
	\\      rounded(rect_dim.xy, rect_dim.zw + 1.0, vec4(0.2, 0.2, 0.2, 0.2))
	\\  );
	\\  vec3 color = border(rect_color.rgb);
	\\  out_color = vec4(color, rect_color.a * alpha);
	\\}
;

pub const Styles = style.merge(
	style.ViewStyles,
	struct {}
);

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

	// Base rectangle, 1x1 pixel in top-left corner.
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

	// Rectangle = { x, y, width, height };
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

	// Border widths
	const border_width_offset: *const anyopaque = @ptrFromInt((RECTANGLE_SIZE + COLOR_SIZE + RADII_SIZE) * @sizeOf(c.GLfloat));
	c.glVertexAttribPointer(
		4,
	 	BORDER_SIZE,
			c.GL_FLOAT,
		 	c.GL_FALSE,
		INSTANCE_SIZE * @sizeOf(c.GLfloat),
	)

	const indices = [6]c.GLuint{
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

pub fn paint(styles: Styles) !void {
	shader.use();

	c.glBindVertexArray(vao);

	const background_color = styles.background_color orelse unreachable;
	const border_radii = styles.border_radius orelse unreachable;
	const top = styles.top orelse unreachable;
	const left = styles.left orelse unreachable;
	const width = styles.width orelse unreachable;
	const height = styles.height orelse unreachable;

	const instance = [_]c.GLfloat{
		left, top, width, height,
		background_color[0], background_color[1], background_color[2], background_color[3],
		border_radii[0], border_radii[1], border_radii[2], border_radii[3]
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
