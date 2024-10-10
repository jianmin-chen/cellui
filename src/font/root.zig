// Generate textures used by the text primitive.

const c = @cImport({
    @cInclude("ft.h");
});
const std = @import("std");

const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const panic = std.debug.panic;

pub const Character = struct {
    repr: usize,
    texture_id: c_uint,
    width: f32,
    height: f32,
    bearing_x: f32,
    bearing_y: f32,
    advance_x: c_long,
    advance_y: c_long
};

const Self = @This();

allocator: Allocator,
ft: c.FT_Library,
face: c.FT_Face,
size: usize,
characters: AutoHashMap(usize, Character),

pub fn init(allocator: Allocator, ft: c.FT_Library, path: []const u8, size: c_uint) !Self {
}
