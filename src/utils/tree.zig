const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn Tree(comptime T: type) type {
    return struct {
        allocator: Allocator,
        next: ?*Tree(T) = null,
        previous: ?*Tree(T) = null,
        first_child: ?*Tree(T) = null,
        last_child: ?*Tree(T) = null,
        parent: ?*Tree(T) = null,
        value: T,

        pub fn init(allocator: Allocator, value: T) !*Tree(T) {
            const self = try allocator.create(Tree(T));
            self.* = .{
                .allocator = allocator,
                .value = value
            };
            return self;
        }

        pub fn deinit(self: *Tree(T)) void {
            if (self.next) |next| {
                next.deinit();
            }

            if (self.last_child) |last_child| {
                var child: ?*Tree(T) = last_child;
                while (child) |node| {
                    child = node.previous;
                    node.deinit();
                }
            }

            self.allocator.destroy(self);
        }

        pub fn addChild(self: *Tree(T), node: *Tree(T)) !*Tree(T) {
            node.parent = self;

            if (self.first_child == null) {
                self.first_child = node;
                self.last_child = node;
            } else {
                if (self.last_child == null) return error.TreeMissingLastChild;

                node.prev = self.last_child;
                self.last_child.next = node;
                self.last_child = node;
            }

            return node;
        }
    };
}
