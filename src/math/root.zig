const std = @import("std");
pub const Float = @import("types.zig").Float;
pub const Matrix = @import("matrix.zig");
pub const Matrix4x4 = Matrix.Matrix4x4;

const _random = std.crypto.random;

pub fn randomFloat(_: Float, _: Float) !Float {
    return _random.float(Float);
}

pub fn random(comptime T: type, min: T, max: T) !T {
    return _random.intRangeAtMost(T, min, max);
}