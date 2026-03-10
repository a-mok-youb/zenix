const std = @import("std");
const Data = @import("types.zig").Data;
const tmpl = @import("template.zig");
const json = @import("json.zig");

// ─── If ──────────────────────────────────────────────────────────────────────

pub fn renderIf(allocator: std.mem.Allocator, input: []const u8, data: []const Data) anyerror![]u8 {
    var result = try allocator.dupe(u8, input);

    while (true) {
        const if_start = std.mem.indexOf(u8, result, "{{#if ") orelse break;
        const if_key_end = std.mem.indexOfPos(u8, result, if_start + 6, "}}") orelse break;
        const key_name = result[if_start + 6 .. if_key_end];
        const if_tag_end = if_key_end + 2;

        const endif_tag = "{{/if}}";
        const else_tag = "{{#else}}";

        const endif_pos = std.mem.indexOfPos(u8, result, if_tag_end, endif_tag) orelse break;

        const else_pos = blk: {
            const ep = std.mem.indexOfPos(u8, result, if_tag_end, else_tag) orelse break :blk null;
            if (ep < endif_pos) break :blk ep;
            break :blk null;
        };

        const key_token = try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{key_name});
        defer allocator.free(key_token);

        const is_true = blk: {
            for (data) |d| {
                if (std.mem.eql(u8, d.key, key_token)) {
                    if (d.value.len == 0) break :blk false;
                    if (std.mem.eql(u8, d.value, "false")) break :blk false;
                    if (std.mem.eql(u8, d.value, "0")) break :blk false;
                    break :blk true;
                }
            }
            break :blk false;
        };

        const replacement = if (else_pos) |ep| blk: {
            if (is_true) break :blk result[if_tag_end..ep] else break :blk result[ep + else_tag.len .. endif_pos];
        } else blk: {
            if (is_true) break :blk result[if_tag_end..endif_pos] else break :blk @as([]const u8, "");
        };

        const new_result = try std.mem.concat(allocator, u8, &.{
            result[0..if_start],
            replacement,
            result[endif_pos + endif_tag.len ..],
        });
        allocator.free(result);
        result = new_result;
    }

    return result;
}

// ─── Each Helpers ─────────────────────────────────────────────────────────────

pub fn findEachEnd(input: []const u8, start: usize) ?usize {
    const end_tag = "{{/each}}";
    var depth: usize = 1;
    var i = start;
    while (i < input.len) {
        if (std.mem.startsWith(u8, input[i..], "{{#each ")) {
            depth += 1;
            i += 8;
        } else if (std.mem.startsWith(u8, input[i..], end_tag)) {
            depth -= 1;
            if (depth == 0) return i;
            i += end_tag.len;
        } else {
            i += 1;
        }
    }
    return null;
}

pub fn templateOutsideNested(
    allocator: std.mem.Allocator,
    block: []const u8,
    item_data: []const Data,
) anyerror![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, block.len);
    defer out.deinit(allocator);

    var i: usize = 0;
    while (i < block.len) {
        if (std.mem.startsWith(u8, block[i..], "{{#each ")) {
            const each_key_end = std.mem.indexOfPos(u8, block, i + 8, "}}") orelse {
                try out.append(allocator, block[i]);
                i += 1;
                continue;
            };
            const each_tag_end = each_key_end + 2;
            const nested_end = findEachEnd(block, each_tag_end) orelse block.len;
            const full_end = nested_end + "{{/each}}".len;

            try out.appendSlice(allocator, block[i..full_end]);
            i = full_end;
            continue;
        }

        const next_each = std.mem.indexOfPos(u8, block, i, "{{#each ") orelse block.len;
        const chunk = block[i..next_each];

        const replaced = try tmpl.Template(allocator, chunk, item_data);
        defer allocator.free(replaced);
        try out.appendSlice(allocator, replaced);
        i = next_each;
    }

    return out.toOwnedSlice(allocator);
}

// ─── Resolve nested path من JSON ─────────────────────────────────────────────
// products.user      → يقرأ products من data ثم يستخرج user
// products.tags      → يقرأ products من data ثم يستخرج tags
// products.user.city → يقرأ products ثم user ثم city
fn resolveNestedValue(
    allocator: std.mem.Allocator,
    data: []const Data,
    parent_name: []const u8,
    child_path: []const u8,
) !?[]u8 {
    // ابحث عن الـ parent في data
    const parent_token = try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{parent_name});
    defer allocator.free(parent_token);

    const parent_value = blk: {
        for (data) |d| {
            if (std.mem.eql(u8, d.key, parent_token)) break :blk d.value;
        }
        return null;
    };

    if (parent_value.len == 0) return null;

    // parse الـ parent JSON
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, parent_value, .{}) catch
        return null;
    defer parsed.deinit();

    // تنقل عبر child_path مثل "user" أو "user.city" أو "tags"
    var current = parsed.value;
    var path_iter = std.mem.splitScalar(u8, child_path, '.');
    while (path_iter.next()) |segment| {
        current = switch (current) {
            .object => |obj| obj.get(segment) orelse return null,
            .array => |arr| blk: {
                const idx = std.fmt.parseInt(usize, segment, 10) catch return null;
                if (idx >= arr.items.len) return null;
                break :blk arr.items[idx];
            },
            else => return null,
        };
    }

    // حول النتيجة إلى JSON string
    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();
    try std.json.stringify(current, .{}, buf.writer());
    return try buf.toOwnedSlice();
}

// ─── تحويل JSON string إلى list of maps للـ each ─────────────────────────────
// يدعم:
//   array of objects  → [{"name":"a"},{"name":"b"}]
//   array of scalars  → ["zig","web"]  → كل item يصبح {{item}}
//   object            → {"name":"a"}   → يُعامل كـ row واحد
fn jsonToEachList(
    allocator: std.mem.Allocator,
    value: []const u8,
) !std.ArrayList(std.StringHashMap([]const u8)) {
    const trimmed = std.mem.trim(u8, value, " \t\n\r");

    // ─── array ───────────────────────────────────────────────────────────────
    if (std.mem.startsWith(u8, trimmed, "[")) {
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, value, .{}) catch
            return std.ArrayList(std.StringHashMap([]const u8)).init(allocator);
        defer parsed.deinit();

        const arr = switch (parsed.value) {
            .array => |a| a,
            else => return std.ArrayList(std.StringHashMap([]const u8)).init(allocator),
        };

        var list = try std.ArrayList(std.StringHashMap([]const u8)).initCapacity(allocator, arr.items.len);

        for (arr.items, 0..) |item, idx| {
            var map = std.StringHashMap([]const u8).init(allocator);

            switch (item) {
                // object → flatten
                .object => try json.flattenJson(allocator, &map, "", item),
                // scalar → {{item}} و {{index}}
                else => {
                    const val: []const u8 = switch (item) {
                        .string => |s| try allocator.dupe(u8, s),
                        .integer => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
                        .float => |f| try std.fmt.allocPrint(allocator, "{e}", .{f}),
                        .bool => |b| try allocator.dupe(u8, if (b) "true" else "false"),
                        else => try allocator.dupe(u8, ""),
                    };
                    try map.put(try allocator.dupe(u8, "item"), val);
                    const idx_str = try std.fmt.allocPrint(allocator, "{d}", .{idx});
                    try map.put(try allocator.dupe(u8, "index"), idx_str);
                },
            }
            try list.append(allocator, map);
        }
        return list;
    }

    // ─── object → row واحد ───────────────────────────────────────────────────
    if (std.mem.startsWith(u8, trimmed, "{")) {
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, value, .{}) catch
            return std.ArrayList(std.StringHashMap([]const u8)).init(allocator);
        defer parsed.deinit();

        var list = try std.ArrayList(std.StringHashMap([]const u8)).initCapacity(allocator, 1);
        var map = std.StringHashMap([]const u8).init(allocator);
        try json.flattenJson(allocator, &map, "", parsed.value);
        try list.append(allocator, map);
        return list;
    }

    return std.ArrayList(std.StringHashMap([]const u8)).init(allocator);
}

// ─── Each ────────────────────────────────────────────────────────────────────

pub fn renderEach(allocator: std.mem.Allocator, input: []const u8, data: []const Data) anyerror![]u8 {
    var result = try allocator.dupe(u8, input);

    while (true) {
        const each_start = std.mem.indexOf(u8, result, "{{#each ") orelse break;
        const each_key_end = std.mem.indexOfPos(u8, result, each_start + 8, "}}") orelse break;
        const key_name = result[each_start + 8 .. each_key_end];
        const each_tag_end = each_key_end + 2;

        const endeach_tag = "{{/each}}";
        const endeach_pos = findEachEnd(result, each_tag_end) orelse break;
        const block_template = result[each_tag_end..endeach_pos];

        const key_token = try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{key_name});
        defer allocator.free(key_token);

        // ─── البحث عن الـ value ───────────────────────────────────────────────
        var nested_buf: ?[]u8 = null;
        defer if (nested_buf) |b| allocator.free(b);

        const value: []const u8 = blk: {
            // 1. بحث مباشر {{products}}
            for (data) |d| {
                if (std.mem.eql(u8, d.key, key_token)) break :blk d.value;
            }
            // 2. nested: products.user أو products.tags
            const dot = std.mem.indexOf(u8, key_name, ".") orelse break :blk @as([]const u8, "");
            const parent_name = key_name[0..dot];
            const child_path = key_name[dot + 1 ..];

            const resolved = try resolveNestedValue(allocator, data, parent_name, child_path) orelse
                break :blk @as([]const u8, "");

            nested_buf = resolved;
            break :blk resolved;
        };

        var rendered_block = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer rendered_block.deinit(allocator);

        if (value.len > 0) {
            const trimmed_val = std.mem.trim(u8, value, " \t");

            if (std.mem.startsWith(u8, trimmed_val, "[") or
                std.mem.startsWith(u8, trimmed_val, "{"))
            {
                // ─── JSON ─────────────────────────────────────────────────
                var objects = try jsonToEachList(allocator, value);
                defer json.freeJsonList(allocator, &objects);

                for (objects.items, 0..) |map, idx| {
                    var arena = std.heap.ArenaAllocator.init(allocator);
                    defer arena.deinit();
                    const a = arena.allocator();

                    var item_data = try std.ArrayList(Data).initCapacity(a, 8);
                    const idx_str = try std.fmt.allocPrint(a, "{d}", .{idx});
                    try item_data.append(a, .{ .key = "{{index}}", .value = idx_str });

                    var it = map.iterator();
                    while (it.next()) |entry| {
                        const item_key = try std.fmt.allocPrint(a, "{{{{{s}}}}}", .{entry.key_ptr.*});
                        try item_data.append(a, .{ .key = item_key, .value = entry.value_ptr.* });
                    }

                    const rendered = try templateOutsideNested(a, block_template, item_data.items);
                    const with_nested = try renderDirectives(a, rendered, data);
                    try rendered_block.appendSlice(allocator, with_nested);
                }
            } else {
                // ─── Comma list ───────────────────────────────────────────
                var items = std.mem.splitScalar(u8, value, ',');
                var idx: usize = 0;
                while (items.next()) |item| {
                    var arena = std.heap.ArenaAllocator.init(allocator);
                    defer arena.deinit();
                    const a = arena.allocator();

                    const trimmed_item = std.mem.trim(u8, item, " \t");
                    const idx_str = try std.fmt.allocPrint(a, "{d}", .{idx});

                    const item_data = [_]Data{
                        .{ .key = "{{item}}", .value = trimmed_item },
                        .{ .key = "{{index}}", .value = idx_str },
                    };

                    const rendered = try templateOutsideNested(a, block_template, &item_data);
                    const with_nested = try renderDirectives(a, rendered, data);
                    try rendered_block.appendSlice(allocator, with_nested);
                    idx += 1;
                }
            }
        }

        const new_result = try std.mem.concat(allocator, u8, &.{
            result[0..each_start],
            rendered_block.items,
            result[endeach_pos + endeach_tag.len ..],
        });
        allocator.free(result);
        result = new_result;
    }

    return result;
}

// ─── Directives ──────────────────────────────────────────────────────────────

pub fn renderDirectives(allocator: std.mem.Allocator, input: []const u8, data: []const Data) anyerror![]u8 {
    const after_if = try renderIf(allocator, input, data);
    defer allocator.free(after_if);
    return try renderEach(allocator, after_if, data);
}
