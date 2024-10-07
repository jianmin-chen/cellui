const std = @import("std");
pub const Rectangle = @import("primitives/rectangle.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Self = @This();

allocator: Allocator,
children: ArrayList(*Self),

pub fn create(
    allocator: Allocator,
    kind: anytype,
    styles: anytype,
) !*Self {
    const self = try allocator.create(Self);
    self.* = .{
        .allocator = allocator,
    }
}

pub fn deinit(self: *Self) void {
    for (self.children.items) |child| {
        child.deinit();
    }
    self.children.deinit();
}
