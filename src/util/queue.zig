const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn QueueNode(comptime T: type) type {
    return struct {
        value: T,
        prev: ?*QueueNode(T) = null,
        next: ?*QueueNode(T) = null,

        pub fn from(allocator: Allocator, value: T) !*QueueNode(T) {
            const self = try allocator.create(QueueNode(T));
            self.* = .{ .value = value };
            return self;
        }
    };
}

pub fn Queue(comptime T: type) type {
    return struct {
        allocator: Allocator,

        start: ?*QueueNode(T) = null,
        end: ?*QueueNode(T) = null,
        len: usize = 0,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn enqueue(self: *Self, value: T) !void {
            var node = try QueueNode(T).from(self.allocator, value);

            if (self.end) |end| {
                end.next = node;
                node.prev = end;
            } else self.start = node;

            self.end = node;
            self.len += 1;
        }

        pub fn dequeue(self: *Self) ?T {
            if (self.start) |start| {
                if (start.next) |next| {
                    self.start = next;
                } else {
                    self.start = null;
                    self.end = null;
                }
                self.len -= 1;
                defer self.allocator.destroy(start);
                return start.value;
            } else return null;
        } 

        pub fn dequeueFront(self: *Self) ?T {
            if (self.end) |end| {
                if (end.prev) |prev| {
                    self.end = prev;
                } else {
                    self.start = null;
                    self.end = null;
                }
                self.len -= 1;
                defer self.allocator.destroy(end);
                return end.value;
            } else return null;
        }

        pub fn deinit(self: *Self) void {
            var queue = self.start;
            while (queue) |node| {
                queue = node.next;
                self.allocator.destroy(node);
            }

            self.start = null;
            self.end = null;
            self.len = 0;
        }
    };
}