// Having a text primitive is more complicated than
// having an image or rectangle primitive because it's hard
// to draw a line for its capabilities.
//
// This should render any UTF-8 string ([]const u8) passed in,
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
const util = @import("util");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;

const Character = fontgen.Character;
const Font = fontgen.Font;

const Color = util.color.ColorPrimitive;
const Shader = util.Shader;

const Self = @This();

pub const is_void_element = false;

const VERTEX_SIZE = 4;
const VERTICES_SIZE = VERTEX_SIZE * 4;

const TEXT_SIZE = 4;
const TEXCOORD_SIZE = 2;
const INSTANCE_SIZE = TEXT_SIZE + TEXCOORD_SIZE;

const INDICES_SIZE = 6;

const MAX_TEXT_PER_BUFFER = std.math.maxInt(c_int);

pub const vertex =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec4 base;
    \\layout (location = 1) in vec4 text;
    \\layout (location = 2) in vec2 texcoord;
    \\
    \\out vec2 tex_coord;
    \\
    \\uniform mat4 projection;
    \\uniform vec2 tex;
    \\
    \\void main() {
    \\	vec2 xy = base.xy * text.zw + text.xy;
    \\	gl_Position = projection * vec4(xy, 0.0, 1.0);
    \\  tex_coord = base.zw * texcoord;
    \\}
;

pub const fragment = 
    \\#version 330 core
    \\
    \\in vec2 tex_coord;
    \\
    \\out vec4 out_color;
    \\
    \\uniform sampler2D tex;
    \\
    \\void main() {
    \\  float alpha = texture(tex, tex_coord).r;
    \\  out_color = vec4(1.0, 0.0, 0.0, alpha);
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

    font_src: ?[]const u8 = null,
    font_family: []const u8,
    text: []const u8
};

pub const FontSize = struct {
    allocator: Allocator,

    vao: c_uint,
    vbo: c_uint,
    font: Font,
    atlas: c_uint = undefined,

    character_count: usize = 0,

    pub fn from(
        passed_allocator: Allocator,
        font_src: []const u8,
        font_size: usize
    ) !*FontSize {
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
            @sizeOf(c.GLfloat) * INSTANCE_SIZE * MAX_TEXT_PER_BUFFER,
            null,
            c.GL_DYNAMIC_DRAW
        );

        // Text = { x, y, width, height }
        c.glVertexAttribPointer(
            1,
            TEXT_SIZE,
            c.GL_FLOAT,
            c.GL_FALSE,
            INSTANCE_SIZE * @sizeOf(c.GLfloat),
            null
        );
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribDivisor(1, 1);

        // Texcoord = { x, y } normalized
        const texcoord_offset: *const anyopaque = @ptrFromInt(TEXT_SIZE * @sizeOf(c.GLfloat));
        c.glVertexAttribPointer(
            2,
            TEXCOORD_SIZE,
            c.GL_FLOAT,
            c.GL_FALSE,
            INSTANCE_SIZE * @sizeOf(c.GLfloat),
            texcoord_offset
        );
        c.glEnableVertexAttribArray(2);
        c.glVertexAttribDivisor(2, 1);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);

        const self = try passed_allocator.create(FontSize);
        self.* = .{
            .allocator = passed_allocator,
            .vao = vao,
            .vbo = vbo,
            .font = try Font.from(passed_allocator, font_src, .{
                .font_size = font_size
            })
        };

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        var texture: c_uint = undefined;
        c.glGenTextures(1, &texture);
        self.atlas = texture;
        
        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glTexParameteri(
            c.GL_TEXTURE_2D, 
            c.GL_TEXTURE_WRAP_S,
            c.GL_CLAMP_TO_BORDER
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_WRAP_T,
            c.GL_CLAMP_TO_BORDER
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D, 
            c.GL_TEXTURE_MIN_FILTER,
            c.GL_LINEAR,
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_MAG_FILTER,
            c.GL_LINEAR
        );
        c.glGenerateMipmap(c.GL_TEXTURE_2D);

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RED,
            @intCast(self.font.atlas_width),
            @intCast(self.font.atlas_height),
            0,
            c.GL_RED,
            c.GL_UNSIGNED_BYTE,
            @ptrCast(&self.font.atlas[0])
        );

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 4);

        return self;
    }

    pub fn deinit(self: *FontSize) void {
        self.font.deinit();
        self.allocator.destroy(self);
    }

    pub fn add_text(self: *FontSize, attributes: Attributes) !void {
        const styles = attributes.styles;
        const text = attributes.text;

        var instance_data = try self.allocator.alloc(c.GLfloat, text.len * INSTANCE_SIZE);
        defer self.allocator.free(instance_data);

        var x = styles.left.?;
        const y = styles.top.?;
        
        var valid_len: usize = 0;

        for (text) |character| {
            const glyph = self.font.characters.get(&[_]u8{ character }) orelse continue;

            const offset = valid_len * INSTANCE_SIZE;
            instance_data[offset] = x + glyph.bearing_x;
            instance_data[offset + 1] = y - glyph.bearing_y;
            instance_data[offset + 2] = glyph.width;
            instance_data[offset + 3] = glyph.height;
            instance_data[offset + 4] = glyph.top / @as(c.GLfloat, @floatFromInt(self.font.atlas_height));
            instance_data[offset + 5] = glyph.left / @as(c.GLfloat, @floatFromInt(self.font.atlas_width));

            x += @floatFromInt(glyph.advance_x);
            valid_len += 1;
        }

        const instance = instance_data[0..INSTANCE_SIZE * valid_len];
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferSubData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(c.GLfloat) * @as(c.GLint, @intCast(INSTANCE_SIZE * self.character_count)),
            @sizeOf(c.GLfloat) * @as(c.GLint, @intCast(INSTANCE_SIZE * valid_len)),
            @ptrCast(&instance[0])
        );

        self.character_count += valid_len;
    }

    pub fn render(self: *FontSize) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.atlas);
        c.glBindVertexArray(self.vao);
        c.glDrawElementsInstanced(
            c.GL_TRIANGLES,
            @intCast(INDICES_SIZE),
            c.GL_UNSIGNED_INT,
            null,
            @intCast(self.character_count)
        );
    }
};

pub const FontFace = struct {
    allocator: Allocator,
    sizes: AutoHashMap(usize, *FontSize),

    pub fn init(passed_allocator: Allocator) !*FontFace {
        const self = try passed_allocator.create(FontFace);
        self.* = .{
            .allocator = passed_allocator,
            .sizes = AutoHashMap(usize, *FontSize).init(passed_allocator)
        };
        return self;
    }

    pub fn deinit(self: *FontFace) void {
        var sizes = self.sizes.valueIterator();
        while (sizes.next()) |value| {
            const size = value.*;
            size.deinit();
        }
        self.sizes.deinit();

        self.allocator.destroy(self);	
    }

    pub fn add_size(
        self: *FontFace,
        font_src: []const u8,
        font_size: usize
    ) !*FontSize {
        const size = try FontSize.from(self.allocator, font_src, font_size);
        try self.sizes.put(font_size, size);
        return size;
    }

    pub fn render(self: *FontFace) void {
        var it = self.sizes.valueIterator();
        while (it.next()) |value| {
            const size = value.*;
            size.render();
        }
    }
};

pub var shader: Shader = undefined;
pub var base_vbo: c_uint = undefined;
pub var ebo: c_uint = undefined;
pub var allocator: Allocator = undefined;

pub var faces: StringHashMap(*FontFace) = undefined;

pub fn init(passed_allocator: Allocator) !void {
    shader = try Shader.init(vertex, fragment);
    allocator = passed_allocator;

    faces = StringHashMap(*FontFace).init(allocator);

    c.glGenBuffers(1, &base_vbo);
    c.glGenBuffers(1, &ebo);

    // Base character rectangle: 1x1 pixel in top-left corner, covers entire atlas.
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
    shader.deinit();

    var it = faces.valueIterator();
    while (it.next()) |value| {
        const face = value.*;
        face.deinit();
    }
    faces.deinit();
}

pub fn paint(attributes: Attributes) !void {
    shader.use();

    const styles = attributes.styles;

    const face = faces.get(attributes.font_family) orelse create: {
        try faces.put(attributes.font_family, try FontFace.init(allocator));
        break :create faces.get(attributes.font_family).?;
    };

    if (attributes.font_src) |font_src| {
        // If font_src is passed in, always overwrite past atlases.
        const size = try face.add_size(font_src, styles.font_size);
        try size.add_text(attributes);
    } else {
        const size = face.sizes.get(styles.font_size);
        _ = size;
    }
}

pub fn render() !void {
    shader.use();

    var it = faces.valueIterator();
    while (it.next()) |value| {
        const face = value.*;
        face.render();
    }
}