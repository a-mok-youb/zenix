const std = @import("std");

pub fn flattenJson(
    allocator: std.mem.Allocator,
    map: *std.StringHashMap([]const u8),
    prefix: []const u8,
    value: std.json.Value,
) !void {
    switch (value) {
        .object => |obj| {
            var it = obj.iterator();
            while (it.next()) |entry| {
                const key = if (prefix.len == 0)
                    try allocator.dupe(u8, entry.key_ptr.*)
                else
                    try std.fmt.allocPrint(allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* });
                defer allocator.free(key);
                try flattenJson(allocator, map, key, entry.value_ptr.*);
            }
        },
        .array => |arr| {
            for (arr.items, 0..) |item, idx| {
                const key = if (prefix.len == 0)
                    try std.fmt.allocPrint(allocator, "{d}", .{idx})
                else
                    try std.fmt.allocPrint(allocator, "{s}.{d}", .{ prefix, idx });
                defer allocator.free(key);
                try flattenJson(allocator, map, key, item);
            }
        },
        else => {
            const key = try allocator.dupe(u8, prefix);
            errdefer allocator.free(key);
            const val: []const u8 = switch (value) {
                .string => |s| try allocator.dupe(u8, s),
                .integer => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
                .float => |f| try std.fmt.allocPrint(allocator, "{e}", .{f}),
                .bool => |b| try allocator.dupe(u8, if (b) "true" else "false"),
                .null => try allocator.dupe(u8, ""),
                else => try allocator.dupe(u8, ""),
            };
            errdefer allocator.free(val);
            try map.put(key, val);
        },
    }
}

pub fn parseJsonArray(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(std.StringHashMap([]const u8)) {
    var list = try std.ArrayList(std.StringHashMap([]const u8)).initCapacity(allocator, 4);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, input, .{}) catch return list;
    defer parsed.deinit();

    const array = switch (parsed.value) {
        .array => |a| a,
        else => return list,
    };

    for (array.items) |item| {
        var map = std.StringHashMap([]const u8).init(allocator);
        try flattenJson(allocator, &map, "", item);
        try list.append(allocator, map);
    }

    return list;
}

pub fn freeJsonList(allocator: std.mem.Allocator, list: *std.ArrayList(std.StringHashMap([]const u8))) void {
    for (list.items) |*map| {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }
    list.deinit(allocator);
}
