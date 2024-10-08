const std = @import("std");
const cellui = @import("root.zig");
const color = @import("color");

const element = @import("elements/element.zig");
const Element = element.Element;
const Rectangle = element.Rectangle;

const App = cellui.App;

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
}

fn loop(app: *App) anyerror!void {
    std.debug.print("fps: {any}\n", .{app.fps});
    // try app.add(Element.Box);
}
