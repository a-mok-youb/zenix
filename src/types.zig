pub const Env = enum {
    development,
    production,
};

pub const zenx_config_zon = struct {
    server: struct {
        port: u16 = 3000,
        address: []const u8 = "127.0.0.1",
    } = .{},
    paths: struct {
        pages: [:0]const u8 = "src/pages",
        components: [:0]const u8 = "src/components",
        layouts: [:0]const u8 = "src/layouts",
    } = .{},
    //env: Env = .development,
    //hot_reload: bool = true,
};

pub const Data = struct {
    key: []const u8,
    value: []const u8,
};

pub const Page = struct {
    page: []const u8,
    title: []const u8,
    data: []const Data,
};
