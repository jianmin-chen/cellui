const std = @import("std");
const cellui = @import("root.zig");
const color = @import("color");
const math = @import("math");

const elements = @import("elements/root.zig");
const Element = elements.Element;
const Rectangle = elements.Rectangle;

const App = cellui.App;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var app = try cellui.setup(allocator, .{
        .initial_width = 800,
        .initial_height = 600,
        .title = "cellui",

        .debug = true
    }, init);
    defer app.deinit();

    try app.loop(loop);
}

fn init(app: *App) anyerror!void {
    for (0..8) |_| {
        _ = try app.root.appendChild(
            try Element(Rectangle).init(
                app.allocator,
                .{
                    .top = @floatFromInt(
                        try math.random(usize, 0, app.height)
                    ),
                    .left = @floatFromInt(
                        try math.random(usize, 0, app.width)
                    ),
                    .width = @floatFromInt(
                        try math.random(usize, 25, 200)
                    ),
                    .height = @floatFromInt(
                        try math.random(usize, 25, 200)
                    ),
                    .color = try color.random()
                }
            )
        );
    }
}

fn loop(app: *App) anyerror!void {
    std.debug.print("fps: {any}\n", .{app.fps});
}
