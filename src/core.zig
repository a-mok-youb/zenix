const std = @import("std");
const types = @import("types.zig");
const render = @import("render.zig");
const config = @import("config.zig").config;

pub const Zpage = struct {
    allocator: std.mem.Allocator,
    config_zon: ?types.config_zon = null,
    config: config,
    component_cache: render.ComponentCache,

    pub const pageTypes = types.Page;

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Zpage);

        self.* = .{
            .allocator = allocator,
            .config = undefined,
            .config_zon = null,
            .component_cache = render.ComponentCache.init(allocator),
        };

        self.config = .{ .Zpage = self };
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.config_zon) |cfg| {
            std.zon.parse.free(self.allocator, cfg);
            self.config_zon = null;
        }

        self.component_cache.deinit();
        self.allocator.destroy(self);
    }

    pub fn Page(self: *Self, status: u16, page: []const u8, data: []const types.Data) ![]const u8 {
        const cfg = self.config_zon.?;
        const paths = cfg.paths;

        const status_str = try std.fmt.allocPrint(self.allocator, "{d}", .{status});
        defer self.allocator.free(status_str);

        const page_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.html", .{ paths.pages, page });
        defer self.allocator.free(page_path);

        return try render.renderPage(
            self.allocator,
            &self.component_cache,
            page_path,
            data,
        );
    }
};
