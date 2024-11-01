const c = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_image_write.h");
});
const std = @import("std");
const cellui = @import("root.zig");
const color = @import("color");
const math = @import("math");
const font = @import("font");

const elements = @import("elements/root.zig");
const Element = elements.Element;
const Node = elements.Node;
const Image = elements.Image;
const Rectangle = elements.Rectangle;
const Text = elements.Text;

const Font = font.Font;

const App = cellui.App;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    // try font.setup();
    // defer font.cleanup();

    var app = try cellui.setup(allocator, .{
        .initial_width = 800,
        .initial_height = 600,
        .title = "cellui",
        .background = "#690",

        .debug = true
    }, init);
    defer app.deinit();

    // var test_font = try Font.from(allocator, "test.ttf", .{
    // 	.font_size = 72
    // });
    // defer test_font.deinit();

    // var png: []u8 = try allocator.alloc(u8, test_font.atlas_width * test_font.atlas_height * 4);
    // defer allocator.free(png);
    // for (0..test_font.atlas_width * test_font.atlas_height) |i| {
    //     png[i * 4 + 0] = test_font.atlas[i];
    //     png[i * 4 + 1] = test_font.atlas[i];
    //     png[i * 4 + 2] = test_font.atlas[i];
    //     png[i * 4 + 3] = 0xff;
    // }
    // _ = c.stbi_write_png("test.png", @intCast(test_font.atlas_width), @intCast(test_font.atlas_height), 4, @ptrCast(&png[0]), @intCast(test_font.atlas_width * 4));

    try app.loop(loop);
}

fn init(app: *App) anyerror!void {
    _ = try app.root.appendChild(
        try Element(Rectangle).init(
            app.allocator,
            .{
                .styles = .{
                    .top = 25,
                    .left = 150,
                    .width = 500,
                    .height = 550,
                    .background_color = try color.process("#fff000"),
                    .border_top_width = 2,
                    .border_top_color = try color.process("#fff")
                }
            }
        )
    );
    _ = try app.root.appendChild(
        try Element(Rectangle).init(
            app.allocator,
            .{
                .styles = .{
                    .top = 25,
                    .left = 25,
                    .width = 50,
                    .height = 50,
                    .background_color = try color.process("#00fff0")
                }
            }
        )
    );

    const node = try _load(app, "test-hippo.png", .{
        .top = 100,
        .left = -20
    });
    const hippo: *Element(Image) = @alignCast(@ptrCast(node.value));
    _ = hippo;

    _ = try _load(app, "test.png", .{
        .top = 0,
        .left = 300
    });

    _ = try app.root.appendChild(
        try Element(Image).init(
            app.allocator,
            .{
                .styles = .{
                    .top = 100,
                    .left = 100,
                    .width = 600,
                    .height = 300,
                    .sx = 50,
                    .sy = 50,
                    .swidth = 50
                },
                .texture_id = 1
            }
        )
    );

    _ = try app.root.appendChild(
        try Element(Text).init(
            app.allocator,
            .{
                .styles = .{
                    .top = 20,
                    .left = 40,
                    .font_size = 24
                },
                .font_src = "test.ttf",
                .font_family = "Inter",
                .text = "cellui says hello, world!"
            }
        )
    );

    // _ = try app.root.appendChild(
    //     try Element(Text).init(
    //         app.allocator,
    //         .{
    //             .styles = .{
    //                 .top = 200,
    //                 .left = 200,
    //                 .color = try color.process("#fff"),
    //                 .font_size = 24
    //             },
    //             .font_src = "test.ttf",
    //             .font_family = "Inter",
    //             .text = "performs a linear interpolation"
    //         }
    //     )
    // );
}

fn loop(app: *App) anyerror!void {
    _ = app;
    // std.debug.print("fps: {any}\n", .{app.fps});
}

fn _load(app: *App, path: []const u8, styles: Image.Styles) !*Node {
    var w: c_int = undefined;
    var h: c_int = undefined;
    var nr_channels: c_int = undefined;

    const img = c.stbi_load(@ptrCast(path), &w, &h, &nr_channels, 0);
    if (img == null) std.debug.panic("", .{});
    defer c.stbi_image_free(img);

    const node = try app.root.appendChild(
        try Element(Image).init(
            app.allocator,
            .{
                .styles = styles,
                .texture = @ptrCast(img[0..@intCast(w * h * nr_channels)]),
                .texture_width = w,
                .texture_height = h,
                .texture_channels = nr_channels
            }
        )
    );
    return node;
}
