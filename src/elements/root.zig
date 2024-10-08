const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const math = @import("math");

pub const Rectangle = @import("primitives/rectangle.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

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

        pub fn deinit(self: *Element(T)) void {
            self.allocator.destroy(self);
        }

        pub fn render(self: *Element(T)) !void {
            try T.render(self.styles);
        }
    };
}

pub const Node = struct {
    allocator: Allocator,

    value: *anyopaque,
    vtable: *const VTable,

    next: ?*Node = null,
    previous: ?*Node = null,
    first_child: ?*Node = null,
    last_child: ?*Node = null,
    parent: ?*Node = null,

    len: usize = 0,

    const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        render: *const fn (ptr: *anyopaque) anyerror!void
    };

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.vtable.deinit(self.value);

        if (self.next) |next| {
            next.deinit();
        }

        if (self.last_child) |last_child| {
            var child: ?*Node = last_child;
            while (child) |node| {
                child = node.previous;
                node.deinit();
            }
        }

        self.allocator.destroy(self);
    }

    pub fn render(self: *Self) anyerror!void {
        try self.vtable.render(self.value);
    }

    pub fn wrap(allocator: Allocator, value: anytype) !*Self {
        const Ptr = @TypeOf(value);
        const PtrInfo = @typeInfo(Ptr);

        assert(PtrInfo == .Pointer);
        assert(PtrInfo.Pointer.size == .One);
        assert(@typeInfo(PtrInfo.Pointer.child) == .Struct);

        const alignment = PtrInfo.Pointer.alignment;

        const impl = struct {
            fn deinit(ptr: *anyopaque) void {
                const self: Ptr align(alignment) = @ptrCast(@alignCast(ptr));
                self.deinit();
            }

            fn render(ptr: *anyopaque) anyerror!void {
                const self: Ptr align(alignment) = @ptrCast(@alignCast(ptr));
                try self.render();
            }
        };

        const wrapper = try allocator.create(Self);
        wrapper.* = .{
            .allocator = allocator,
            .value = value,
            .vtable = &.{
                .deinit = impl.deinit,
                .render = impl.render
            }
        };
        return wrapper;
    }

    pub fn appendChild(self: *Self, child: anytype) !*Node {
        var node = try Self.wrap(self.allocator, child);
        node.parent = self;

        if (self.first_child == null) {
            self.first_child = node;
            self.last_child = node;
        } else {
            if (self.last_child != null) {
                node.previous = self.last_child;
                (self.last_child orelse unreachable).next = node;
                self.last_child = node;
            } else return error.MissingLastChild;
        }

        self.len += 1;

        return node;
    }
};

pub fn setup(allocator: Allocator, width: usize, height: usize) !void {
    try Rectangle.init(allocator);
    viewport(width, height);
}

pub fn viewport(width: usize, height: usize) void {
    const projection = math.Matrix.ortho(
        0,
        @floatFromInt(width),
        @floatFromInt(height),
        0
    );
    c.glUniformMatrix4fv(
        Rectangle.shader.uniform("projection"),
        1,
        c.GL_FALSE,
        @ptrCast(&projection)
    );
}

pub fn cleanup() void {
    Rectangle.deinit();
}
