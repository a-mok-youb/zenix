const std = @import("std");
//

pub const Paths = struct {
    pages: [:0]const u8,
    components: [:0]const u8,
    layouts: [:0]const u8,
};

pub const zenx_config = struct {
    port: u16,
    paths: Paths,
};

pub const Data = struct {
    key: []const u8,
    value: []const u8,
};

pub const Page = struct {
    pagePath: []const u8,
    title: []const u8,
    data: []const Data,
};

pub const ErrorPage = struct {
    status: u16,
    errorPagePath: []const u8,
    data: []const Data,
};

pub const Zenix = struct {
    allocator: std.mem.Allocator,
    paths: Paths,
};
