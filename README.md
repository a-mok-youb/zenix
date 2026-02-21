# Zenix

⚠️ This project is under active development and not ready for production use.

# Installation Guide

1️⃣ Add Zenix as a dependency in your build.zig.zon:

> [!NOTE]
>```bash
>zig fetch --save >https://github.com/a-mok-youb/zenix/archive/refs/heads/main.tar.gz
>```

2️⃣ In your build.zig, add the zenix module as a dependency to your program:

> [!NOTE] add this code in **build.zig** file
>```bash
> const zenix = b.dependency("zenix", .{
>    .target = target,
>    .optimize = optimize,
>  });
>
>  exe.root_module.addImport("zenix", zenix.module("zenix"));
>```

The library tracks Zig master. If you're using a specific version of Zig, use the appropriate branch.

add file **zenx.config.zon** in your project folder
> [!NOTE] **zenx.config.zon**
>```bash
>.{
>    .port = 8080,
>    .paths = .{
>        .pages = "src/pages",
>        .components = "src/components",
>        .layouts = "src/layouts",
>    },
>}
>```

How to use

```bash
const std = @import("std");
const Zenix = @import("zenix").Zenix;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const cfg = try Zenix.config(allocator);
    var app = try Zenix.init(allocator);

    const html = try app.Html(.{ .pagePath = "index", .title = "Home Page", .data = &.{
        .{ .key = "{{title}}", .value = "Welcome to Zenix!" },
        .{ .key = "{{content}}", .value = "This is a sample page rendered with Zenix." },
    } });

    defer allocator.free(html);

    std.debug.print("{s}\n", .{html});
}
```

# whit [http.zig](https://github.com/karlseguin/http.zig)

```bash
const std = @import("std");
const httpz = @import("httpz");
const Zenix = @import("zenix").Zenix;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const cfg = try Zenix.config(allocator);

    var handler = Handler{
        .allocator = allocator,
        .zenix = try Zenix.init(allocator),
    };

    var server = try httpz.Server(*Handler).init(
        allocator,
        .{ .port = cfg.port },
        &handler,
    );
    defer server.deinit();
    defer server.stop();

    var router = try server.router(.{});
    router.get("/", index, .{});
    router.get("/error", @"error", .{});

    std.debug.print("listening http://localhost:{d}/\n", .{cfg.port});
    try server.listen();
}

const Handler = struct {
    allocator: std.mem.Allocator,
    zenix: Zenix,

    _hits: usize = 0,

    pub fn notFound(self: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
        res.status = 404;

        const body = try self.zenix.Error(.{
            .status = 404,
            .errorPagePath = "error",
            .data = &.{
                .{ .key = "{{status}}", .value = "404" },
                .{ .key = "{{message}}", .value = "page not found" },
            },
        });

        res.body = body;
    }

    pub fn uncaughtError(
        self: *Handler,
        req: *httpz.Request,
        res: *httpz.Response,
        err: anyerror,
    ) void {
        std.debug.print("uncaught http error at {s}: {}\n", .{ req.url.path, err });
        res.status = 500;

        if (self.zenix.Error(.{
            .status = 500,
            .errorPagePath = "error",
            .data = &.{
                .{ .key = "{{status}}", .value = "500" },
                .{ .key = "{{message}}", .value = "Internal Server Error" },
            },
        })) |body| {
            res.body = body;
        } else |_| {
            res.body = "Internal Server Error";
        }
    }
};

fn index(self: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    const body = try self.zenix.Html(.{
        .pagePath = "index",
        .title = "index",
        .data = &.{
            .{ .key = "{{username}}", .value = "ayoub" },
            .{ .key = "{{items}}", .value = "<li>Rust</li><li>Zig</li>" },
            .{ .key = "{{title}}", .value = "Card Title" },
            .{ .key = "{{description}}", .value = "product description" },
        },
    });

    res.body = body;
}

fn @"error"(_: *Handler, _: *httpz.Request, _: *httpz.Response) !void {
    return error.ActionError;
}


```

## License

[MIT](https://choosealicense.com/licenses/mit/)
