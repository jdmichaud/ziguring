const std = @import("std");

fn generate_header(b: *std.Build, dependency: *std.Build.Dependency,
  path: []const u8, content: []const u8) void {
  var file = std.fs.createFileAbsolute(dependency.path(path).getPath(b), .{
    .truncate = true,
  }) catch @panic("Couldn't write to file");
  _ = file.write(content) catch @panic("Couldn't write to file");
}

const compat_h_content =
  \\/* SPDX-License-Identifier: MIT */
  \\#ifndef LIBURING_COMPAT_H
  \\#define LIBURING_COMPAT_H
  \\
  \\#include <linux/time_types.h>
  \\/* <linux/time_types.h> is included above and not needed again */
  \\#define UAPI_LINUX_IO_URING_H_SKIP_LINUX_TIME_TYPES_H 1
  \\
  \\#include <linux/openat2.h>
  \\
  \\#endif
  ;
const io_uring_version_h_content =
  \\ /* SPDX-License-Identifier: MIT */
  \\ #ifndef LIBURING_VERSION_H
  \\ #define LIBURING_VERSION_H
  \\ 
  \\ #define IO_URING_VERSION_MAJOR 2
  \\ #define IO_URING_VERSION_MINOR 6
  \\ 
  \\ #endif
  ;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("liburing", .{});

    const lib = b.addStaticLibrary(.{
        .name = "uring",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(upstream.path("src/include"));

    // TODO: Auto generate this file
    // lib.addIncludePath(upstream.path("config-host.h"));

    const lib_srcs = &.{
      "src/setup.c",
      "src/queue.c",
      "src/register.c",
      "src/syscall.c",
      "src/version.c",
      "src/nolibc.c",
    };

    var flags = std.ArrayList([]const u8).init(b.allocator);

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

    generate_header(b, upstream, "src/include/liburing/compat.h", compat_h_content);
    generate_header(b, upstream, "src/include/liburing/io_uring_version.h", io_uring_version_h_content);

    lib.addCSourceFiles(.{
      .dependency = upstream,
      .files = lib_srcs,
      .flags = flags.items,
    });

    b.installArtifact(lib);
    lib.installHeader(upstream.path("src/include/liburing.h").getPath(b), "liburing.h");
    lib.installHeader(upstream.path("src/include/liburing/barrier.h").getPath(b), "liburing/barrier.h");
    lib.installHeader(upstream.path("src/include/liburing/compat.h").getPath(b), "liburing/compat.h");
    lib.installHeader(upstream.path("src/include/liburing/io_uring.h").getPath(b), "liburing/io_uring.h");
    lib.installHeader(upstream.path("src/include/liburing/io_uring_version.h").getPath(b), "liburing/io_uring_version.h");
    lib.linkLibC();
}
