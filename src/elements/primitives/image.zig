const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;

const Self = @This();

pub const vertex =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec4 vertex;
    \\
    \\out vec2 tex_coords;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  gl_Position = projection * vec4(pos.xy, 0.0, 1.0);
    \\  tex_coords = vertex.zw;
    \\}
;

pub const fragment =
    \\#version 330 core
    \\
    \\in vec2 tex_coords;
    \\
    \\out vec4 color;
    \\
    \\uniform sampler2D img;
    \\
    \\void main() {
    \\  color = texture(img, tex_coords);
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
    src: ?[]const u8 = null
};

pub var shader: Shader = undefined;
