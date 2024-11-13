const c = @cImport({
    @cInclude("glad/glad.h");
});
const std = @import("std");
const style = @import("style");
const Float = @import("math").Float;

const Shader = @import("shader.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const assert = std.debug.assert;

const Self = @This();

const VERTEX_SIZE = 4;
const VERTICES_SIZE = VERTEX_SIZE * 4;

const DEST_SIZE = 4;
const SRC_SIZE = 4;
const TEXTURE_SIZE = 2;

pub const vertex = 
    \\#version 330 core
    \\
    \\layout (location = 0) in vec4 base;
    \\layout (location = 1) in vec4 dest;
    \\layout (location = 2) in vec4 src;
    \\layout (location = 3) in vec2 tex;
    \\
    \\out vec2 tex_coord;
    \\
    \\
;