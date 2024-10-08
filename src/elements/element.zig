const std = @import("std");
pub const Rectangle = @import("primitives/rectangle.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn Element(comptime T: type) type {
    return struct {
        allocator: Allocator,
        styles: T.Styles,

        pub fn init(allocator: Allocator, styles: T.Styles) !*Element(T) {
            const self = try allocator.create(Element(T));
            self.* = .{
                .allocator = allocator,
                .styles = styles
            };
            return self;
        }

        pub fn render(self: *Element(T)) !void {
            try T.render(self.styles);
        }

        pub fn deinit(self: *Element(T)) void {
            self.allocator.destroy(self);
        }
    };
}
