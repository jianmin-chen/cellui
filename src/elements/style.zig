const std = @import("std");
const Color = @import("color").ColorPrimitive;

const assert = std.debug.assert;

pub const FlexDirection = enum { row, column };

pub const ViewStyles = struct {
    top: ?f32 = null,
    left: ?f32 = null,
    width: ?f32 = null,
    height: ?f32 = null,

    background_color: ?Color = null,

    border_radius: ?[4]f32 = [4]f32{ 15, 15, 15, 15 },
    border_top_left_radius: ?f32 = 0,
    border_top_right_radius: ?f32 = 0,
    border_bottom_left_radius: ?f32 = 0,
    border_bottom_right_radius: ?f32 = 0,

    border_width: ?[4]f32 = [4]f32{ 0, 0, 0, 0 },
    border_top_width: ?f32 = 0,
    border_right_width: ?f32 = 0,
    border_bottom_width: ?f32 = 0,
    border_left_width: ?f32 = 0,

    border_color: ?[4]Color = null,
    border_top_left_color: ?Color = null,
    border_top_right_color: ?Color = null,
    border_bottom_left_color: ?Color = null,
    border_bottom_right_color: ?Color = null,

    margin: ?[4]f32 = null,
    margin_top: ?f32 = 0,
    margin_right: ?f32 = 0,
    margin_bottom: ?f32 = 0,
    margin_left: ?f32 = 0,

    padding: ?[4]f32 = null,
    padding_top: ?f32 = 0,
    padding_right: ?f32 = 0,
    padding_bottom: ?f32 = 0,
    padding_left: ?f32 = 0,

    // pub fn decompose(self: *Self) void {
    //     // Resolve styles that rely on individual fields.
    //     // i.e., self.border_radius = { self.border_radius_top_left, ... }
    //     if (self.border_radius == null) {
    //         self.border_radius = [4]f32{
    //             self.border_top_left_radius orelse 0,
    //             self.border_top_right_radius orelse 0,
    //             self.border_bottom_left_radius orelse 0,
    //             self.border_bottom_right_radius orelse 0
    //         };
    //     }
    // }
};

pub fn merge(comptime T: type, comptime U: type) type {
    // Merge two structs together.
    // Usually used for combining a default set of styles with a specific set.
    const TInfo = @typeInfo(T);
    const UInfo = @typeInfo(U);
    assert(TInfo == .Struct);
    assert(UInfo == .Struct);

    return @Type(.{
    	.Struct = .{
     		.layout = .auto,
       		.fields = TInfo.Struct.fields ++ UInfo.Struct.fields,
         	.decls = TInfo.Struct.decls ++ UInfo.Struct.decls,
          	.is_tuple = false
     	}
    });
}
