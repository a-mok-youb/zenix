const std = @import("std");

const Replacement = @import("structs.zig").Replacement;
const render = @import("render.zig");

pub fn html(
    pagePath: []const u8,
    layoutPath: []const u8,
    title: []const u8,
    replacements: []const Replacement,
) ![]u8 {
    const pageContent = try render.loadFile(pagePath);
    const layoutContent = try render.loadFile(layoutPath);

    var allReplacements = try std.ArrayList(Replacement).initCapacity(std.heap.page_allocator, 0);
    defer allReplacements.deinit(std.heap.page_allocator);

    try allReplacements.append(std.heap.page_allocator, .{ .key = "{{title}}", .value = title });
    try allReplacements.append(std.heap.page_allocator, .{ .key = "{{content}}", .value = pageContent });

    for (replacements) |r| {
        try allReplacements.append(std.heap.page_allocator, r);
    }
    const renderedPage = try render.renderTemplate(layoutContent, allReplacements.items);
    var result = renderedPage;

    result = try render.rendercomponent(result);
    return result;
}

pub fn htmlError(status: u16, errorPagePath: []const u8, layoutPath: []const u8, replacements: []const Replacement) ![]u8 {
    const status_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{status});
    defer std.heap.page_allocator.free(status_str);
    const body = try html(errorPagePath, layoutPath, status_str, replacements);
    return body;
}

//pub fn htmlError(status: u16, message: []const u8, replacements: []const Replacement) ![]u8 {
// const status_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{status});
// defer std.heap.page_allocator.free(status_str);
//const body = try html("frontend/pages/error.html", "frontend/layouts/main_layout.html", status_str, &.{
// .{ .key = "{{status}}", .value = status_str },
//.{ .key = "{{message}}", .value = message },
// });
// return body;
//}
