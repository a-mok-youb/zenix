<<<<<<< HEAD
# Zenix

⚠️ This project is under active development and not ready for production use.


High-performance web framework built with Zig.
- [ ] SSR support
- [ ] Template engine
- [ ] Static files serving
- [ ] Hot reload support (dev mode)


# Installation
Add zenix.zig as a dependency in your build.zig.zon:
```bash
 zig fetch --save https://github.com/a-mok-youb/zenix/archive/refs/heads/main.tar.gz
```
 In your build.zig, add the zenix module as a dependency to your program:
```bash
 const zenix = b.dependency("zenix", .{
    .target = target,
    .optimize = optimize,
  });

  exe.root_module.addImport("zenix", zenix.module("zenix"));
```

The library tracks Zig master. If you're using a specific version of Zig, use the appropriate branch.

## License

[MIT](https://choosealicense.com/licenses/mit/)
=======
# zenix
>>>>>>> 7146dce1b55327ef894260dcc6335754de040090
