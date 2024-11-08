const std = @import("std");
const cellui = @import("root.zig");

const Allocator = std.mem.Allocator;

const App = cellui.App;
const Element = cellui.Element;
const View = cellui.View;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var app = try cellui.setup(allocator, .{
        .initial_width = 800,
        .initial_height = 800,
        .title = "cellui",
        .background = "#fff",

        .debug = true
    }, init);
    defer app.deinit();

    try app.loop(loop);
}

fn init(app: *App) anyerror!void {
    const view = try Element(View).from(
        app.allocator,
        .{
            .styles = .{
                .flex = 1,
                .padding = 20,
            },
        }
    );
    _ = try app.root.appendChild(view);
}

fn loop(app: *App) anyerror!void {
    _ = app;
}