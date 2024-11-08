const std = @import("std");
const cellui = @import("cellui");

const ArrayList = std.ArrayList;

const Element = cellui.Element;
const Button = cellui.Button;
const Input = cellui.Input;
const View = cellui.View;
const Text = cellui.Text;
const Signal = cellui.Signal;
const color = cellui.color;

const theme = "dandelion";
const foreground = "white";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var app = try cellui.setup(allocator, .{
        .initial_width = 800,
        .initial_height = 600,
        .title = "todo",
        .background = theme
    });
    defer app.deinit();

    try app.load_font("Nunito", "path-to-nunito.ttf");

    try app.launch(root);
}

const Todo = struct {
    done: bool = false,
    task: []const u8,

    const Self = @This();

    pub fn from(task: []const u8) Self {
        return .{ .task = task };
    }

    pub fn as_element(task: []const u8) void {
        _ = task;
    }
};

fn root(app: *cellui.App) !*Element {
    const wrapper = try Element(View).init(
        app.allocator,
        .{
            .align_self = "center",
            .background_color = foreground,
            .border_radius = 14,
            .border_color = "#efefef",
            .border_width = 1,
            .padding = 14
        }
    );

    // What we're missing here that would be nice to have:
    // Storing state so we don't have to manage it.
    // CSS defaults for text, etc.
    // Syntax extension similar to JSX.
    try wrapper.appendChild(
        try Element(Text).init(
            app.allocator,
            .{
                .font_family = "Nunito",
                .font_size = 36,
                .font_weight = "bold",
                .text = "No tasks!",
                .border_bottom_width = 1,
                .border_bottom_color = "#efefef"
            }
        )
    );

    const todos = try Signal(ArrayList(*Todo))
                        .init(ArrayList(*Todo).init(app.allocator));
    todos.onCleanup(&todo_cleanup);

    const input = try Signal(ArrayList(u8))
                        .init(ArrayList(u8).init(app.allocator));
    input.onCleanup(&input_cleanup);

    const input = try wrapper.appendChild(
        try Element(Input).init(
            app.allocator,
            .{
                .font_family = "Nunito",
                .font_size = 18,
                .border_width = 1,
                .border_color = "#",
            }
        )
    );

    const button = try wrapper.appendChild(
        try Element(Button).init(
            app.allocator,
            .{
                .font_family = "Nunito",
                .background_color = theme,
                .color = foreground,
                .text = "Add new task",
                .onclick = add_task
            }
        )
    );

    try wrapper.appendChild(
        try Element(View).init(
            app.allocator,
            .{},
            .{ .id = "tasks" }
        )
    );

    return wrapper;
}

fn add_task(app: *cellui.App, event: *cellui.Event) !void {
    std.debug.print("{any}\n", .{event});
    var tasks = try app.locateChild(.{ .id = "tasks" }).?;
    try tasks.appendChild(try Todo.as_element());
}

// Unfortunately Zig doesn't let us have anonymous functions or nested functions.

fn todo_cleanup(value: ArrayList(*Todo)) void {
    value.deinit();
}

fn input_cleanup(value: ArrayList(u8)) void {
    value.deinit();
}
