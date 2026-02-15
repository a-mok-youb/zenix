const std = @import("std");
const Replacement = @import("structs.zig").Replacement;
const render = @import("render.zig");

pub fn Html(
    pagePath: []const u8,
    layoutPath: []const u8,
    title: []const u8,
    replacements: []const Replacement,
) ![]const u8 {
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

    result = try render.renderComponent(result);
    return result;
}

pub fn Error(status: u16, errorPagePath: []const u8, replacements: []const Replacement) ![]const u8 {
    const status_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{status});
    defer std.heap.page_allocator.free(status_str);

    const page_path = try std.fmt.allocPrint(std.heap.page_allocator, "view/pages/{s}.html", .{errorPagePath});
    defer std.heap.page_allocator.free(page_path);

    const layout = "main_layout";
    const layout_path = try std.fmt.allocPrint(std.heap.page_allocator, "view/layouts/{s}.html", .{layout});
    defer std.heap.page_allocator.free(layout_path);

    return try Html(page_path, layout_path, status_str, replacements);
}
