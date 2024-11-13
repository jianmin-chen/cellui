// This represents the root styles for every element.
// All custom elements also need to have this base set of styles.

const std = @import("std");
const util = @import("util");
const Float = @import("math").Float;

const assert = std.debug.assert;

const color = util.color;
const Color = color.ColorPrimitive;

pub const merge = util.merge;

pub const Position = enum { static, relative, absolute, fixed, sticky };

pub const Layout = enum { flex, none };
pub const FlexDirection = enum { row, column };

pub const ViewStyles = struct {
    display: Layout = .flex,
    flex_direction: FlexDirection = .column,
    flex: usize = 0,
    flex_grow: usize = 0,
    position: Position = .static,

    top: ?Float = null,
    left: ?Float = null,
    width: ?Float = null,
    height: ?Float = null,

    _background_color: Color = color.default,
    background_color: ?[]const u8 = null,

    border_radius: ?[4]Float = [4]Float{ 15, 15, 15, 15 },
    border_top_left_radius: ?Float = null,
    border_top_right_radius: ?Float = null,
    border_bottom_left_radius: ?Float = null,
    border_bottom_right_radius: ?Float = null,

    border_width: ?[4]Float = [4]Float{ 0, 0, 0, 0 },
    border_top_width: ?f32 = 0,
    border_right_width: ?f32 = 0,
    border_bottom: ?f32 = 0,
    border_left_width: ?f32 = 0,

    border_color: ?[4]Color = [_]Color{color.transparent} ** 4,
    border_top_color: ?Color = null,
    border_right_color: ?Color = null,
    border_bottom_color: ?Color = null,
    border_left_color: ?Color = null,

    margin: ?f32 = null,
    margin_top: ?f32 = 0,
    margin_right: ?f32 = 0,
    margin_bottom: ?f32 = 0,
    margin_left: ?f32 = 0,

    padding: ?f32 = null,
    padding_top: ?f32 = 0,
    padding_right: ?f32 = 0,
    padding_bottom: ?f32 = 0,
    padding_left: ?f32 = 0,
};

pub fn resolve(styles: *ViewStyles) !void {
    _ = styles;
}