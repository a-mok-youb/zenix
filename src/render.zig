const std = @import("std");
const Replacement = @import("structs.zig").Replacement;

//____________ LOADING FILES ___________________________________________________________________________________
pub fn loadFile(path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    _ = try file.readAll(buffer);
    return buffer;
}
//_______________________________________________________________________________________________________________

//____________ RENDERING TEMPLATE _______________________________________________________________________________

pub fn renderTemplate(template: []const u8, replacements: []const Replacement) ![]const u8 {
    var result = template;

    for (replacements) |r| {
        const replaced = try std.mem.replaceOwned(u8, std.heap.page_allocator, result, r.key, r.value);
        if (result.ptr != template.ptr) {
            std.heap.page_allocator.free(result);
        }
        result = replaced;
    }

    return result;
}
//_______________________________________________________________________________________________________________

//____________ RENDERING COMPONENTS _____________________________________________________________________________
pub fn renderComponent(input: []const u8) ![]const u8 {
    var result = input;

    while (true) {
        const start = std.mem.indexOf(u8, result, "<component:") orelse break;
        const end = std.mem.indexOf(u8, result[start..], "/>") orelse break;
        const comp_call = result[start .. start + end + 2];

        const name_start = start + 11;
        const space_pos = std.mem.indexOfScalarPos(u8, result, name_start, ' ') orelse (start + end);
        const comp_name = result[name_start..space_pos];

        const comp_path = try std.fmt.allocPrint(std.heap.page_allocator, "view/components/{s}.html", .{comp_name});
        defer std.heap.page_allocator.free(comp_path);
        const comp_template = loadFile(comp_path) catch "<div>Component missing</div>";

        var comp_replacements = try std.ArrayList(Replacement).initCapacity(std.heap.page_allocator, 0);
        defer {
            for (comp_replacements.items) |r| std.heap.page_allocator.free(r.key);
            comp_replacements.deinit(std.heap.page_allocator);
        }

        const props_str = result[space_pos .. start + end];
        var pos: usize = 0;
        while (pos < props_str.len) {
            // Skip whitespace
            while (pos < props_str.len and props_str[pos] == ' ') : (pos += 1) {}
            if (pos >= props_str.len) break;

            // Find key=
            const key_start = pos;
            while (pos < props_str.len and props_str[pos] != '=') : (pos += 1) {}
            if (pos >= props_str.len) break;

            const key = props_str[key_start..pos];
            pos += 1; // skip '='

            // Skip whitespace and opening quote
            while (pos < props_str.len and (props_str[pos] == ' ' or props_str[pos] == '"')) : (pos += 1) {}
            if (pos >= props_str.len) break;

            const val_start = pos;
            // Find closing quote
            while (pos < props_str.len and props_str[pos] != '"') : (pos += 1) {}
            const val = props_str[val_start..pos];

            if (pos < props_str.len) pos += 1; // skip closing quote

            const full_key = try std.fmt.allocPrint(std.heap.page_allocator, "{{{{{s}}}}}", .{key});
            try comp_replacements.append(std.heap.page_allocator, .{ .key = full_key, .value = val });
        }

        const rendered_comp = try renderTemplate(comp_template, comp_replacements.items);
        const replaced = try std.mem.replaceOwned(u8, std.heap.page_allocator, result, comp_call, rendered_comp);
        if (result.ptr != input.ptr) {
            std.heap.page_allocator.free(result);
        }
        result = replaced;
    }

    return result;
}
//__________________________________________________________________________________________________________________
