const std = @import("std");
const Replacement = @import("structs.zig").Replacement;
const render = @import("render.zig");

pub const Zenix = struct {
    allocator: std.mem.Allocator,

    const PAGE_DIR = "view/pages/";
    const LAYOUT_DIR = "view/layouts/";
    const LAYOUT = "main_layout";

    const PAGE_PATH = PAGE_DIR ++ "{s}.html";
    const LAYOUT_PATH = LAYOUT_DIR ++ "{s}.html";

    pub const Page = struct {
        pagePath: []const u8,
        title: []const u8,
        replacements: []const Replacement,
    };

    pub const ErrorPage = struct {
        status: u16,
        errorPagePath: []const u8,
        replacements: []const Replacement,
    };

    pub fn init(allocator: std.mem.Allocator) Zenix {
        return .{ .allocator = allocator };
    }

    pub fn Html(self: *Zenix, page: Page) ![]const u8 {
        const page_path = try std.fmt.allocPrint(self.allocator, PAGE_PATH, .{page.pagePath});
        defer self.allocator.free(page_path);

        const layout_path = try std.fmt.allocPrint(self.allocator, LAYOUT_PATH, .{LAYOUT});
        defer self.allocator.free(layout_path);

        return try render.renderPage(self.allocator, page_path, layout_path, page.title, page.replacements);
    }

    pub fn Error(self: *Zenix, errorPage: ErrorPage) ![]const u8 {
        const status_str = try std.fmt.allocPrint(self.allocator, "{d}", .{errorPage.status});
        defer self.allocator.free(status_str);

        const page_path = try std.fmt.allocPrint(self.allocator, PAGE_PATH, .{errorPage.errorPagePath});
        defer self.allocator.free(page_path);

        const layout_path = try std.fmt.allocPrint(self.allocator, LAYOUT_PATH, .{LAYOUT});
        defer self.allocator.free(layout_path);

        return try render.renderPage(self.allocator, page_path, layout_path, status_str, errorPage.replacements);
    }
};

//_____ how to use ____________________________________________________________________________________
// In your main function or wherever you want to render a page, you can do something like this:

//const zenix = @import("zenix.zig");
// pub fn main() !void {
//      zenix.init();
//      defer zenix.deinit();
//
//      const replacements = [_]Replacement{
//          .{ .key = "{{title}}", .value = "Welcome to Zenix!" },
//          .{ .key = "{{content}}", .value = "This is a sample page rendered with Zenix." },
//  };
//  const html = try zenix.Html("home", "Home Page", replacements);
//  std.debug.print("{s}\n", .{html});
//}
