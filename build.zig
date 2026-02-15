

const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zenix_module = b.addModule("zenix", .{
        .root_source_file = b.path("src/zenix.zig"),
        .target = target,
        .optimize = optimize,
    });

     {
        const options = b.addOptions();
        zenix_module.addOptions("build", options);
    }
}
