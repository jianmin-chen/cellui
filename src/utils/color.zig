const std = @import("std");
const math = @import("math");

const Allocator = std.mem.Allocator;
const JSON = std.json.ArrayHashMap([]const u8);

const Self = @This();

pub const ColorPrimitive = [4]f32;
pub const transparent = ColorPrimitive{ 0.0, 0.0, 0.0, 1.0 };

pub const ColorKind = enum { primitive, hex };

pub const defaults_location = "src/utils/color_defaults.json";
pub var defaults: JSON = undefined;

kind: ColorKind = .primitive,
repr: ColorPrimitive = transparent,

pub fn setup(allocator: Allocator) !void {
    const file= try std.fs.cwd().openFile(defaults_location, .{});
    defer file.close();

    const buf = try allocator.alloc(u8, try file.getEndPos());
    _ = try file.readAll(buf);
    defer allocator.free(buf);

    // defaults = try JSON.jsonParseFromValue(
    // 	allocator,
    // 	std.json.Value { .string = std.mem.trim(u8, buf, "\n") },
    // 	.{ .allocate = .alloc_always }
    // );
}

pub fn cleanup(allocator: Allocator) void {
    defaults.deinit(allocator);
}

pub fn parse(_color: []const u8) !Self {
    var self: Self = .{};
    if (std.mem.startsWith(u8, _color, "#")) {
        // #rgb, #rgba, #rrggbb, #rrggbbaa
        self.kind = .hex;

        const color = std.mem.trim(u8, _color, "#");

        var chunk_len: usize = 0;
        var alpha: bool = false;
        if (color.len % 3 == 0) {
            chunk_len = color.len / 3;
        } else if (color.len % 4 == 0) {
            chunk_len = color.len / 4;
            alpha = true;
        } else return error.InvalidColor;

        if (chunk_len > 2) return error.InvalidColor;

        for (0..color.len / chunk_len) |i| {
            const chunk = color[i * chunk_len..i * chunk_len + chunk_len];
            var repr = try std.fmt.parseInt(usize, chunk, 16);
            if (chunk.len == 1) repr = (repr << 4) | repr;
            self.repr[i] = @as(f32, @floatFromInt(repr)) / 255.0;
        }
    } else {

    }
    return self;
}

pub fn process(color: []const u8) !ColorPrimitive {
    const self = try parse(color);
    return self.repr;
}

pub fn random() !ColorPrimitive {
    return [4]f32{
        try math.randomFloat(0, 1),
        try math.randomFloat(0, 1),
        try math.randomFloat(0, 1),
        1.0
    };
}
