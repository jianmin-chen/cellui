// This uses 1/3 of the texture units available on target,
// not bindless textures due to general target incompatability.

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("stb_image.h");
});
const std = @import("std");
const style = @import("style");

const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;
const assert = std.debug.assert;

const Self = @This();

const VERTEX_SIZE = 4;
const VERTICES_SIZE = VERTEX_SIZE * 4;

const DEST_SIZE = 4;
const SRC_SIZE = 4;
const INSTANCE_SIZE = DEST_SIZE + SRC_SIZE;

const INDICES_SIZE = 6;

const MAX_IMAGES = std.math.maxInt(c_int);

pub const vertex =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec4 base;
    \\layout (location = 1) in vec4 dest;
    \\layout (location = 2) in vec4 src;
    \\
    \\out vec2 tex_coords;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  vec2 xy = base.xy * dest.zw + dest.xy;
    \\  gl_Position = projection * vec4(xy, 0.0, 1.0);
    \\  tex_coords = base.zw;
    \\}
;

pub const fragment =
    \\#version 330 core
    \\
    \\in vec2 tex_coords;
    \\
    \\out vec4 color;
    \\
    \\uniform sampler2D tex;
    \\
    \\void main() {
    \\  color = texture(tex, tex_coords);
    \\}
;

pub const WrapOption = enum {
    clamp_to_edge,
    clamp_to_border,
    mirrored_repeat,
    repeat,
    mirror_clamp_to_edge,

    pub fn to_flag(self: WrapOption) c.GLint {
        return switch (self) {
            .clamp_to_edge => c.GL_CLAMP_TO_EDGE,
            .clamp_to_border => c.GL_CLAMP_TO_BORDER,
            .mirrored_repeat => c.GL_MIRRORED_REPEAT,
            .repeat => c.GL_REPEAT,
            .mirror_clamp_to_edge => c.GL_MIRROR_CLAMP_TO_EDGE
        };
    }
};

pub const MipmapOption = enum {
    none,
    nearest,
    linear,
    nearest_mipmap_nearest,
    linear_mipmap_nearest,
    nearest_mipmap_linear,
    linear_mipmap_linear,

    pub fn to_flag(self: MipmapOption) c.GLint {
        return switch (self) {
            .nearest => c.GL_NEAREST,
            .linear => c.GL_LINEAR,
            .nearest_mipmap_nearest => c.GL_NEAREST_MIPMAP_NEAREST,
            .linear_mipmap_nearest => c.GL_LINEAR_MIPMAP_NEAREST,
            .nearest_mipmap_linear => c.GL_NEAREST_MIPMAP_LINEAR,
            .linear_mipmap_linear => c.GL_LINEAR_MIPMAP_LINEAR,
            else => unreachable
        };
    }

    pub fn valid(self: MipmapOption, flag: c.GLint) bool {
        if (flag == c.GL_TEXTURE_MAG_FILTER) {
            if (self != .nearest and self != .linear) return false;
        }

        return true;
    }
};

pub const Styles = style.merge(
    style.ViewStyles,
    struct {
        wrap_horizontal: WrapOption = .clamp_to_border,
        wrap_vertical: WrapOption = .clamp_to_border,
        min_filter: MipmapOption = .linear,
        mag_filter: MipmapOption = .linear,

        sx: ?f32 = 0,
        sy: ?f32 = 0,
        swidth: ?f32 = null,
        sheight: ?f32 = null
    }
);

pub const Attributes = struct {
    styles: Styles,

    texture: ?[]u8 = null,
    texture_id: ?usize = null,
    texture_level: ?c_int = 0,
    texture_channels: ?isize = 3,
    texture_width: ?isize = 0,
    texture_height: ?isize = 0
};

pub const Texture = struct {
    amount: usize = 1
};

pub var shader: Shader = undefined;
pub var vao: c_uint = undefined;
pub var base_vbo: c_uint = undefined;
pub var instanced_vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub var textures: HashMap(c_uint, Texture) = undefined;
pub var texture_count: usize = 0;

pub fn init(allocator: Allocator) !void {
    shader = try Shader.init(vertex, fragment);
    textures = HashMap(c_uint, Texture).init(allocator);

    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &base_vbo);
    c.glGenBuffers(1, &instanced_vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    // Base rectangle: 1x1 pixel in top-left corner, covers entire source image.
    const base_vertices = [_]c.GLfloat{
        0, 1, 0, 1,
        0, 0, 0, 0,
        1, 0, 1, 0,
        1, 1, 1, 1
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
        @sizeOf(c.GLfloat) * INSTANCE_SIZE * MAX_IMAGES,
        null,
        c.GL_DYNAMIC_DRAW
    );

    // Destination = { dx, dy, dwidth, dheight }
    c.glVertexAttribPointer(
        1,
        DEST_SIZE,
        c.GL_FLOAT,
        c.GL_FALSE,
        INSTANCE_SIZE * @sizeOf(c.GLfloat),
        null
    );
    c.glEnableVertexAttribArray(1);
    c.glVertexAttribDivisor(1, 1);

    // Source = { sx, sy, swidth, sheight }
    const source_offset: *const anyopaque = @ptrFromInt(DEST_SIZE * @sizeOf(c.GLfloat));
    c.glVertexAttribPointer(
        2,
        SRC_SIZE,
        c.GL_FLOAT,
        c.GL_TRUE,
        INSTANCE_SIZE * @sizeOf(c.GLfloat),
        source_offset
    );
    c.glEnableVertexAttribArray(2);
    c.glVertexAttribDivisor(2, 1);

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

    var allocated_units: c.GLint = undefined;
    c.glGetIntegerv(c.GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, &allocated_units);
    std.debug.print("{any}\n", .{allocated_units});
}

pub fn deinit() void {
    var it = textures.keyIterator();
    while (it.next()) |tex_id| {
        c.glDeleteTextures(1, @ptrCast(&tex_id));
    }
    textures.deinit();

    c.glDeleteVertexArrays(1, &vao);
    shader.deinit();
}

pub fn paint(attributes: Attributes) !void {
    shader.use();

    const styles = attributes.styles;

    const top = styles.top orelse unreachable;
    const left = styles.left orelse unreachable;
    const width: f32 = styles.width orelse @floatFromInt(attributes.texture_width orelse unreachable);
    const height: f32 = styles.height orelse @floatFromInt(attributes.texture_height orelse unreachable);

    if (attributes.texture) |data| {
        const texture_width = attributes.texture_width orelse unreachable;
        const texture_height = attributes.texture_height orelse unreachable;
        const sx = styles.sx orelse unreachable;
        const sy = styles.sy orelse unreachable;

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        var texture: c_uint = undefined;
        c.glGenTextures(1, &texture);
        try textures.put(texture, Texture{});

        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_WRAP_S,
            WrapOption.to_flag(styles.wrap_horizontal)
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_WRAP_T,
            WrapOption.to_flag(styles.wrap_vertical)
        );
        if (styles.min_filter != .none)
            c.glTexParameteri(
                c.GL_TEXTURE_2D,
                c.GL_TEXTURE_MIN_FILTER,
                MipmapOption.to_flag(styles.min_filter)
            );
        if (styles.mag_filter != .none) {
            assert(MipmapOption.valid(styles.mag_filter, c.GL_TEXTURE_MAG_FILTER));
            c.glTexParameteri(
                c.GL_TEXTURE_2D,
                c.GL_TEXTURE_MAG_FILTER,
                MipmapOption.to_flag(styles.mag_filter)
            );
        }

        const format: c.GLint = switch (attributes.texture_channels orelse 3) {
            3 => c.GL_RGB,
            4 => c.GL_RGBA,
            else => return error.UnsupportedImageFormat
        };
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            attributes.texture_level orelse unreachable,
            format,
            @intCast(texture_width),
            @intCast(texture_height),
            0,
            @intCast(format),
            c.GL_UNSIGNED_BYTE,
            @ptrCast(&data[0])
        );

        if (styles.min_filter != .none or styles.mag_filter != .none)
            c.glGenerateMipmap(c.GL_TEXTURE_2D);

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 4);

        const instance = [_]c.GLfloat{
            left, top, width, height,
            sx, sy, @floatFromInt(texture_width), @floatFromInt(texture_height)
        };
        std.debug.print("{any}\n", .{instance});

        c.glBindBuffer(c.GL_ARRAY_BUFFER, instanced_vbo);
        c.glBufferSubData(
            c.GL_ARRAY_BUFFER,
            @as(c.GLint, @intCast(texture_count * INSTANCE_SIZE)) * @sizeOf(c.GLfloat),
            @sizeOf(c.GLfloat) * INSTANCE_SIZE,
            @ptrCast(&instance[0])
        );
    } else if (attributes.texture_id) |texture_id| {
        _ = texture_id;
    }

    texture_count += 1;
}

pub fn render() !void {
    shader.use();

    c.glBindVertexArray(vao);

    var it = textures.iterator();
    while (it.next()) |entry| {
        const texture = entry.value_ptr.*;
        c.glBindTexture(c.GL_TEXTURE_2D, entry.key_ptr.*);
        c.glDrawElementsInstanced(
            c.GL_TRIANGLES,
            @intCast(INDICES_SIZE),
            c.GL_UNSIGNED_INT,
            null,
            @intCast(texture.amount)
        );
    }
}
