const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zenx_module = b.addModule("zenix", .{
        .root_source_file = b.path("src/zenix.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const options = b.addOptions();
        zenx_module.addOptions("build", options);
    }
}
