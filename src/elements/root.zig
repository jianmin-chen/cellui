const c = @cImport({
	@cInclude("glad/glad.h");
	@cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const style = @import("style");
const Matrix4x4 = @import("math").Matrix4x4;

pub const Image = @import("primitives/image.zig");
pub const Rectangle = @import("primitives/rectangle.zig");
pub const Text = @import("primitives/text.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn Element(comptime T: type) type {
	return struct {
		allocator: Allocator,
		attributes: T.Attributes,

		pub fn init(allocator: Allocator, attributes: T.Attributes) !*Element(T) {
			const self = try allocator.create(Element(T));
			self.* = .{
				.allocator = allocator,
				.attributes = attributes
			};
			return self;
		}

		pub fn deinit(self: *Element(T)) void {
			self.allocator.destroy(self);
		}

		pub fn paint(self: *Element(T)) !void {
		    try T.paint(self.attributes);
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
		paint: *const fn (ptr: *anyopaque) anyerror!void
	};

	const Self = @This();

	pub fn deinit(self: *Self) void {
		if (self.last_child) |last_child| {
			last_child.deinit();
		}

		if (self.previous) |node| {
			node.deinit();
		}

		self.vtable.deinit(self.value);
		self.allocator.destroy(self);
	}

	pub fn paint(self: *Self) !void {
		try self.vtable.paint(self.value);
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

			fn paint(ptr: *anyopaque) anyerror!void {
				const self: Ptr align(alignment) = @ptrCast(@alignCast(ptr));
				try self.paint();
			}
		};

		const wrapper = try allocator.create(Self);
		wrapper.* = .{
			.allocator = allocator,
			.value = value,
			.vtable = &.{
				.deinit = impl.deinit,
				.paint = impl.paint
			}
		};
		return wrapper;
	}

	pub fn appendChild(self: *Self, child: anytype) !*Node {
		var node = try Self.wrap(self.allocator, child);
		try node.paint();
		node.parent = self;

		if (self.first_child == null) {
			self.first_child = node;
			self.last_child = node;
		} else {
			if (self.last_child != null) {
				node.previous = self.last_child;
				(self.last_child.?).next = node;
				self.last_child = node;
			} else return error.MissingLastChild;
		}

		self.len += 1;

		return node;
	}
};

pub fn setup(allocator: Allocator, projection: Matrix4x4) !void {
	try Image.init(allocator);
	try Rectangle.init(allocator);
	try Text.init(allocator);
	viewport(projection);
}

pub fn viewport(projection: Matrix4x4) void {
	c.glUniformMatrix4fv(
		Image.shader.uniform("projection"),
		1,
		c.GL_FALSE,
		@ptrCast(&projection)
	);
	c.glUniformMatrix4fv(
		Rectangle.shader.uniform("projection"),
		1,
		c.GL_FALSE,
		@ptrCast(&projection)
	);
	c.glUniformMatrix4fv(
		Text.shader.uniform("projection"),
		1,
		c.GL_FALSE,
		@ptrCast(&projection)
	);
}

pub fn cleanup(_: Allocator) void {
	Image.deinit();
	Rectangle.deinit();
	Text.deinit();
}
