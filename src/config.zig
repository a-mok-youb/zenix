const std = @import("std");
const types = @import("types.zig");
const Zpage = @import("core.zig").Zpage;
const loadFile = @import("utils/loadfile.zig").loadFile;

pub const config = struct {
    Zpage: *Zpage,
    const Self = @This();

    pub fn Zon(self: *Self) !types.config_zon {
        //const file_content = try std.fs.cwd().readFileAllocOptions(
        //self.Zpage.allocator,
        //"zpage.config.zon",
        //1024 * 10,
        //null,
        //.@"1",
        // 0,
        //);
        //defer self.zenix.allocator.free(file_content);

        const comp_template = try loadFile(self.Zpage.allocator, "zpage.config.zon");

        const source = try self.Zpage.allocator.dupeZ(u8, comp_template);
        defer self.Zpage.allocator.free(source);

        const cfg = try std.zon.parse.fromSlice(
            types.config_zon,
            self.Zpage.allocator,
            source,
            null,
            .{},
        );
        self.Zpage.config_zon = cfg;
        return cfg;
    }
};
