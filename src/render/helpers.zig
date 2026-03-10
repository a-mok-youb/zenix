const std = @import("std");

pub fn clearUnresolvedTokens(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);

    var i: usize = 0;
    while (i < input.len) {
        if (std.mem.startsWith(u8, input[i..], "{{")) {
            const end = std.mem.indexOfPos(u8, input, i + 2, "}}") orelse {
                try result.append(allocator, input[i]);
                i += 1;
                continue;
            };
            i = end + 2;
            continue;
        }
        try result.append(allocator, input[i]);
        i += 1;
    }
    return result.toOwnedSlice(allocator);
}

pub fn removeBlankLines(allocator: std.mem.Allocator, input: []u8) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, input.len);

    var i: usize = 0;
    while (i < input.len) {
        const line_start = i;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
        const line_end = i;
        if (i < input.len) i += 1;

        const line = input[line_start..line_end];
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
        }
    }

    return out.toOwnedSlice(allocator);
}

pub fn removeEmptyTags(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try allocator.dupe(u8, input);

    const void_tags = [_][]const u8{
        "meta",  "link", "br",  "hr",    "img",   "input",
        "area",  "base", "col", "embed", "param", "source",
        "track", "wbr",
    };

    var changed = true;
    while (changed) {
        changed = false;
        var i: usize = 0;
        while (i < result.len) {
            if (result[i] != '<') {
                i += 1;
                continue;
            }

            if (i + 1 < result.len and (result[i + 1] == '/' or
                result[i + 1] == '!' or result[i + 1] == '?'))
            {
                i += 1;
                continue;
            }

            var j = i + 1;
            while (j < result.len and result[j] != ' ' and
                result[j] != '>' and result[j] != '/') : (j += 1)
            {}
            const tag_name = result[i + 1 .. j];
            if (tag_name.len == 0) {
                i += 1;
                continue;
            }

            var is_void = false;
            for (void_tags) |vt| {
                if (std.mem.eql(u8, tag_name, vt)) {
                    is_void = true;
                    break;
                }
            }
            if (is_void) {
                i += 1;
                continue;
            }

            const open_end = std.mem.indexOfPos(u8, result, j, ">") orelse {
                i += 1;
                continue;
            };
            if (open_end > 0 and result[open_end - 1] == '/') {
                i += 1;
                continue;
            }

            const close_tag = try std.fmt.allocPrint(allocator, "</{s}>", .{tag_name});
            defer allocator.free(close_tag);

            const close_pos = std.mem.indexOfPos(u8, result, open_end + 1, close_tag) orelse {
                i += 1;
                continue;
            };

            const content = result[open_end + 1 .. close_pos];
            const trimmed_content = std.mem.trim(u8, content, " \t\n\r");

            if (trimmed_content.len == 0) {
                const new_result = try std.mem.concat(allocator, u8, &.{
                    result[0..i],
                    result[close_pos + close_tag.len ..],
                });
                allocator.free(result);
                result = new_result;
                changed = true;
                break;
            }
            i += 1;
        }
    }

    const cleaned = try removeBlankLines(allocator, result);
    allocator.free(result);
    return cleaned;
}
