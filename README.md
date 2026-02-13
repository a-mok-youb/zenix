# Zenix
High-performance web framework built with Zig.
- [ ] SSR support
- [ ] Template engine
- [ ] Static files serving
- [ ] Hot reload support (dev mode)


# Installation
Add http.zig as a dependency in your build.zig.zon:
 zig fetch --save "git+https://github.com/karlseguin/http.zig#master"
 In your build.zig, add the httpz module as a dependency to your program:
  const httpz = b.dependency("httpz", .{
    .target = target,
    .optimize = optimize,
 });

// the executable from your call to b.addExecutable(...)
exe.root_module.addImport("httpz", httpz.module("httpz"));
The library tracks Zig master. If you're using a specific version of Zig, use the appropriate branch.