const std = @import("std");
const types = @import("types.zig");
const Zenix = @import("core.zig").Zenix;
const loadFile = @import("utils/loadfile.zig").loadFile;

pub const config = struct {
    zenix: *Zenix,
    const Self = @This();

    pub fn Zon(self: *Self) !types.zenx_config_zon {
        //const file_content = try std.fs.cwd().readFileAllocOptions(
        //self.zenix.allocator,
        //"zenx.config.zon",
        //1024 * 10,
        //null,
        //.@"1",
        // 0,
        //);
        //defer self.zenix.allocator.free(file_content);

        const comp_template = try loadFile(self.zenix.allocator, "zenx.config.zon");

        const source = try self.zenix.allocator.dupeZ(u8, comp_template);
        defer self.zenix.allocator.free(source);

        const cfg = try std.zon.parse.fromSlice(
            types.zenx_config_zon,
            self.zenix.allocator,
            source,
            null,
            .{},
        );
        self.zenix.zenx_config_zon = cfg;
        return cfg;
    }
};
