const std = @import("std");
pub const Float = @import("types.zig");
pub const Matrix = @import("matrix.zig");
pub const Matrix4x4 = Matrix.Matrix4x4;

const rand = std.crypto.random;

pub fn randomFloat(min: Float, max: Float) !Float {
    _ = min;
    _ = max;
    return rand.float(Float);
}

// pub fn random(comptime T: type, min: T, max: T) !T {
//     return (rng orelse try init()).intRangeAtMost(T, min, max);
// }

pub fn random(comptime T: type, min: T, max: T) !T {
    return rand.intRangeAtMost(T, min, max);
}
