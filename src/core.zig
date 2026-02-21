const std = @import("std");
const structs = @import("structs.zig");
const render = @import("render.zig");

const zenx_config = structs.zenx_config;
const Paths = structs.Paths;
const Data = structs.Data;
const Page = structs.Page;
const ErrorPage = structs.ErrorPage;

pub const Zenix = struct {
    allocator: std.mem.Allocator,
    paths: Paths,

    pub fn init(allocator: std.mem.Allocator) !Zenix {
        const cfg = try Zenix.config(allocator);
        return .{ .allocator = allocator, .paths = cfg.paths };
    }

    pub fn config(allocator: std.mem.Allocator) !zenx_config {
        const file_content = try std.fs.cwd().readFileAllocOptions(
            allocator,
            "zenx.config.zon",
            1024 * 10,
            null,
            .@"1",
            0,
        );

        defer allocator.free(file_content);

        return try std.zon.parse.fromSlice(
            zenx_config,
            allocator,
            file_content,
            null,
            .{},
        );
    }
    pub fn Html(self: *Zenix, page: Page) ![]const u8 {
        const page_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.html", .{ self.paths.pages, page.pagePath });
        defer self.allocator.free(page_path);

        const layout_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.html", .{ self.paths.layouts, "main_layout" });
        defer self.allocator.free(layout_path);

        return try render.renderPage(self.allocator, page_path, layout_path, page.title, page.data);
    }

    pub fn Error(self: *Zenix, errorPage: ErrorPage) ![]const u8 {
        const status_str = try std.fmt.allocPrint(self.allocator, "{d}", .{errorPage.status});
        defer self.allocator.free(status_str);

        const page_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.html", .{ self.paths.pages, errorPage.errorPagePath });
        defer self.allocator.free(page_path);

        const layout_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.html", .{ self.paths.layouts, "main_layout" });
        defer self.allocator.free(layout_path);

        return try render.renderPage(self.allocator, page_path, layout_path, status_str, errorPage.data);
    }
};
