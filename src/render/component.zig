const std = @import("std");
const loadFile = @import("../utils/loadfile.zig").loadFile;
const Data = @import("../types.zig").Data;
const tmpl = @import("template.zig");
const dir = @import("directives.zig");

// ─── Slots ───────────────────────────────────────────────────────────────────

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

// ─── Cache ────────────────────────────────────────────────────────────────────

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
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
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
            const owned_name = try self.allocator.dupe(u8, name);
            self.map.put(owned_name, missing) catch {
                self.allocator.free(owned_name);
                self.allocator.free(missing);
                return error.OutOfMemory;
            };
            return missing;
        };

        const owned_name = try self.allocator.dupe(u8, name);
        self.map.put(owned_name, content) catch {
            self.allocator.free(owned_name);
            self.allocator.free(content);
            return error.OutOfMemory;
        };
        return content;
    }
};

// ─── Component Render ─────────────────────────────────────────────────────────

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

        const self_close_pos = std.mem.indexOfPos(u8, input, j, "/>");
        const open_close_pos = std.mem.indexOfPos(u8, input, j, ">");
        const is_self_closing = if (self_close_pos) |sc|
            if (open_close_pos) |oc| sc <= oc else true
        else
            false;

        if (is_self_closing) {
            const sc = self_close_pos.?;
            const props_str = input[j..sc];

            var props = try tmpl.parseProps(allocator, props_str);
            defer props.deinit(allocator);

            const comp_template = try cache.get(comp_name);

            var replacements = try tmpl.buildReplacements(allocator, props, &.{
                .{ .key = "{{slot}}", .value = "" },
            }, global_data);
            defer tmpl.freeReplacements(allocator, &replacements);

            var k: usize = 0;
            while (k < comp_template.len) {
                if (std.mem.startsWith(u8, comp_template[k..], "{{slot:")) {
                    const sn_start = k + 7;
                    const sn_end = std.mem.indexOfPos(u8, comp_template, sn_start, "}}") orelse break;
                    const slot_token = try allocator.dupe(u8, comp_template[k .. sn_end + 2]);
                    if (!tmpl.hasKey(replacements, slot_token)) {
                        try replacements.append(allocator, .{ .key = slot_token, .value = "" });
                    } else {
                        allocator.free(slot_token);
                    }
                    k = sn_end + 2;
                    continue;
                }
                k += 1;
            }

            const templated = try tmpl.Template(allocator, comp_template, replacements.items);
            defer allocator.free(templated);
            const with_directives = try dir.renderDirectives(allocator, templated, replacements.items);
            defer allocator.free(with_directives);
            const final = try ComponentRender(allocator, cache, with_directives, global_data);
            defer allocator.free(final);
            try out.appendSlice(allocator, final);

            i = sc + 2;
            continue;
        }

        const tag_close = open_close_pos orelse {
            try out.append(allocator, input[i]);
            i += 1;
            continue;
        };

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

        var props = try tmpl.parseProps(allocator, props_str);
        defer props.deinit(allocator);

        const comp_template = try cache.get(comp_name);

        const default_slot = try extractDefaultSlot(allocator, children);
        defer allocator.free(default_slot);

        var replacements = try tmpl.buildReplacements(allocator, props, &.{
            .{ .key = "{{slot}}", .value = default_slot },
        }, global_data);
        defer tmpl.freeReplacements(allocator, &replacements);

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

        const templated = try tmpl.Template(allocator, comp_template, replacements.items);
        defer allocator.free(templated);
        const with_directives = try dir.renderDirectives(allocator, templated, replacements.items);
        defer allocator.free(with_directives);
        const final = try ComponentRender(allocator, cache, with_directives, global_data);
        defer allocator.free(final);
        try out.appendSlice(allocator, final);

        i = close_pos + close_tag.len;
    }

    return out.toOwnedSlice(allocator);
}
