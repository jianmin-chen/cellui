const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
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
const TEXTURE_SIZE = 2;
const INSTANCE_SIZE = DEST_SIZE + SRC_SIZE + TEXTURE_SIZE;

const INDICES_SIZE = 6;

const MAX_IMAGES_PER_BUFFER = std.math.maxInt(c_int);

pub const vertex = 
    \\#version 330 core
    \\
    \\layout (location = 0) in vec4 base;
    \\layout (location = 1) in vec4 dest;
    \\layout (location = 2) in vec4 src;
    \\layout (location = 3) in vec2 tex;
    \\
    \\out vec2 tex_coord;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  vec2 xy = base.xy * dest.zw + dest.xy;
    \\  gl_Position = projection * vec4(xy, 0.0, 1.0);
    \\  vec2 sxy = src.xy / tex;
    \\  vec2 swh = src.zw / tex;
    \\  tex_coord = vec2(
    \\      max(base.z * (sxy.x + swh.x), sxy.x),
    \\      max(base.w * (sxy.y + swh.y), sxy.y)
    \\  ); 
    \\}
;

pub const fragment = 
    \\#version 330 core
    \\
    \\in vec2 tex_coord;
    \\
    \\out vec4 color;
    \\
    \\uniform sampler2D tex;
    \\
    \\void main() {
    \\  color = texture(tex, tex_coord);
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
            .linear_mipmap_linear => c.GL_LINEAR_MIPMAP_LINEAR
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
        min_filter: ?MipmapOption = .linear,
        mag_filter: ?MipmapOption = .linear,

        sx: f32 = 0,
        sy: f32 = 0,
        swidth: ?f32 = null,
        sheight: ?f32 = null
    }
);

pub const Attributes = struct {
    styles: Styles,

    texture: ?[]u8 = null,
    texture_id: ?usize = null,
    texture_level: isize = 0,
    texture_channels: ?isize = null,
    texture_width: ?isize = null,
    texture_height: ?isize = null
};

pub const Texture = struct {
    amount: usize = 1,
    vao: c_uint,
    vbo: c_uint,

    width: f32,
    height: f32,

    pub fn init(instance: [INSTANCE_SIZE]f32) Texture {
        var vao: c_uint = undefined;
        var vbo: c_uint = undefined;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);

        c.glBindVertexArray(vao);

        // Base
        c.glBindBuffer(c.GL_ARRAY_BUFFER, base_vbo);
        c.glVertexAttribPointer(
            0,
            VERTEX_SIZE,
            c.GL_FLOAT,
            c.GL_FALSE,
            VERTEX_SIZE * @sizeOf(c.GLfloat),
            null
        );
        c.glEnableVertexAttribArray(0);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(c.GLfloat) * INSTANCE_SIZE * MAX_IMAGES_PER_BUFFER,
            null,
            c.GL_DYNAMIC_DRAW
        );

        c.glBufferSubData(
            c.GL_ARRAY_BUFFER,
            0,
            @sizeOf(c.GLfloat) * INSTANCE_SIZE,
            @ptrCast(&instance[0])
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
            c.GL_FALSE,
            INSTANCE_SIZE * @sizeOf(c.GLfloat),
            source_offset
        );
        c.glEnableVertexAttribArray(2);
        c.glVertexAttribDivisor(2, 1);

        // Original texture = { texture width, texture height }
        // Used with source for cropping.
        const texture_offset: *const anyopaque = @ptrFromInt((DEST_SIZE + SRC_SIZE) * @sizeOf(c.GLfloat));
        c.glVertexAttribPointer(
            3,
            TEXTURE_SIZE,
            c.GL_FLOAT,
            c.GL_FALSE,
            INSTANCE_SIZE * @sizeOf(c.GLfloat),
            texture_offset
        );
        c.glEnableVertexAttribArray(3);
        c.glVertexAttribDivisor(3, 1);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);

        return .{
            .vao = vao,
            .vbo = vbo,
            .width = instance[8],
            .height = instance[9]
        };
    }

    pub fn increment(self: Texture, instance: [INSTANCE_SIZE - 2]f32) Texture {
        const instance_data = instance ++ [_]f32{ self.width, self.height };

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferSubData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(c.GLfloat) * @as(c.GLint, @intCast(self.amount * INSTANCE_SIZE)),
            @sizeOf(c.GLfloat) * INSTANCE_SIZE,
            @ptrCast(&instance_data[0])
        );

        return .{
            .amount = self.amount + 1,
            .vao = self.vao,
            .vbo = self.vbo,

            .width = self.width,
            .height = self.height
        };
    }

    pub fn render(self: Texture) void {
        c.glBindVertexArray(self.vao);
        c.glDrawElementsInstanced(
            c.GL_TRIANGLES,
            @intCast(INDICES_SIZE),
            c.GL_UNSIGNED_INT,
            null,
            @intCast(self.amount)
        );
    }
};

pub var shader: Shader = undefined;
pub var base_vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;

pub var textures: HashMap(c_uint, Texture) = undefined;

pub fn init(allocator: Allocator) !void {
    shader = try Shader.init(vertex, fragment);
    textures = HashMap(c_uint, Texture).init(allocator);

    c.glGenBuffers(1, &base_vbo);
    c.glGenBuffers(1, &ebo);

    // Base image rectangle: 1x1 pixel in top-left corner, covers entire source image.
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
    var it = textures.keyIterator();
    while (it.next()) |tex_id| {
        c.glDeleteTextures(1, @ptrCast(&tex_id));
    }
    textures.deinit();

    shader.deinit();
}

pub fn paint(attributes: Attributes) !void {
    const styles = attributes.styles;

    const top = styles.top.?;
    const left = styles.left.?;

    if (attributes.texture) |data| {
        const width: f32 = styles.width orelse @floatFromInt(attributes.texture_width.?);
        const height: f32 = styles.height orelse @floatFromInt(attributes.texture_height.?);
        const texture_width = attributes.texture_width.?;
        const texture_height = attributes.texture_height.?;

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        var texture: c_uint = undefined;
        c.glGenTextures(1, &texture);
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

        assert(
            !((styles.min_filter == null and styles.mag_filter != null)
                or (styles.min_filter != null and styles.mag_filter == null))
        );
        if (styles.min_filter) |min_filter| {
            c.glTexParameteri(
                c.GL_TEXTURE_2D,
                c.GL_TEXTURE_MIN_FILTER,
                MipmapOption.to_flag(min_filter)
            );
        }
        if (styles.mag_filter) |mag_filter| {
            assert(MipmapOption.valid(mag_filter, c.GL_TEXTURE_MAG_FILTER));
            c.glTexParameteri(
                c.GL_TEXTURE_2D,
                c.GL_TEXTURE_MAG_FILTER,
                MipmapOption.to_flag(mag_filter)
            );
        }

        const format: c.GLint = switch (attributes.texture_channels.?) {
            3 => c.GL_RGB,
            4 => c.GL_RGBA,
            else => return error.UnsupportedImageFormat
        };
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            @intCast(attributes.texture_level),
            format,
            @intCast(texture_width),
            @intCast(texture_height),
            0,
            @intCast(format),
            c.GL_UNSIGNED_BYTE,
            @ptrCast(&data[0])
        );

        if (styles.min_filter != null and styles.mag_filter != null)
            c.glGenerateMipmap(c.GL_TEXTURE_2D);
        
        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 4);

        const swidth: f32 = styles.swidth orelse @floatFromInt(texture_width);
        const sheight: f32 = styles.sheight orelse @floatFromInt(texture_height);

        try textures.put(
            texture,
            Texture.init(
                [_]c.GLfloat{
                    left, top, width, height,
                    styles.sx, styles.sy, swidth, sheight,
                    @floatFromInt(texture_width), @floatFromInt(texture_height)
                }
            )
        );
    } else if (attributes.texture_id) |texture_id| {
        const id: c_uint = @intCast(texture_id);
        if (textures.get(id)) |texture| {
            const width = styles.width orelse texture.width;
            const height = styles.height orelse texture.height;
            const swidth: f32 = styles.swidth orelse texture.width;
            const sheight: f32 = styles.sheight orelse texture.height;
            try textures.put(
                id,
                texture.increment(
                    [_]c.GLfloat{
                        left, top, width, height,
                        styles.sx, styles.sy, swidth, sheight
                    }
                )
            );
        } else return error.TextureNotFound;
    } else return error.NoTextureReference;
}

pub fn render() !void {
    shader.use();

    var it = textures.iterator();
    while (it.next()) |entry| {
        const id = entry.key_ptr.*;
        const texture = entry.value_ptr.*;
    
        c.glBindTexture(c.GL_TEXTURE_2D, id);
        texture.render();
    }
}