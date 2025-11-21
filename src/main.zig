const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const Config = struct {
    master_width: f64 = 0.5,
    gap: i32 = 10,
    smart_gaps: bool = false,
    inner_gap: i32 = 10,
    min_stack_width: u32 = 100,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = Config{};

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--master-width")) {
            if (args.next()) |val| config.master_width = try std.fmt.parseFloat(f64, val);
        } else if (std.mem.eql(u8, arg, "--gap")) {
            if (args.next()) |val| config.gap = try std.fmt.parseInt(i32, val, 10);
        } else if (std.mem.eql(u8, arg, "--smart-gaps")) {
            if (args.next()) |val| {
                if (std.mem.eql(u8, val, "true")) {
                    config.smart_gaps = true;
                } else if (std.mem.eql(u8, val, "false")) {
                    config.smart_gaps = false;
                }
            }
        } else if (std.mem.eql(u8, arg, "--inner-gap")) {
            if (args.next()) |val| config.inner_gap = try std.fmt.parseInt(i32, val, 10);
        }
    }

    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();

    var app = App.init(allocator, config);
    defer app.deinit();

    registry.setListener(*App, App.registryListener, &app);

    if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

    if (app.layout_manager == null) {
        std.debug.print("Error: river_layout_manager_v3 not found\n", .{});
        return;
    }

    while (true) {
        if (display.dispatch() != .SUCCESS) break;
    }
}

const App = struct {
    allocator: std.mem.Allocator,
    config: Config,
    layout_manager: ?*river.LayoutManagerV3 = null,
    pending_outputs: std.ArrayListUnmanaged(*wl.Output) = .{},
    contexts: std.ArrayListUnmanaged(*Context) = .{},

    pub fn init(allocator: std.mem.Allocator, config: Config) App {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *App) void {
        self.pending_outputs.deinit(self.allocator);
        for (self.contexts.items) |ctx| {
            self.allocator.destroy(ctx);
        }
        self.contexts.deinit(self.allocator);
    }

    fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, app: *App) void {
        switch (event) {
            .global => |global| {
                const interface_name = std.mem.span(global.interface);
                if (std.mem.eql(u8, interface_name, std.mem.span(river.LayoutManagerV3.interface.name))) {
                    app.layout_manager = registry.bind(global.name, river.LayoutManagerV3, 2) catch |err| {
                        std.debug.print("Failed to bind layout manager: {}\n", .{err});
                        return;
                    };
                    // Initialize pending
                    for (app.pending_outputs.items) |output| {
                        initLayout(app, app.layout_manager.?, output);
                    }
                    app.pending_outputs.clearRetainingCapacity();
                } else if (std.mem.eql(u8, interface_name, std.mem.span(wl.Output.interface.name))) {
                    const output = registry.bind(global.name, wl.Output, 4) catch return;
                    if (app.layout_manager) |manager| {
                        initLayout(app, manager, output);
                    } else {
                        app.pending_outputs.append(app.allocator, output) catch return;
                    }
                }
            },
            else => {},
        }
    }
};

const Context = struct {
    layout: *river.LayoutV3,
    app: *App,
};

fn initLayout(app: *App, manager: *river.LayoutManagerV3, output: *wl.Output) void {
    // Namespace "mascen"
    const layout = manager.getLayout(output, "mascen") catch return;

    const ctx = app.allocator.create(Context) catch return;
    ctx.* = .{ .layout = layout, .app = app };

    layout.setListener(*Context, layoutListener, ctx);

    app.contexts.append(app.allocator, ctx) catch {
        app.allocator.destroy(ctx);
        layout.destroy();
        return;
    };
}

fn layoutListener(layout: *river.LayoutV3, event: river.LayoutV3.Event, ctx: *Context) void {
    const app = ctx.app;
    switch (event) {
        .layout_demand => |demand| {
            handleDemand(ctx, demand);
        },
        .namespace_in_use => {
            std.debug.print("Namespace 'mascen' already in use on this output.\n", .{});
            layout.destroy();
        },
        .user_command => |cmd| {
            // Handle runtime commands
            const cmd_str = std.mem.span(cmd.command);
            var it = std.mem.tokenizeScalar(u8, cmd_str, ' ');
            const command = it.next() orelse return;

            if (std.mem.eql(u8, command, "master-width")) {
                if (it.next()) |val| {
                    app.config.master_width = std.fmt.parseFloat(f64, val) catch app.config.master_width;
                }
            } else if (std.mem.eql(u8, command, "gap")) {
                if (it.next()) |val| {
                    app.config.gap = std.fmt.parseInt(i32, val, 10) catch app.config.gap;
                }
            } else if (std.mem.eql(u8, command, "inner-gap")) {
                if (it.next()) |val| {
                    app.config.inner_gap = std.fmt.parseInt(i32, val, 10) catch app.config.inner_gap;
                }
            } else if (std.mem.eql(u8, command, "smart-gaps")) {
                if (it.next()) |val| {
                    if (std.mem.eql(u8, val, "true")) app.config.smart_gaps = true;
                    if (std.mem.eql(u8, val, "false")) app.config.smart_gaps = false;
                }
            }
        },
        else => {},
    }
}

fn isLeftIndex(stack_count: u32, index: u32) bool {
    // Anchor to the bottom (oldest) of the stack.
    // This ensures that adding windows (at index 0) doesn't shift older windows.
    // We calculate distance from the bottom (stack_count - 1).
    // Distance 0 (Oldest) -> Left
    // Distance 1 -> Right
    // Distance 2 -> Left
    const distance = (stack_count - 1) - index;
    return (distance % 2 == 0);
}

fn handleDemand(ctx: *Context, demand: anytype) void {
    const layout = ctx.layout;
    const config = ctx.app.config;

    const view_count = demand.view_count;
    const usable_width: i32 = @intCast(demand.usable_width);
    const usable_height: i32 = @intCast(demand.usable_height);
    const serial = demand.serial;

    if (view_count == 0) {
        layout.commit("mascen", serial);
        return;
    }

    var gap = config.gap;
    if (config.smart_gaps and view_count == 1) {
        gap = 0;
    }
    const inner_gap = config.inner_gap;

    // Master dimensions
    var master_w_px: i32 = @intFromFloat(@as(f64, @floatFromInt(usable_width)) * config.master_width);
    if (master_w_px > usable_width) master_w_px = usable_width;

    const master_h_px = usable_height - 2 * gap;

    // Centered master x
    const master_x = @divTrunc(usable_width - master_w_px, 2);
    const master_y = gap;

    // Side stacks
    // Left side: x=gap, w = master_x - gap - inner_gap
    var left_w: i32 = master_x - gap - inner_gap;
    const left_x = gap;

    // Right side: x = master_x + master_w_px + inner_gap
    // w = usable_width - x - gap
    const right_x = master_x + master_w_px + inner_gap;
    var right_w: i32 = usable_width - right_x - gap;

    if (left_w < 0) left_w = 0;
    if (right_w < 0) right_w = 0;

    // Check min width
    const min_w: i32 = @intCast(config.min_stack_width);
    var hide_sides = false;
    if (left_w < min_w) hide_sides = true;
    if (right_w < min_w) hide_sides = true;

    // Calculate counts
    // Strategy: Master is always the LAST window (index view_count - 1).
    // Stack is indices 0 to view_count - 2.

    var left_count: u32 = 0;
    var right_count: u32 = 0;

    const stack_count = if (view_count > 0) view_count - 1 else 0;

    var i: u32 = 0;
    while (i < stack_count) : (i += 1) {
        if (isLeftIndex(stack_count, i)) {
            left_count += 1;
        } else {
            right_count += 1;
        }
    }

    const left_count_i32: i32 = @intCast(left_count);
    const right_count_i32: i32 = @intCast(right_count);

    // Heights
    var left_height: i32 = 0;
    if (left_count > 0) {
        left_height = @divTrunc(usable_height - 2 * gap - (left_count_i32 - 1) * inner_gap, left_count_i32);
    }

    var right_height: i32 = 0;
    if (right_count > 0) {
        right_height = @divTrunc(usable_height - 2 * gap - (right_count_i32 - 1) * inner_gap, right_count_i32);
    }

    var current_left_y: i32 = gap;
    var current_right_y: i32 = gap;

    i = 0;
    while (i < view_count) : (i += 1) {
        if (i == view_count - 1) {
            // Master (Last Window)
            layout.pushViewDimensions(master_x, master_y, @intCast(master_w_px), @intCast(master_h_px), serial);
        } else if (hide_sides) {
            // Hide
            layout.pushViewDimensions(-10000, 0, 0, 0, serial);
        } else if (isLeftIndex(stack_count, i)) {
            layout.pushViewDimensions(left_x, current_left_y, @intCast(left_w), @intCast(left_height), serial);
            current_left_y += left_height + inner_gap;
        } else {
            layout.pushViewDimensions(right_x, current_right_y, @intCast(right_w), @intCast(right_height), serial);
            current_right_y += right_height + inner_gap;
        }
    }

    layout.commit("mascen", serial);
}
