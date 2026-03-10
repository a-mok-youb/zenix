const std = @import("std");
const loadFile = @import("../utils/loadfile.zig").loadFile;
const Data = @import("../types.zig").Data;
const tmpl = @import("template.zig");
const helpers = @import("helpers.zig");
const comp = @import("component.zig");
const dir = @import("directives.zig");

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
        return try std.fmt.allocPrint(allocator, "<div>layout {s} not found</div>", .{layout_name});
    };
    defer allocator.free(layout_template);

    var props = try tmpl.parseProps(allocator, props_str);
    defer props.deinit(allocator);

    var replacements = try tmpl.buildReplacements(allocator, props, &.{
        .{ .key = "{{content}}", .value = content },
    }, &.{});
    defer tmpl.freeReplacements(allocator, &replacements);

    return try tmpl.Template(allocator, layout_template, replacements.items);
}

pub fn renderPage(
    allocator: std.mem.Allocator,
    cache: *comp.ComponentCache,
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

    const rendered = try comp.ComponentRender(allocator, cache, with_layout, wrapped.items);
    defer allocator.free(rendered);

    const templated = try tmpl.Template(allocator, rendered, wrapped.items);
    defer allocator.free(templated);

    const with_directives = try dir.renderDirectives(allocator, templated, wrapped.items);
    defer allocator.free(with_directives);

    const cleared = try helpers.clearUnresolvedTokens(allocator, with_directives);
    defer allocator.free(cleared);

    return try helpers.removeEmptyTags(allocator, cleared);
}
