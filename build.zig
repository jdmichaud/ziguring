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

    var flags = std.ArrayList([]const u8).init(b.allocator);

    // const constant_flags: []const []const u8 = &.{
    flags.appendSlice(&.{
      // TODO: All these defines come from config-host.h which is generated
      // by configure.
      "-DCONFIG_HAVE_KERNEL_RWF_T",
      "-DCONFIG_HAVE_KERNEL_TIMESPEC",
      "-DCONFIG_HAVE_OPEN_HOW",
      "-DCONFIG_HAVE_STATX",
      "-DCONFIG_HAVE_GLIBC_STATX",
      "-DCONFIG_HAVE_CXX",
      "-DCONFIG_HAVE_UCONTEXT",
      "-DCONFIG_HAVE_STRINGOP_OVERFLOW",
      "-DCONFIG_HAVE_ARRAY_BOUNDS",
      "-DCONFIG_HAVE_NVME_URING",
      "-DCONFIG_HAVE_FANOTIFY",
      "-DCONFIG_HAVE_FUTEXV",
      // end auto generated defines

      // AT_FDCWD does not seem to be defined for some reason
      // TODO: Remove this kludge
      "-DAT_FDCWD=-100",

      "-D_LARGEFILE_SOURCE",
      "-D_FILE_OFFSET_BITS=64",
      "-DLIBURING_INTERNAL",
      "-ffreestanding",
      "-fno-builtin", 
      "-nodefaultlibs",
      "-nostdlib", 
      "-Wall",
      "-Wextra",  
      "-Wno-unused-parameter",
    }) catch unreachable;
   
    flags.appendSlice(switch (target.result.cpu.arch) {
      // https://github.com/axboe/liburing/blob/liburing-2.5/configure#L392
      .aarch64, .riscv32, .riscv64, .x86, .x86_64 => &.{ "-DCONFIG_NOLIBC" },
      else => &.{},
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

    lib.addCSourceFiles(.{
      .dependency = upstream,
      .files = lib_srcs,
      .flags = flags.items,
    });

    b.installArtifact(lib);
    lib.linkLibC();
}
