const std = @import("std");
const cellui = @import("cellui");

const Allocator = std.mem.Allocator;

const App = cellui.App;
const Element = cellui.Element;
const Node = cellui.Node;

const Rectangle = cellui.Rectangle;
const Text = cellui.Text;

const Signal = cellui.Signal;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var app = try App.from(
        allocator,
        .{
            .initial_width = 100,
            .initial_height = 100,
            .title = "counter"
        },
        root
    );
    defer app.deinit();

    try app.launch();
}

fn root(app: *App) !*Node {
    const count = Signal(usize).init(app.allocator, 0);

    return try Element(Rectangle).from(
        app.allocator,
        .{},
        .{
            try Element(Text).from(
                app.allocator,
                .{
                    .value =
                },
                .{}
            )
        }
    );
}