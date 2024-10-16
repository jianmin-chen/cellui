// Canvas-style implementation.

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("stb_image.h");
});
const std = @import("std");
const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Self = @This();

const INDICES_SIZE = 6;
const VERTEX_SIZE = 4;
const VERTICES_SIZE = VERTEX_SIZE * 4;
pub const MAX_TEXTURES = std.math.maxInt(c_int);
const TEXTURE_BUFFER_SIZE = VERTICES_SIZE * MAX_TEXTURES;

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
    \\  gl_Position = projection * vec4(vertex.xy, 0.0, 1.0);
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

pub const Styles = struct {
	top: ?f32 = null,
	left: ?f32 = null,
	width: ?f32 = null,
	height: ?f32 = null,
	src: ?[]const u8 = null,
	alt: ?[]const u8 = null
};

pub var shader: Shader = undefined;
pub var vao: c_uint = undefined;
pub var vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub var textures: ArrayList(c_uint) = undefined;

pub fn init(allocator: Allocator) !void {
    shader = try Shader.init(vertex, fragment);
    textures = ArrayList(c_uint).init(allocator);

    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(c.GLfloat) * TEXTURE_BUFFER_SIZE, null, c.GL_DYNAMIC_DRAW);

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(c.GLint) * INDICES_SIZE * MAX_TEXTURES, null, c.GL_DYNAMIC_DRAW);

    // Singular vertex holds position and texcoords.
    c.glVertexAttribPointer(0, VERTEX_SIZE, c.GL_FLOAT, c.GL_FALSE, VERTEX_SIZE * @sizeOf(c.GLfloat), null);
    c.glEnableVertexAttribArray(0);
}

pub fn deinit() void {
    for (textures.items) |tex| {
        c.glDeleteTextures(1, &tex);
    }
    textures.deinit();
    c.glDeleteVertexArrays(1, &vao);
    shader.deinit();
}

pub fn paint(styles: Styles) !void {
    shader.use();

    const top = styles.top orelse unreachable;
    const left = styles.left orelse unreachable;
    var width = styles.width orelse unreachable;
    var height = styles.height orelse unreachable;
    const src = styles.src orelse unreachable;

    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

    var w: c_int = undefined;
    var h: c_int = undefined;
    var nr_channels: c_int = undefined;

    const img = c.stbi_load(@ptrCast(src), &w, &h, &nr_channels, 0);
    if (img == null) {
        // TODO: Alt text
        return error.ImageNotFound;
    }
    defer c.stbi_image_free(img);

    const format: c.GLint = switch (nr_channels) {
        3 => c.GL_RGB,
        4 => c.GL_RGBA,
        else => return error.UnsupportedImageFormat,
    };

    var texture: c_uint = undefined;
    c.glGenTextures(1, &texture);
    try textures.append(texture);

    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, format, w, h, 0, @intCast(format), c.GL_UNSIGNED_BYTE, @ptrCast(&img[0]));
    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 4);

    const window_aspect_ratio: f32 = 1300 / 1200;
    const texture_aspect_ratio = @as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(h));
    if (window_aspect_ratio > texture_aspect_ratio) {
        width = height * texture_aspect_ratio;
    } else {
        height = width / texture_aspect_ratio;
    }

    const vertices = [_]c.GLfloat{ left, top + height, 0.0, 1.0, left, top, 0.0, 0.0, left + width, top, 1.0, 0.0, left + width, top + height, 1.0, 1.0 };

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferSubData(c.GL_ARRAY_BUFFER, @as(c.GLint, @intCast(textures.items.len * VERTICES_SIZE)) * @sizeOf(c.GLfloat), @sizeOf(c.GLfloat) * VERTICES_SIZE, @ptrCast(&vertices[0]));

    const index_offset: c_int = @as(c_int, @intCast(textures.items.len)) * 4;
    const indices = [_]c.GLint{ 3 + index_offset, 1 + index_offset, index_offset, 3 + index_offset, 2 + index_offset, 1 + index_offset };

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferSubData(c.GL_ELEMENT_ARRAY_BUFFER, @as(c.GLint, @intCast(textures.items.len * INDICES_SIZE)) * @sizeOf(c.GLint), @sizeOf(c.GLint) * INDICES_SIZE, @ptrCast(&indices[0]));
}

pub fn render() !void {
    shader.use();

    c.glBindVertexArray(vao);

    for (textures.items) |tex| {
        c.glBindTexture(c.GL_TEXTURE_2D, tex);
        c.glDrawElements(c.GL_TRIANGLES, 12, c.GL_UNSIGNED_INT, null);
    }
}
