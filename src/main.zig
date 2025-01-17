const std = @import("std");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const stime = sokol.time;
const m = @import("math.zig");
const shader_quad = @import("shaders/quad.glsl.zig");
const Vec4 = m.Vec4;
const ArrayList = std.ArrayList;

const print = std.debug.print;

const win_width = 800;
const win_height = 600;
const ortho_proj_mat = m.Mat4.ortho(0, win_width, win_height, 0, -1.0, 1.0);

const state = struct {
    var bind: sg.Bindings = .{};
    var pip: sg.Pipeline = .{};
    var pass_action: sg.PassAction = .{};
    const vs_params: shader_quad.VsParams = .{ .p = ortho_proj_mat };
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var quad_vertices = ArrayList(f32).init(allocator);
    var quad_indices = ArrayList(u16).init(allocator);
    var quad_count: u32 = 0;
};

fn RGBToFloat(c: u8) f32 {
    return @as(f32, @floatFromInt(c)) / 255.0;
}

fn randColor() ColorRGB {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });
    const rand = prng.random();

    var res = ColorRGB{};
    res.r = rand.intRangeAtMost(u8, 0, 255);
    res.g = rand.intRangeAtMost(u8, 0, 255);
    res.b = rand.intRangeAtMost(u8, 0, 255);

    return res;
}

const ColorRGB = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    fn redToFloat(self: *ColorRGB) f32 {
        return @as(f32, @floatFromInt(self.r)) / 255.0;
    }
    fn greenToFloat(self: *ColorRGB) f32 {
        return @as(f32, @floatFromInt(self.g)) / 255.0;
    }
    fn blueToFloat(self: *ColorRGB) f32 {
        return @as(f32, @floatFromInt(self.b)) / 255.0;
    }
};

const Quad = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

fn render_quad(quad: Quad, color: ColorRGB) void {
    const vertices = [_]f32{
        quad.x,          quad.y,          0.0, RGBToFloat(color.r), RGBToFloat(color.g), RGBToFloat(color.b), 1.0,
        quad.x + quad.w, quad.y,          0.0, RGBToFloat(color.r), RGBToFloat(color.g), RGBToFloat(color.b), 1.0,
        quad.x,          quad.y + quad.h, 0.0, RGBToFloat(color.r), RGBToFloat(color.g), RGBToFloat(color.b), 1.0,
        quad.x + quad.h, quad.y + quad.h, 0.0, RGBToFloat(color.r), RGBToFloat(color.g), RGBToFloat(color.b), 1.0,
    };

    for (vertices) |v| {
        state.quad_vertices.append(v) catch unreachable;
    }

    state.quad_indices.append((@as(u16, @intCast(state.quad_count)) * 4) + 0) catch unreachable;
    state.quad_indices.append((@as(u16, @intCast(state.quad_count)) * 4) + 1) catch unreachable;
    state.quad_indices.append((@as(u16, @intCast(state.quad_count)) * 4) + 2) catch unreachable;
    state.quad_indices.append((@as(u16, @intCast(state.quad_count)) * 4) + 2) catch unreachable;
    state.quad_indices.append((@as(u16, @intCast(state.quad_count)) * 4) + 1) catch unreachable;
    state.quad_indices.append((@as(u16, @intCast(state.quad_count)) * 4) + 3) catch unreachable;

    state.quad_count += 1;
}

export fn init() void {
    stime.setup();
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // a vertex buffer
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{ .size = 500000, .usage = .DYNAMIC, .type = .VERTEXBUFFER });

    state.bind.index_buffer = sg.makeBuffer(.{
        .size = 8192,
        .type = .INDEXBUFFER,
        .usage = .DYNAMIC,
    });

    // a shader and pipeline state object
    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shader_quad.quadShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[shader_quad.ATTR_quad_pos].format = .FLOAT3;
            l.attrs[shader_quad.ATTR_quad_in_color].format = .FLOAT4;
            break :init l;
        },
        .index_type = .UINT16,
    });

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };
}

export fn frame() void {
    if (state.quad_vertices.items.len > 0) {
        state.quad_vertices.clearRetainingCapacity();
        state.quad_indices.clearRetainingCapacity();
        state.quad_count = 0;
        state.bind.vertex_buffer_offsets[0] = 0;
        state.bind.index_buffer_offset = 0;
    }

    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });

    for (0..25) |i| {
        for (0..25) |j| {
            const _i = @as(f32, @floatFromInt(i));
            const _j = @as(f32, @floatFromInt(j));
            render_quad(.{ .x = 32 * _j, .y = 32 * _i, .w = 32, .h = 32 }, randColor());
        }
    }

    if (state.quad_vertices.items.len > 0) {
        sg.updateBuffer(state.bind.vertex_buffers[0], sg.asRange(state.quad_vertices.items));
        sg.updateBuffer(state.bind.index_buffer, sg.asRange(state.quad_indices.items));
    }

    print("quads: {d}\nvertices: {d}\nindices: {d}\n\n", .{ state.quad_count, state.quad_vertices.items.len, state.quad_indices.items.len });

    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);
    sg.applyUniforms(shader_quad.UB_vs_params, sg.asRange(&state.vs_params));
    sg.draw(0, state.quad_count * 6, 1);
    sg.endPass();
    sg.commit();
}

export fn input(e: ?*const sapp.Event) void {
    const event = e;
    if (event.?.type == .KEY_DOWN) {
        //      print("key down", .{});
        switch (event.?.key_code) {
            .UP => print("up", .{}),
            else => {},
        }
    } else if (event.?.type == .KEY_UP) {
        //      print("key up", .{});
    }
}

export fn cleanup() void {
    sg.shutdown();
    state.quad_vertices.deinit();
    state.quad_indices.deinit();
    _ = state.gpa.deinit();
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = win_width,
        .height = win_height,
        .icon = .{ .sokol_default = true },
        .window_title = "zigtris",
        .logger = .{ .func = slog.func },
        .event_cb = input,
    });
}
