const std = @import("std");

const assert = std.debug.assert;

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
            .decls = TInfo.Struct.decls ++ UInfo.Struct.decls,
            .is_tuple = false
        }
    });
}
