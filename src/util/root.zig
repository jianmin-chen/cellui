const std = @import("std");
pub const color = @import("color.zig");
const math = @import("math");
pub const queue = @import("queue.zig");
pub const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Float = math.Float;

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

pub fn isTruthy(value: anytype) bool {
    if (@as(Float, value) > 0.0) return true;
    return false;
}

// Cascade through a set of values,
// finding one that is valid to store inside value.
//
// value is a pointer to a type.
pub fn cascade(
    value: anytype,
    fallthrough: anytype,
    fallback: anytype,
    options: struct {
        // Assumes that this is usually run on `Float`s.
        valid: fn (value: anytype) bool = isTruthy
    }
) void {
    assert(@typeInfo(@TypeOf(value)) == .Pointer);
    if (options.valid(value.*)) return;
    inline for (fallthrough) |case| {
        if (options.valid(case)) {
            value.* = case;
            return;
        }
    }
    value.* = fallback;
}