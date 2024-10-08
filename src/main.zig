const c = @cImport({
    @cInclude("stb_image_write.h");
});
const std = @import("std");
const cellui = @import("root.zig");
const color = @import("color");
const math = @import("math");
const font = @import("font");

const elements = @import("elements/root.zig");
const Element = elements.Element;
const Image = elements.Image;
const Rectangle = elements.Rectangle;

const Font = font.Font;

const App = cellui.App;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    try font.setup();
    defer font.cleanup();

    var test_font = try Font.from(allocator, "test.ttf", .{
        .font_size = 72
    });
    defer test_font.deinit();

    var png: []u8 = try allocator.alloc(u8, test_font.atlas_width * test_font.atlas_height * 4);
    defer allocator.free(png);
    for (0..test_font.atlas_width * test_font.atlas_height) |i| {
        png[i * 4 + 0] = test_font.atlas[i];
        png[i * 4 + 1] = test_font.atlas[i];
        png[i * 4 + 2] = test_font.atlas[i];
        png[i * 4 + 3] = 0xff;
    }
    _ = c.stbi_write_png("test.png", @intCast(test_font.atlas_width), @intCast(test_font.atlas_height), 4, @ptrCast(&png[0]), @intCast(test_font.atlas_width * 4));

    // var app = try cellui.setup(allocator, .{
    //     .initial_width = 1300,
    //     .initial_height = 1200,
    //     .title = "cellui",

    //     .debug = true
    // }, init);
    // defer app.deinit();

    // try app.loop(loop);
}

fn init(app: *App) anyerror!void {
    _ = try app.root.appendChild(
        try Element(Image).init(
            app.allocator,
            .{
                .top = 0,
                .left = 0,
                .width = 1296,
                .height = 884,
                .src = "test.png"
            }
        )
    );
    // _ = try app.root.appendChild(
    //     try Element(Rectangle).init(
    //         app.allocator,
    //         .{
    //             .top = 25,
    //             .left = 300,
    //             .width = 475,
    //             .height = 550,
    //             .color = try color.process("#23272e")
    //         }
    //     )
    // );
}

fn loop(app: *App) anyerror!void {
    _ = app;
    // std.debug.print("fps: {any}\n", .{app.fps});
}
