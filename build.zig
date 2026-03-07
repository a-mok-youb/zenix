const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const Zpage = b.addModule("Zpage", .{
        .root_source_file = b.path("src/index.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const options = b.addOptions();
        Zpage.addOptions("build", options);
    }
}
