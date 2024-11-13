const std = @import("std");
const math = @import("math");

const Allocator = std.mem.Allocator;

const Float = math.Float;

pub const ColorPrimitive = [4]Float;
pub const default = ColorPrimitive{ 0.0, 0.0, 0.0, 1.0 };
pub const transparent = ColorPrimitive{ 0.0, 0.0, 0.0, 0.0 };

const Error = error{ InvalidHexColor, InvalidFormat } || std.fmt.ParseIntError;

pub fn parse(_color: []const u8) Error!ColorPrimitive {
    var result = default;

    if (std.mem.startsWith(u8, _color, "#")) {
        // #rgb, #rgba, #rrggbb, #rrggbbaa
        const color = std.mem.trim(u8, _color, "#");

        var chunk_len: usize = 0;
        var alpha: bool = false;
        if (color.len % 3 == 0) {
            chunk_len = color.len / 3;
        } else if (color.len % 4 == 0) {
            chunk_len = color.len / 4;
            alpha = true;
        } else return Error.InvalidHexColor;

        if (chunk_len > 2) return Error.InvalidHexColor;

        for (0..color.len / chunk_len) |i| {
            const chunk = color[i * chunk_len..i * chunk_len + chunk_len];
            var repr = try std.fmt.parseInt(usize, chunk, 16);
            if (chunk.len == 1) repr = (repr << 4) | repr;
            result[i] = @as(Float, @floatFromInt(repr)) / 255; 
        }
    } else return Error.InvalidFormat;

    return result;
}

pub fn random() !ColorPrimitive {
    return [4]Float{
        try math.randomFloat(0, 1),
        try math.randomFloat(0, 1),
        try math.randomFloat(0, 1),
        1
    };
}