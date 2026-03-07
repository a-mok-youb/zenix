const std = @import("std");
const loadFile = @import("utils/loadfile.zig").loadFile;
const types = @import("types.zig");
const Data = types.Data;

fn extractNamedSlot(allocator: std.mem.Allocator, input: []const u8, name: []const u8) !?[]const u8 {
    const open_tag = try std.fmt.allocPrint(allocator, "<slot:{s}>", .{name});
    defer allocator.free(open_tag);
    const close_tag = try std.fmt.allocPrint(allocator, "</slot:{s}>", .{name});
    defer allocator.free(close_tag);

    const start = std.mem.indexOf(u8, input, open_tag) orelse return null;
    const content_start = start + open_tag.len;
    const end = std.mem.indexOf(u8, input[content_start..], close_tag) orelse return null;

    return input[content_start .. content_start + end];
}

fn extractDefaultSlot(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try allocator.dupe(u8, input);

    var i: usize = 0;
    while (i < result.len) {
        if (std.mem.startsWith(u8, result[i..], "<slot:")) {
            const tag_end = std.mem.indexOfPos(u8, result, i + 6, ">") orelse break;
            const slot_name = result[i + 6 .. tag_end];
            const close_tag = try std.fmt.allocPrint(allocator, "</slot:{s}>", .{slot_name});
            defer allocator.free(close_tag);

            const close_pos = std.mem.indexOfPos(u8, result, tag_end, close_tag) orelse break;
            const full_end = close_pos + close_tag.len;

            const new_result = try std.mem.concat(allocator, u8, &.{
                result[0..i],
                result[full_end..],
            });
            allocator.free(result);
            result = new_result;
            continue;
        }
        i += 1;
    }

    const trimmed = std.mem.trim(u8, result, " \t\n\r");
    const owned = try allocator.dupe(u8, trimmed);
    allocator.free(result);
    return owned;
}

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
        if (i >= input.len or input[i] != '"') break;
        i += 1;

        const val_start = i;
        while (i < input.len and input[i] != '"') : (i += 1) {}
        if (i >= input.len) break;
        const val = input[val_start..i];
        i += 1;

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

pub const ComponentCache = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) ComponentCache {
        return .{
            .allocator = allocator,
            .map = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ComponentCache) void {
        var it = self.map.iterator();
        while (it.next()) |entry| self.allocator.free(entry.value_ptr.*);
        self.map.deinit();
    }

    pub fn get(self: *ComponentCache, name: []const u8) ![]const u8 {
        if (self.map.get(name)) |v| return v;

        const path = try std.fmt.allocPrint(self.allocator, "src/components/{s}.html", .{name});
        defer self.allocator.free(path);

        const content = loadFile(self.allocator, path) catch {
            const missing = try std.fmt.allocPrint(
                self.allocator,
                "<div>Component {s} missing</div>",
                .{name},
            );
            try self.map.put(name, missing);
            return missing;
        };

        try self.map.put(name, content);
        return content;
    }
};

fn buildReplacements(
    allocator: std.mem.Allocator,
    props: std.ArrayList(Data),
    extra: []const Data,
) !std.ArrayList(Data) {
    var list = try std.ArrayList(Data).initCapacity(allocator, props.items.len + extra.len);

    for (props.items) |p| {
        const wrapped = try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{p.key});
        try list.append(allocator, .{ .key = wrapped, .value = p.value });
    }
    for (extra) |e| {
        const key = try allocator.dupe(u8, e.key);
        try list.append(allocator, .{ .key = key, .value = e.value });
    }
    return list;
}

fn freeReplacements(allocator: std.mem.Allocator, list: *std.ArrayList(Data)) void {
    for (list.items) |r| allocator.free(r.key);
    list.deinit(allocator);
}

fn hasKey(list: std.ArrayList(Data), key: []const u8) bool {
    for (list.items) |r| {
        if (std.mem.eql(u8, r.key, key)) return true;
    }
    return false;
}

fn clearUnresolvedTokens(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);

    var i: usize = 0;
    while (i < input.len) {
        if (std.mem.startsWith(u8, input[i..], "{{")) {
            const end = std.mem.indexOfPos(u8, input, i + 2, "}}") orelse {
                try result.append(allocator, input[i]);
                i += 1;
                continue;
            };
            // تخطي الـ token كاملاً
            i = end + 2;
            continue;
        }
        try result.append(allocator, input[i]);
        i += 1;
    }
    return result.toOwnedSlice(allocator);
}

pub fn ComponentRender(
    allocator: std.mem.Allocator,
    cache: *ComponentCache,
    input: []const u8,
    global_data: []const Data,
) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, input.len);

    var i: usize = 0;
    while (i < input.len) {
        if (!std.mem.startsWith(u8, input[i..], "<component:")) {
            try out.append(allocator, input[i]);
            i += 1;
            continue;
        }

        const name_start = i + 11;
        var j = name_start;
        while (j < input.len and input[j] != ' ' and input[j] != '/' and input[j] != '>') : (j += 1) {}
        const comp_name = input[name_start..j];

        const tag_close = std.mem.indexOfPos(u8, input, j, ">") orelse {
            try out.append(allocator, input[i]);
            i += 1;
            continue;
        };

        const is_self_closing = tag_close > 0 and input[tag_close - 1] == '/';

        if (is_self_closing) {
            const props_str = input[j .. tag_close - 1];
            var props = try parseProps(allocator, props_str);
            defer props.deinit(allocator);

            const comp_template = try cache.get(comp_name);

            var replacements = try buildReplacements(allocator, props, &.{
                .{ .key = "{{slot}}", .value = "" },
            });
            defer freeReplacements(allocator, &replacements);

            // named slots فارغة
            var k: usize = 0;
            while (k < comp_template.len) {
                if (std.mem.startsWith(u8, comp_template[k..], "{{slot:")) {
                    const sn_start = k + 7;
                    const sn_end = std.mem.indexOfPos(u8, comp_template, sn_start, "}}") orelse break;
                    const slot_token = try allocator.dupe(u8, comp_template[k .. sn_end + 2]);
                    if (!hasKey(replacements, slot_token)) {
                        try replacements.append(allocator, .{ .key = slot_token, .value = "" });
                    } else {
                        allocator.free(slot_token);
                    }
                    k = sn_end + 2;
                    continue;
                }
                k += 1;
            }

            const rendered = try Template(allocator, comp_template, replacements.items);
            defer allocator.free(rendered);
            // ✅ مرر global_data للـ recursive call فقط للـ page-level tokens
            const final = try ComponentRender(allocator, cache, rendered, global_data);
            defer allocator.free(final);
            try out.appendSlice(allocator, final);

            i = tag_close + 1;
            continue;
        }

        // Block component
        const props_str = input[j..tag_close];
        const children_start = tag_close + 1;

        const close_tag = try std.fmt.allocPrint(allocator, "</component:{s}>", .{comp_name});
        defer allocator.free(close_tag);

        const close_pos = std.mem.indexOfPos(u8, input, children_start, close_tag) orelse {
            try out.append(allocator, input[i]);
            i += 1;
            continue;
        };

        const children = input[children_start..close_pos];

        var props = try parseProps(allocator, props_str);
        defer props.deinit(allocator);

        const comp_template = try cache.get(comp_name);

        const default_slot = try extractDefaultSlot(allocator, children);
        defer allocator.free(default_slot);

        var replacements = try buildReplacements(allocator, props, &.{
            .{ .key = "{{slot}}", .value = default_slot },
        });
        defer freeReplacements(allocator, &replacements);

        // named slots فقط — بدون global_data ✅
        {
            var k: usize = 0;
            while (k < comp_template.len) {
                if (std.mem.startsWith(u8, comp_template[k..], "{{slot:")) {
                    const sn_start = k + 7;
                    const sn_end = std.mem.indexOfPos(u8, comp_template, sn_start, "}}") orelse break;
                    const slot_name = comp_template[sn_start..sn_end];
                    const slot_token = try allocator.dupe(u8, comp_template[k .. sn_end + 2]);
                    const slot_content = try extractNamedSlot(allocator, children, slot_name);
                    try replacements.append(allocator, .{
                        .key = slot_token,
                        .value = slot_content orelse "",
                    });
                    k = sn_end + 2;
                    continue;
                }
                k += 1;
            }
        }

        const rendered = try Template(allocator, comp_template, replacements.items);
        defer allocator.free(rendered);
        const final = try ComponentRender(allocator, cache, rendered, global_data);
        defer allocator.free(final);
        try out.appendSlice(allocator, final);

        i = close_pos + close_tag.len;
    }

    return out.toOwnedSlice(allocator);
}

pub fn LayoutTag(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    const start = std.mem.indexOf(u8, input, "<layout:") orelse return try allocator.dupe(u8, input);
    const name_start = start + 8;

    var j = name_start;
    while (j < input.len and input[j] != ' ' and input[j] != '>') : (j += 1) {}
    const layout_name = input[name_start..j];

    const open_end = std.mem.indexOfPos(u8, input, j, ">") orelse return try allocator.dupe(u8, input);
    const props_str = input[j..open_end];

    const close_tag = "</layout>";
    const close_pos = std.mem.indexOf(u8, input[open_end..], close_tag) orelse
        return try allocator.dupe(u8, input);
    const content = input[open_end + 1 .. open_end + close_pos];

    const layout_path = try std.fmt.allocPrint(allocator, "src/layouts/{s}.html", .{layout_name});
    defer allocator.free(layout_path);

    const layout_template = loadFile(allocator, layout_path) catch |err| {
        std.debug.print("Layout error: {}\n", .{err});
        return try std.fmt.allocPrint(
            allocator,
            "<div>layout {s} not found</div>",
            .{layout_name},
        );
    };
    defer allocator.free(layout_template);

    var props = try parseProps(allocator, props_str);
    defer props.deinit(allocator);

    var replacements = try buildReplacements(allocator, props, &.{
        .{ .key = "{{content}}", .value = content },
    });
    defer freeReplacements(allocator, &replacements);

    return try Template(allocator, layout_template, replacements.items);
}

pub fn renderPage(
    allocator: std.mem.Allocator,
    cache: *ComponentCache,
    page: []const u8,
    data: []const Data,
) ![]const u8 {
    const page_content = try loadFile(allocator, page);
    defer allocator.free(page_content);

    const with_layout = try LayoutTag(allocator, page_content);
    defer allocator.free(with_layout);

    var wrapped = try std.ArrayList(Data).initCapacity(allocator, data.len);
    defer {
        for (wrapped.items) |r| allocator.free(r.key);
        wrapped.deinit(allocator);
    }
    for (data) |d| {
        const wk = try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{d.key});
        try wrapped.append(allocator, .{ .key = wk, .value = d.value });
    }

    const templated = try Template(allocator, with_layout, wrapped.items);
    defer allocator.free(templated);

    const rendered = try ComponentRender(allocator, cache, templated, wrapped.items);
    defer allocator.free(rendered);

    // امسح أي {{token}} لم يُستبدل
    return try clearUnresolvedTokens(allocator, rendered);
}
