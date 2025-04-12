const std = @import("std");
const Build = std.Build;
const sokol = @import("sokol");

const Options = struct {
    mod: *Build.Module,
    dep_sokol: *Build.Dependency,
};

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const mod_zigtris = b.createModule(.{
        .root_source_file = b.path("src/zigtris.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
        },
        .link_libc = true,
    });

    mod_zigtris.addCSourceFile(.{
        .file = b.path("src/stb_image.c"), 
        .flags = &.{"-fno-sanitize=undefined"},
    });
    mod_zigtris.addIncludePath(b.path("src"));

    // special case handling for native vs web build
    const opts = Options{ .mod = mod_zigtris, .dep_sokol = dep_sokol };
    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, opts);
    } else {
        try buildNative(b, opts);
    }
}

// this is the regular build for all native platforms, nothing surprising here
fn buildNative(b: *Build, opts: Options) !void {
    const exe = b.addExecutable(.{
        .name = "zigtris",
        .root_module = opts.mod,
    });
    const shader_paths = [_][]const u8{"src/tex_quad.glsl", "src/quad.glsl"};
    for (shader_paths) |shader_path| {
        const shd = try buildShader(b, opts.dep_sokol, shader_path);
        exe.step.dependOn(&shd.step);
    }

    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    b.step("run", "Run zigtris").dependOn(&run.step);
}

// for web builds, the Zig code needs to be built into a library and linked with the Emscripten linker
fn buildWeb(b: *Build, opts: Options) !void {
    const lib = b.addStaticLibrary(.{
        .name = "zigtris",
        .root_module = opts.mod,
        .link_libc = true,
    });


    const shader_paths = [_][]const u8{"src/tex_quad.glsl", "src/quad.glsl"};
    for (shader_paths) |shader_path| {
        const shd = try buildShader(b, opts.dep_sokol, shader_path);
        lib.step.dependOn(&shd.step);
    }

    // create a build step which invokes the Emscripten linker
    const emsdk = opts.dep_sokol.builder.dependency("emsdk", .{});
    lib.addSystemIncludePath(emsdk.path(b.pathJoin(&.{"upstream", "emscripten", "cache", "sysroot", "include"})));
    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = lib,
        .target = opts.mod.resolved_target.?,
        .optimize = opts.mod.optimize.?,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = opts.dep_sokol.path("src/sokol/web/shell.html"),
        .use_offset_converter = true,
    });


    // attach Emscripten linker output to default install step
    b.getInstallStep().dependOn(&link_step.step);
    // ...and a special run step to start the web build output via 'emrun'
    const run = sokol.emRunStep(b, .{ .name = "zigtris", .emsdk = emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run zigtris").dependOn(&run.step);
}

// compile shader via sokol-shdc
fn buildShader(b: *Build, dep_sokol: *Build.Dependency, shader_path: []const u8) !*Build.Step.Run {
    const result: *Build.Step.Run = try sokol.shdc.compile(b, .{
        .dep_shdc = dep_sokol.builder.dependency("shdc", .{}),
        .input = b.path(shader_path),
        .output = b.path(b.fmt("{s}.zig", .{shader_path})),
        .slang = .{
            .glsl410 = true,
            .glsl300es = true,
            .hlsl4 = true,
            .metal_macos = true,
            .wgsl = true,
        },
    });

    return result;
}
