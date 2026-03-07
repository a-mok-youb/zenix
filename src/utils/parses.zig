const std = @import("std");
const types = @import("../types.zig");

const Data = types.Data;

pub fn Slots(allocator: std.mem.Allocator, content: []const u8) !std.ArrayList(Data) {
    var slots = try std.ArrayList(Data).initCapacity(allocator, 0);
    var pos: usize = 0;

    while (pos < content.len) {
        const slot_pos = std.mem.indexOfPos(u8, content, pos, "slot=\"") orelse break;
        const name_start = slot_pos + 6;
        const name_end = std.mem.indexOfScalarPos(u8, content, name_start, '"') orelse break;
        const slot_name = content[name_start..name_end];

        const inner_start = std.mem.indexOfScalarPos(u8, content, name_end, '>') orelse break;
        const inner_end = std.mem.indexOfScalarPos(u8, content, inner_start, '<') orelse break;
        const inner = content[inner_start + 1 .. inner_end];

        const key = try std.fmt.allocPrint(allocator, "{{{{slot:{s}}}}}", .{slot_name});
        try slots.append(allocator, .{ .key = key, .value = inner });

        pos = inner_end;
    }

    try slots.append(allocator, .{ .key = "{{slot}}", .value = content });

    return slots;
}

pub fn Props(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Data) {
    var props = try std.ArrayList(Data).initCapacity(allocator, 0);

    var pos: usize = 0;

    while (pos < input.len) {
        while (pos < input.len and input[pos] == ' ') : (pos += 1) {}

        if (pos >= input.len) break;

        const key_start = pos;

        while (pos < input.len and input[pos] != '=') : (pos += 1) {}

        if (pos >= input.len) break;

        const key = input[key_start..pos];
        pos += 1;

        while (pos < input.len and (input[pos] == '"' or input[pos] == ' ')) : (pos += 1) {}

        const val_start = pos;

        while (pos < input.len and input[pos] != '"') : (pos += 1) {}

        const val = input[val_start..pos];

        if (pos < input.len) pos += 1;

        const full_key =
            try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{key});

        try props.append(
            allocator,
            .{
                .key = full_key,
                .value = val,
            },
        );
    }

    return props;
}
