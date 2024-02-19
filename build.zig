const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("liburing", .{});

    const lib = b.addStaticLibrary(.{
        .name = "liburing",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(upstream.path("src/include"));

    // TODO: Auto generate this file
    // lib.addIncludePath(upstream.path("config-host.h"));

    // gcc -D_GNU_SOURCE 
    //  -Iinclude/ 
    //  -include ../config-host.h 
    //  -D_LARGEFILE_SOURCE
    //  -D_FILE_OFFSET_BITS=64
    //  -nostdlib
    //  -nodefaultlibs
    //  -ffreestanding
    //  -fno-builtin
    //  -fno-stack-protector
    //  -MT "setup.ol
    //  -MMD
    //  -MP
    //  -MF
    //  "setup.ol.d"
    //  -O3
    //  -Wall
    //  -Wextra
    //  -fno-stack-protector
    //  -Wno-unused-parameter
    //  -DLIBURING_INTERNAL 
    //  -nostdlib
    //  -nodefaultlibs
    //  -ffreestanding
    //  -fno-builtin
    //  -fno-stack-protector
    //  -c
    //  -o setup.ol
    //  setup.c

    const lib_srcs = &.{
      "src/setup.c",
      "src/queue.c",
      "src/register.c",
      "src/syscall.c",
      "src/version.c",
      "src/nolibc.c",
    };

    const config_h = b.addConfigHeader(.{
      .style = .blank,
      .include_path = "config-host.h",
    }, .{
      .CONFIG_NOLIBC = switch (target.result.cpu.arch) {
        // https://github.com/axboe/liburing/blob/liburing-2.5/configure#L392
        .aarch64, .riscv32, .riscv64, .x86, .x86_64 => {},
        else => null,
      },
      // TODO: All these defines come from config-host.h which is generated
      // by configure.
      .CONFIG_HAVE_KERNEL_RWF_T = {},
      .CONFIG_HAVE_KERNEL_TIMESPEC = {},
      .CONFIG_HAVE_OPEN_HOW = {},
      .CONFIG_HAVE_STATX = {},
      .CONFIG_HAVE_GLIBC_STATX = {},
      .CONFIG_HAVE_CXX = {},
      .CONFIG_HAVE_UCONTEXT = {},
      .CONFIG_HAVE_STRINGOP_OVERFLOW = {},
      .CONFIG_HAVE_ARRAY_BOUNDS = {},
      .CONFIG_HAVE_NVME_URING = {},
      .CONFIG_HAVE_FANOTIFY = {},
      .CONFIG_HAVE_FUTEXV = {},
      // AT_FDCWD does not seem to be defined for some reason
      // TODO: Remove this kludge
      .AT_FDCWD = -100,
    });
    // config_h.addValues(common_config);
    lib.addConfigHeader(config_h);
    lib.installConfigHeader(config_h, .{});

    var flags = std.ArrayList([]const u8).init(b.allocator);
    
    flags.appendSlice(&.{
      "-DCONFIG_HAVE_FUTEXV",
      "-D_LARGEFILE_SOURCE",
      "-D_FILE_OFFSET_BITS=64",
      "-DLIBURING_INTERNAL",
      "-ffreestanding",
      "-fno-builtin", 
      "-Wall",
      "-Wextra",  
      "-Wno-unused-parameter",
    }) catch unreachable;
   
    flags.appendSlice(switch (optimize) {
      .Debug => &.{
        "-ggdb3",
        "-fsanitize=undefined",
      },   
      .ReleaseSafe => &.{
        "-fsanitize=undefined",
      },  
      .ReleaseFast => &.{
        "-fno-stack-protector",
        "-O3", 
      }, 
      .ReleaseSmall => &.{
        "-Os", 
      },
    }) catch unreachable;

    flags.appendSlice(switch (target.result.cpu.arch) {
      // https://github.com/axboe/liburing/blob/liburing-2.5/configure#L392
      .aarch64, .riscv32, .riscv64, .x86, .x86_64 => &.{ "-nostdlib", "-nodefaultlibs" },
      else => &.{},
    }) catch unreachable;

    lib.addCSourceFiles(.{
      .dependency = upstream,
      .files = lib_srcs,
      .flags = flags.items,
    });

    b.installArtifact(lib);
    lib.linkLibC();
}
