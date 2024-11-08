const std = @import("std");
const color = @import("color");

const assert = std.debug.assert;

const Color = color.ColorPrimitive;

pub const Layout = enum { flex, none };
pub const FlexDirection = enum { row, column };

pub const ViewStyles = struct {
    const Self = @This();

    display: Layout = .flex,
    flex: usize = 0,
};