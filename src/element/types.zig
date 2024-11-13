const c = @cImport({
    @cInclude("glad/glad.h");
});
const std = @import("std");
const math = @import("math");
const style = @import("style");
const util = @import("util");
const Rectangle = @import("primitives/rectangle.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const Matrix4x4 = math.Matrix4x4;

// An element is essentially an instance of a "view".
// Checking is done at compile-time by the compiler to ensure that passed types contain:
// a struct type called `Attributes` that contains a field called `styles`
// that contains a subset of styles that can be resolved by `style.resolve`;
// and a paint() function that takes its own `Attributes`.
//
// This makes it particularly easy to create a custom View,
// which can control a subset of what can get rendered on screen,
// e.g. rectangles (`Element(Rectangle)`).
pub fn Element(comptime T: type) type {
    return struct {
        allocator: Allocator = undefined,
        attributes: *T.Attributes,

        // Surprisingly, this returns a *Node instead of a *Element(T).
        // This effectively erases the type, 
        // and creates a tree given an elements' children.
        pub fn from(allocator: Allocator, attributes: T.Attributes, children: anytype) !*Node {
            const attr = try allocator.create(T.Attributes);
            attr.* = attributes;

            const element = try allocator.create(Element(T));
            element.* = .{
                .allocator = allocator,
                .attributes = attr
            };

            // Make sure that children is a empty struct if element is a void element;
            // that is, if it can't hold children, e.g. `View(Image)`.
            assert(!(@typeInfo(@TypeOf(children)).Struct.fields.len == 0 and T.is_void_element));

            try element.paint();

            return Node.from(allocator, element, children);
        }

        pub fn deinit(self: *Element(T)) void {
            self.allocator.destroy(self.attributes);
            self.allocator.destroy(self);
        }

        pub fn paint(self: *Element(T)) !void {
            try style.resolve(@ptrCast(&self.attributes.styles));
            try T.paint(self.attributes.*);
        }

        pub fn format(
            self: *Element(T),
            fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype
        ) !void {
            _ = self;
            _ = fmt;
            _ = options;
            try writer.print("{any}", .{T});
        }
    };
}

// This represents a node in a tree, but
// is also used to wrap around `Element` so
// we gain two advantages:
pub const Node = struct {
    const Self = @This();

    const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        paint: *const fn (ptr: *anyopaque) anyerror!void
    };

    allocator: Allocator,

    render_id: usize = 0,
    value: *anyopaque,
    methods: *const VTable,

    next: ?*Self = null,
    previous: ?*Self = null,
    first_child: ?*Self = null,
    last_child: ?*Self = null,
    parent: ?*Self = null,

    len: usize = 0,

    pub fn from(allocator: Allocator, element: anytype, children: anytype) !*Self {
        const Ptr = @TypeOf(element);
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

            fn paint(ptr: *anyopaque) !void {
                const self: Ptr align(alignment) = @ptrCast(@alignCast(ptr));
                try self.paint();
            }
        };

        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .value = element,
            .methods = &.{
                .deinit = impl.deinit,
                .paint = impl.paint,
            }
        };

        inline for (children) |child| {
            try self.appendChild(child);
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.last_child) |last_child| last_child.deinit();
        if (self.previous) |node| node.deinit();
        self.methods.deinit(self.value);
        self.allocator.destroy(self);
    }

    pub fn paint(self: *Self) !void {
        try self.methods.paint(self.value);
    }

    pub fn format(
        self: *Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{any}", .{self.value});
    }

    pub fn appendChild(self: *Self, child: *Node) !void {
        child.parent = self;
        if (self.first_child == null) {
            self.first_child = child;
            self.last_child = child;
        } else {
            assert(self.last_child != null);
            child.previous = self.last_child;
            (self.last_child.?).next = child;
            self.last_child = child;
        }
        
        self.len += 1;
    }
};

// This is used to type erase a specific view, 
// used where a lack of typing is needed,
// such as render_stack in `src/root.zig`.
//
// This makes it easy to write custom views,
// while adhering to the shape of an interface.
pub const View = struct {
    const VTable = struct {
        deinit: *const fn () void,
        render: *const fn () anyerror!void
    };

    methods: *const VTable,

    pub fn from(view: anytype) !View {
        const ViewType = view;

        const Ptr = @TypeOf(ViewType);
        const PtrInfo = @typeInfo(Ptr);

        // More assertions would probably be handy here,
        // but the compiler takes care of a lot of type checks for us.
        assert(PtrInfo == .Type);

        const impl = struct {
            fn deinit() void {
                ViewType.deinit();
            }

            fn render() !void {
                try ViewType.render();
            }
        };

        return .{
            .methods = &.{
                .deinit = impl.deinit,
                .render = impl.render
            }
        };
    }

    pub fn deinit(self: View) void {
        self.methods.deinit();
    }

    pub fn render(self: View) !void {
        try self.methods.render();
    }
};