// ─── re-exports ───────────────────────────────────────────────────────────────
pub const Data = @import("../types.zig").Data;
pub const ComponentCache = @import("component.zig").ComponentCache;

pub const renderPage = @import("layout.zig").renderPage;
pub const Template = @import("template.zig").Template;
pub const parseProps = @import("template.zig").parseProps;
pub const renderDirectives = @import("directives.zig").renderDirectives;
