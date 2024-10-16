// Generate texture atlases used by the text primitive.

const c = @cImport({
    @cInclude("ft.h");
    @cInclude("glad/glad.h");
});
const std = @import("std");

const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const math = std.math;

pub var ft_library: c.FT_Library = undefined;

pub const Character = struct {
    grapheme: usize,
    top: f32,
    left: f32,
    width: f32,
    height: f32,
    bearing_x: f32,
    bearing_y: f32,
    advance_x: c_long,
    advance_y: c_long,
};

pub const Font = struct {
    allocator: Allocator,
    face: c.FT_Face = undefined,
    sdf: bool,
    font_size: usize,
    range: [2]usize,
    num_glyphs: usize,
    characters: AutoHashMap(usize, Character),

    atlas: []u8 = undefined,
    atlas_width: usize = 1,
    atlas_height: usize = 1,

    const Self = @This();

    pub fn from(
        allocator: Allocator,
        path: []const u8,
        optional_args: struct {
            font_size: c_uint = 14,
            sdf: bool = false,
            glyph_range: [2]usize = [2]usize{65, 127}
        }
    ) !Self {
        var self: Self = .{
            .allocator = allocator,
            .sdf = optional_args.sdf,
            .font_size = if (optional_args.sdf) 72 else @intCast(optional_args.font_size),
            .range = optional_args.glyph_range,
            .num_glyphs = optional_args.glyph_range[1] - optional_args.glyph_range[0],
            .characters = AutoHashMap(usize, Character).init(allocator)
        };

        if (c.FT_New_Face(ft_library, @ptrCast(path), 0, &self.face) != c.GL_FALSE)
            return error.FaceLoadError;

        const font_size: c_uint = @intCast(self.font_size);
        _ = c.FT_Set_Pixel_Sizes(self.face, 0, font_size);

        const face = self.face.*;

        // Calculate approximate atlas size, to a power of two (for mipmapping).
        // FreeType stores font sizes in 26.6 fractional pixel format = 1/64
        const size = face.size.*;
        const max_dimensions =
            (1 + (size.metrics.height >> 6)) *
                @as(c_long, @intFromFloat(
                    @ceil(@sqrt(@as(f64, @floatFromInt(self.num_glyphs))))
                ));
        while (self.atlas_width < max_dimensions) self.atlas_width <<= 1;
        self.atlas_height = self.atlas_width;
        self.atlas = try allocator.alloc(u8, self.atlas_width * self.atlas_height);

        var x: usize = 0;
        var y: usize = 0;

        const slot = self.face.*.glyph;

        for (self.range[0]..self.range[1]) |i| {
            if (c.FT_Load_Char(self.face, i, c.FT_LOAD_RENDER) != c.GL_FALSE)
                return error.GlyphLoadError;

            _ = c.FT_Render_Glyph(slot, c.FT_RENDER_MODE_SDF);

            const glyph = self.face.*.glyph.*;

            if (x + glyph.bitmap.width >= self.atlas_width) {
                const glyph_size = self.face.*.size.*;
                x = 0;
                y += @intCast(1 + (glyph_size.metrics.height >> 6));
            }

            for (0..glyph.bitmap.rows) |row| {
                for (0..glyph.bitmap.width) |col| {
                    const xpos = x + col;
                    const ypos = y + row;
                    self.atlas[ypos * self.atlas_width + xpos] =
                        glyph.bitmap.buffer[row * @as(usize, @intCast(glyph.bitmap.pitch)) + col];
                }
            }

            try self.characters.put(i, .{
                .grapheme = i,
                .top = @floatFromInt(x),
                .left = @floatFromInt(y),
                .width = @floatFromInt(glyph.bitmap.width),
                .height = @floatFromInt(glyph.bitmap.rows),
                .bearing_x = @floatFromInt(glyph.bitmap_left),
                .bearing_y = @floatFromInt(glyph.bitmap_top),
                .advance_x = glyph.advance.x >> 6,
                .advance_y = glyph.advance.y >> 6
            });

            x += glyph.bitmap.width + 1;
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = c.FT_Done_Face(self.face);
        self.allocator.free(self.atlas);
        self.characters.deinit();
    }
};

pub fn setup() !void {
    if (c.FT_Init_FreeType(&ft_library) != c.GL_FALSE)
        return error.FreeTypeLoadError;
}

pub fn cleanup() void {
    _ = c.FT_Done_FreeType(ft_library);
}

pub fn _test(allocator: Allocator) !void {
    _ = allocator;
}
