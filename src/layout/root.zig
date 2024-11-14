const std = @import("std");
const element = @import("../element/root.zig");
const math = @import("math");
const style = @import("style");
const Queue = @import("util").Queue;

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Node = element.Node;

const Float = math.Float;

const ViewStyles = style.ViewStyles;

// Calculating the layout essentially means
// giving every node in a `node` a determined top, left, width, height
// based upon other property values.
pub fn calculate(allocator: Allocator, root: *Node) !void {
    var queue = Queue(*Node).init(allocator);
    defer queue.deinit();

    var n: ?*Node = root;
    while (n) |node| {
        try queue.enqueue(node);

        const styles = node.viewStyles();
        style.resolve(styles);

        n = null;
        if (node.first_child) |first_child| {
            n = first_child;
        } else if (node.next) |next| {
            n = next;
        } else if (node.parent) |parent| {
            if (parent.next) |next| n = next;
        }
    }

    while (queue.dequeue()) |node| {
        const styles = node.viewStyles();

        switch (styles.display) {
            .none => @panic("Node should not have `display: none` at this stage of layout"),
            .flex => {
                var total_flex_grow: Float = 0;

                if (node.parent) |parent| {
                    const parent_styles = parent.viewStyles();
                    switch (parent_styles.display) {
                        .none => {
                            hide(styles);
                        },
                        .flex => {
                            // If parent node is a flex node,
                            // let's start by inheriting its dimension on the cross axis. 
                            switch (parent_styles.flex_direction) {
                                .column => styles.width = parent_styles.width - parent_styles.padding_horizontal,
                                .row => styles.height = parent_styles.height - parent_styles.padding_vertical
                            }
                            std.debug.print("{d} {d}\n", .{styles.width, styles.height});
                        }
                    }
                }

                var it = node.iterator();
                while (it.next()) |child| {
                    const child_styles = child.viewStyles();
                    total_flex_grow += @floatFromInt(child_styles.flex_grow);
                }

                if (total_flex_grow != 0) {
                    var current_flex_grow = total_flex_grow;
                    switch (styles.flex_direction) {
                        .row => {
                            const base_dimension = styles.width - styles.padding_horizontal;
                            const factor = base_dimension / total_flex_grow;
                            it = node.iterator();
                            while (it.next()) |child| {
                                var child_styles = child.viewStyles();
                                const flex_grow: Float = @floatFromInt(child_styles.flex_grow);
                                child_styles.width = factor * flex_grow;
                                child_styles.top = styles.top + styles.padding_top;
                                child_styles.left = styles.left + styles.padding_left + factor * (total_flex_grow - current_flex_grow);
                                current_flex_grow -= flex_grow;
                            }
                        },
                        .column => {
                            const base_dimension = styles.height - styles.padding_vertical;
                            const factor = base_dimension / total_flex_grow;
                            it = node.iterator();
                            while (it.next()) |child| {
                                var child_styles = child.viewStyles();
                                const flex_grow: Float = @floatFromInt(child_styles.flex_grow);
                                child_styles.height = factor * flex_grow;
                                child_styles.top = styles.top + styles.padding_top + factor * (total_flex_grow - current_flex_grow);
                                child_styles.left = styles.left + styles.padding_left;
                                current_flex_grow -= flex_grow;
                            }
                        }
                    }
                }
            }
        }
    }
}

fn hide(styles: *ViewStyles) void {
    styles.top = 0;
    styles.right = 0;
    styles.bottom = 0;
    styles.left = 0;
    styles.width = 0;
    styles.height = 0;
}