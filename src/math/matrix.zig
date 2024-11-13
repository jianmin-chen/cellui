const Float = @import("types.zig").Float;

pub const Matrix4x4 = [4][4]Float;

pub fn ortho(left: Float, right: Float, bottom: Float, top: Float) Matrix4x4 {
    var matrix: Matrix4x4 = [_][4]Float{[_]Float{0} ** 4} ** 4;
    matrix[0][0] = 2 / (right - left);
    matrix[1][1] = 2 / (top - bottom);
    matrix[2][2] = -1;
    matrix[3][0] = -(right + left) / (right - left);
    matrix[3][1] = -(top + bottom) / (top - bottom);
    matrix[3][3] = 1;
    return matrix;
}
