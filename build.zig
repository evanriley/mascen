const std = @import("std");
const Scanner = @import("wayland").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Pass a dummy path for wayland_protocols to avoid pkg-config failure
    // since we are not using system protocols anyway.
    const scanner = Scanner.create(b, .{
        .wayland_protocols = b.path("protocol"), 
    });
    const wayland = b.createModule(.{ .root_source_file = scanner.result });

    // Add the river layout protocol
    scanner.addCustomProtocol(b.path("protocol/river-layout-v3.xml"));

    // Generate bindings
    scanner.generate("wl_output", 4);
    scanner.generate("river_layout_manager_v3", 2);

    const exe = b.addExecutable(.{
        .name = "mascen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addImport("wayland", wayland);
    exe.linkLibC();
    exe.linkSystemLibrary("wayland-client");

    b.installArtifact(exe);
}
