const std = @import("std");
////////////////////////////////////////////////////////////////
// LOAD FILE
////////////////////////////////////////////////////////////////
pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, size);

    _ = try file.readAll(buffer);
    return buffer;
}
