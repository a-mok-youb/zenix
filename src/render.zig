const std = @import("std");
const structs = @import("structs.zig");

const Paths = structs.Paths;
const Data = structs.Data;

////////////////////////////////////////////////////////////////
// LOAD FILE
////////////////////////////////////////////////////////////////

pub fn loadFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, size);

    _ = try file.readAll(buffer);
    return buffer;
}

////////////////////////////////////////////////////////////////
// RENDER TEMPLATE
////////////////////////////////////////////////////////////////

pub fn renderTemplate(
    allocator: std.mem.Allocator,
    template: []const u8,
    data: []const Data,
) ![]const u8 {
    var result = template;

    for (data) |r| {
        const replaced = try std.mem.replaceOwned(
            u8,
            allocator,
            result,
            r.key,
            r.value,
        );

        if (result.ptr != template.ptr) {
            allocator.free(result);
        }

        result = replaced;
    }

    if (result.ptr == template.ptr) {
        return try allocator.dupe(u8, template);
    }

    return result;
}

////////////////////////////////////////////////////////////////
// RENDER COMPONENT
////////////////////////////////////////////////////////////////

pub fn renderComponent(
    allocator: std.mem.Allocator,
    // componentPath: Paths.components,
    input: []const u8,
) ![]const u8 {
    var result = try allocator.dupe(u8, input);

    while (true) {
        const start = std.mem.indexOf(u8, result, "<component:") orelse break;
        const end_rel = std.mem.indexOf(u8, result[start..], "/>") orelse break;
        const end = start + end_rel + 2;

        const comp_call = result[start..end];

        const name_start = start + 11;
        const space_pos = std.mem.indexOfScalarPos(u8, result, name_start, ' ') orelse (start + end_rel);

        //const component_Path = try std.fmt.allocPrint(allocator, "{s}/{s}.html", .{ componentPath, result[name_start..space_pos] });
        //defer allocator.free(component_Path);
        const comp_name = result[name_start..space_pos];

        const comp_path = try std.fmt.allocPrint(
            allocator,
            "src/components/{s}.html",
            .{comp_name},
        );
        defer allocator.free(comp_path);

        const comp_template =
            loadFile(allocator, comp_path) catch try allocator.dupe(u8, "<div>Component missing</div>");

        var comp_replacements =
            try std.ArrayList(Data).initCapacity(allocator, 0);
        defer {
            for (comp_replacements.items) |r| {
                allocator.free(r.key);
            }
            comp_replacements.deinit(allocator);
        }

        // props
        const props_str = result[space_pos .. start + end_rel];
        var pos: usize = 0;

        while (pos < props_str.len) {
            while (pos < props_str.len and props_str[pos] == ' ') : (pos += 1) {}

            if (pos >= props_str.len) break;

            const key_start = pos;
            while (pos < props_str.len and props_str[pos] != '=') : (pos += 1) {}

            if (pos >= props_str.len) break;

            const key = props_str[key_start..pos];
            pos += 1;

            while (pos < props_str.len and
                (props_str[pos] == ' ' or props_str[pos] == '"')) : (pos += 1)
            {}

            const val_start = pos;

            while (pos < props_str.len and props_str[pos] != '"') : (pos += 1) {}

            const val = props_str[val_start..pos];

            if (pos < props_str.len) pos += 1;

            const full_key =
                try std.fmt.allocPrint(allocator, "{{{{{s}}}}}", .{key});

            try comp_replacements.append(
                allocator,
                .{ .key = full_key, .value = val },
            );
        }

        const rendered_comp =
            try renderTemplate(
                allocator,
                comp_template,
                comp_replacements.items,
            );

        allocator.free(comp_template);

        const replaced =
            try std.mem.replaceOwned(
                u8,
                allocator,
                result,
                comp_call,
                rendered_comp,
            );

        allocator.free(rendered_comp);
        allocator.free(result);

        result = replaced;
    }

    return result;
}

////////////////////////////////////////////////////////////////
// RENDER PAGE
////////////////////////////////////////////////////////////////

pub fn renderPage(
    allocator: std.mem.Allocator,
    pagePath: []const u8,
    layoutPath: []const u8,
    title: []const u8,
    data: []const Data,
) ![]const u8 {
    const pageContent = try loadFile(allocator, pagePath);
    defer allocator.free(pageContent);

    const layoutContent = try loadFile(allocator, layoutPath);
    defer allocator.free(layoutContent);

    var allReplacements =
        try std.ArrayList(Data).initCapacity(allocator, 0);
    defer allReplacements.deinit(allocator);

    try allReplacements.append(
        allocator,
        .{ .key = "{{title}}", .value = title },
    );

    try allReplacements.append(
        allocator,
        .{ .key = "{{content}}", .value = pageContent },
    );

    for (data) |r| {
        try allReplacements.append(allocator, r);
    }

    const rendered = try renderTemplate(
        allocator,
        layoutContent,
        allReplacements.items,
    );

    defer allocator.free(rendered);

    return try renderComponent(allocator, rendered);
}
