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

pub const vertex =
	\\#version 330 core
	\\
	\\layout (location = 0) in vec2 base;
	\\layout (location = 1) in vec4 text;
	\\layout (location = 2) in vec2 texcoords;
	\\
	\\out vec2 tex_coords;
	\\
	\\uniform mat4 projection;
	\\
	\\void main() {
	\\	vec2 xy = base *
	\\	gl_Position = projection * vec4(text.xy, 0.0, 1.0);
	\\	tex_coords = texcoords;
	\\}
;

pub const fragment =
	\\#version 330 core
	\\
	\\in vec2 tex_coords;
	\\
	\\out vec4 color;
	\\
	\\uniform sampler2D atlas;
	\\
	\\void main() {
	\\	float alpha = texture(atlas, tex_coords).r;
;

pub const Styles = style.merge(
	style.ViewStyles,
	struct {
		color: ?Color = Color{ 0.0, 0.0, 0.0, 1.0 }
	}
);

pub var shader: Shader = undefined;
pub var vao: c_uint = undefined;
pub var base_vbo: c_uint = undefined;
pub var instanced_vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub fn init(_: Allocator) !void {
	shader = try Shader.init(vertex, fragment);

	c.glGenVertexArrays(1, &vao);
	c.glGenBuffers(1, &base_vbo);
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
