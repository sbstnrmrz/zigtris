const std = @import("std");
const Build = std.Build;
const sokol = @import("sokol");

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const dep_zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });

    const mod_zigtris = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "zstbi", .module = dep_zstbi.module("root") },
        },
    });

    // special case handling for native vs web build
    if (target.result.isWasm()) {
        try buildWeb(b, mod_zigtris, dep_sokol);
    } else {
        try buildNative(b, mod_zigtris);
    }
}

// this is the regular build for all native platforms, nothing surprising here
fn buildNative(b: *Build, mod: *Build.Module) !void {
    const exe = b.addExecutable(.{
        .name = "zigtris",
        .root_module = mod,
    });
    const zstbi = b.dependency("zstbi", .{});
    exe.linkLibrary(zstbi.artifact("zstbi"));
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    b.step("run", "Run zigtris").dependOn(&run.step);
}

// for web builds, the Zig code needs to be built into a library and linked with the Emscripten linker
fn buildWeb(b: *Build, mod: *Build.Module, dep_sokol: *Build.Dependency) !void {
    const lib = b.addStaticLibrary(.{
        .name = "zigtris",
        .root_module = mod,
    });

    // create a build step which invokes the Emscripten linker
    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = lib,
        .target = mod.resolved_target.?,
        .optimize = mod.optimize.?,
        .emsdk = emsdk,
        .use_offset_converter = true,
        .extra_args = &[_][]const u8{
            "-sASSERTIONS",
            "-g",
        },
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html"),
    });
    // ...and a special run step to start the web build output via 'emrun'
    const run = sokol.emRunStep(b, .{ .name = "zigtris", .emsdk = emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run zigtris").dependOn(&run.step);
}
