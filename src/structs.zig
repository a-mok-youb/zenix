const std = @import("std");
//
pub const Paths = struct {
    pages: []const u8,
    components: []const u8,
    layouts: []const u8,
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
