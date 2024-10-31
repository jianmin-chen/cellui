// Having a text primitive is more complicated than
// having an image or rectangle primitive because it's hard
// to draw a line for its capabilities.
// 
// This should render any UTF-8 string passed in,
// accounting for shaping and bidirectionality, 
// and a subset of breaking as needed for layout.
// 
// Derivatives could perhaps use the `font` module themselves?

const c = @cImport({
	@cInclude("glad/glad.h");
	@cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const fontgen = @import("font");
const style = @import("style");
const Color = @import("color").ColorPrimitive;
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;

const Character = fontgen.Character;
const Font = fontgen.Font;

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
	\\	color = vec4(1.0, 1.0, 1.0, alpha);
	\\}
;

pub const Styles = style.merge(
	style.ViewStyles,
	struct {
		color: ?Color = Color{ 0.0, 0.0, 0.0, 1.0 },
		font_size: usize = 14
	}
);

pub const Attributes = struct {
	styles: Styles,

	font_src: []const u8,
	text: []const u8
};

pub var shader: Shader = undefined;
pub var vao: c_uint = undefined;
pub var base_vbo: c_uint = undefined;
pub var instanced_vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub var allocator: Allocator = undefined;

pub fn init(passed_allocator: Allocator) !void {
	shader = try Shader.init(vertex, fragment);
	allocator = passed_allocator;

	c.glGenVertexArrays(1, &vao);
	c.glGenBuffers(1, &base_vbo);
	c.glGenBuffers(1, &ebo);

	// Base glyph rectangle: 1x1 pixel in top-left corner
}

pub fn deinit() void {
	c.glDeleteVertexArrays(1, &vao);
	shader.deinit();
}

pub fn paint(attributes: Attributes) !void {
	shader.use();

	c.glBindVertexArray(vao);

	const styles = attributes.styles;
	
	var font = try Font.from(
		allocator,
		attributes.font_src,
		.{
			.font_size = @intCast(styles.font_size)
		}
	);
	defer font.deinit();

	const character = font.characters.get("A");
	std.debug.print("{any}\n", .{character});
}

pub fn render() !void {
	shader.use();

	c.glBindVertexArray(vao);
}