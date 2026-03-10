const std = @import("std");
const Data = @import("../types.zig").Data;

pub fn parseProps(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Data) {
    var props = try std.ArrayList(Data).initCapacity(allocator, 4);

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] == ' ' or input[i] == '\t' or
            input[i] == '\n' or input[i] == '\r')) : (i += 1)
        {}
        if (i >= input.len) break;

        const key_start = i;
        while (i < input.len and input[i] != '=') : (i += 1) {}
        if (i >= input.len) break;
        const key = std.mem.trim(u8, input[key_start..i], " \t");
        i += 1;
        if (i >= input.len) break;

        if (input[i] == '"') {
            i += 1;
            const val_start = i;
            while (i < input.len and input[i] != '"') : (i += 1) {}
            if (i >= input.len) break;
            const val = input[val_start..i];
            i += 1;
            try props.append(allocator, .{ .key = key, .value = val });
            continue;
        }

        if (std.mem.startsWith(u8, input[i..], "{{")) {
            const tok_end = std.mem.indexOfPos(u8, input, i + 2, "}}") orelse break;
            const val = input[i .. tok_end + 2];
            i = tok_end + 2;
            try props.append(allocator, .{ .key = key, .value = val });
            continue;
        }

        const val_start = i;
        while (i < input.len and input[i] != ' ' and input[i] != '/' and
            input[i] != '>' and input[i] != '\t') : (i += 1)
        {}
        const val = input[val_start..i];
        try props.append(allocator, .{ .key = key, .value = val });
    }
    return props;
}

pub fn Template(allocator: std.mem.Allocator, template: []const u8, data: []const Data) ![]const u8 {
    var result = template;
    var owns = false;

    for (data) |r| {
        const replaced = try std.mem.replaceOwned(u8, allocator, result, r.key, r.value);
        if (owns) allocator.free(result);
        result = replaced;
        owns = true;
    }

    if (!owns) return try allocator.dupe(u8, template);
    return result;
}

pub fn hasKey(list: std.ArrayList(Data), key: []const u8) bool {
    for (list.items) |r| {
        if (std.mem.eql(u8, r.key, key)) return true;
    }
    return false;
}

pub fn buildReplacements(
    allocator: std.mem.Allocator,
    props: std.ArrayList(Data),
    extra: []const Data,
    global_data: []const Data,
) !std.ArrayList(Data) {
    var list = try std.ArrayList(Data).initCapacity(allocator, props.items.len + extra.len);

    for (props.items) |p| {
        const wrapped_key = try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{p.key});

        const resolved_value = blk: {
            if (std.mem.startsWith(u8, p.value, "{{") and
                std.mem.endsWith(u8, p.value, "}}"))
            {
                for (global_data) |g| {
                    if (std.mem.eql(u8, g.key, p.value)) break :blk g.value;
                }
            }
            break :blk p.value;
        };

        try list.append(allocator, .{ .key = wrapped_key, .value = resolved_value });
    }
    for (extra) |e| {
        const key = try allocator.dupe(u8, e.key);
        try list.append(allocator, .{ .key = key, .value = e.value });
    }
    return list;
}

pub fn freeReplacements(allocator: std.mem.Allocator, list: *std.ArrayList(Data)) void {
    for (list.items) |r| allocator.free(r.key);
    list.deinit(allocator);
}
