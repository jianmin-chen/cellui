const std = @import("std");
const cellui = @import("root.zig");
const color = @import("color.zig");

const App = cellui.App;
const Element = cellui.Element;

pub fn main() !void {
    var app = try cellui.setup(.{
        .initial_width = 800,
        .initial_height = 600,
        .title = "cellui",

        .debug = true
    }, init);
    defer app.deinit();

    try app.loop(loop);
}

fn init(app: *App) anyerror!void {
    _ = app;
    std.debug.print("init\n", .{});
}

fn loop(app: *App) anyerror!void {
    std.debug.print("fps: {any}\n", .{app.fps});
    try app.render(
        try Element.create(
            app.default_allocator,
            Element.Box,
            .{
                .x = 0,
                .y = 0,
                .width = 25,
                .height = 25,
                .color = try color.process("#fff")
            }
        )
    );
    // try app.add(Element.Box);
}
