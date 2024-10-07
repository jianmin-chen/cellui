const std = @import("std");

const Self = @This();

pub const ColorPrimitive = [4]f32;

pub const ColorKind = enum { primitive, hex };

kind: ColorKind = .primitive,
repr: ?ColorPrimitive = [4]f32{0.0, 0.0, 0.0, 1.0},

pub fn parse(color: []const u8) !Self {
    var self: Self = .{};
    if (std.mem.startsWith(u8, color, "#")) {
        self.kind = .hex;
    }
    return self;
}

pub fn process(color: []const u8) !ColorPrimitive {
    const self = try parse(color);
    return self.repr orelse unreachable;
}
