const std = @import("std");
pub const color = @import("color.zig");
pub const queue = @import("queue.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Queue = queue.Queue;
pub const QueueNode = queue.QueueNode;

pub fn merge(comptime T: type, comptime U: type) type {
    // Merge two structs together.
    const TInfo = @typeInfo(T);
    const UInfo = @typeInfo(U);
    assert(TInfo == .Struct);
    assert(UInfo == .Struct);

    return @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = TInfo.Struct.fields ++ UInfo.Struct.fields,

            // This is redundant because it doesn't actually work;
            // Zig doesn't let you append decls from two structs.
            // But it's useful as an assertion.
            .decls = TInfo.Struct.decls ++ UInfo.Struct.decls,

            .is_tuple = false
        }
    });
}