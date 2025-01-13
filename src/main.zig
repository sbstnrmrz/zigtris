//------------------------------------------------------------------------------
//  quad.zig
//
//  Simple 2D rendering with vertex- and index-buffer.
//------------------------------------------------------------------------------
const std = @import("std");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const m = @import("math.zig");
const shader_quad = @import("shaders/quad.glsl.zig");
const Vec4 = m.Vec4;

const print = std.debug.print;

const win_width = 800;
const win_height = 600;
const ortho_proj_mat = m.Mat4.ortho(0, win_width, win_height, 0, -1.0, 1.0);

const state = struct {
    var bind: sg.Bindings = .{};
    var pip: sg.Pipeline = .{};
    var pass_action: sg.PassAction = .{};
    const vs_params: shader_quad.VsParams = .{ .p = ortho_proj_mat };
};

const ColorRGB = struct {
    r: u8,
    g: u8,
    b: u8,

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

fn mat4ToArr(mat: m.Mat4) [16]f32 {
    var res: [16]f32 = undefined;

    var i: usize = 0;
    for (mat.m) |row| {
        for (row) |col| {
            res[i] = col;
            i += 1;
        }
    }

    return res;
}

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // a vertex buffer
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{ .usage = .DYNAMIC, .size = 1000, .type = .VERTEXBUFFER });

    // an index buffer
    state.bind.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&[_]u16{ 0, 1, 2, 2, 1, 3 }),
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

    // clear to black
    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };
}

export fn frame() void {
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });

    const width = 32.0;
    const height = 32.0;
    const rect_x = 100.0;
    const rect_y = 100.0;
    var color = ColorRGB{ .r = 255, .g = 0, .b = 0 };

    sg.updateBuffer(state.bind.vertex_buffers[0], sg.asRange(&[_]f32{
        rect_x,         rect_y,          0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
        rect_x + width, rect_y,          0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
        rect_x,         rect_y + height, 0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
        rect_x + width, rect_y + height, 0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
    }));

    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);
    sg.applyUniforms(shader_quad.UB_vs_params, sg.asRange(&state.vs_params));

    sg.draw(0, 6, 1);
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
}

fn render_quad(x: f32, y: f32, width: f32, height: f32, color: ColorRGB) void {
    const quad = [_]f32{
        x,         y,          0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
        x + width, y,          0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
        x,         y + height, 0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
        x + width, y + height, 0.0, color.redToFloat(), color.greenToFloat(), color.blueToFloat(), 1.0,
    };

    _ = quad;

    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shader_quad.quadShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[shader_quad.ATTR_quad_pos].format = .FLOAT3;
            l.attrs[shader_quad.ATTR_quad_color].format = .FLOAT4;
            break :init l;
        },
        .index_type = .UINT16,
    });
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .icon = .{ .sokol_default = true },
        .window_title = "zigtris",
        .logger = .{ .func = slog.func },
        .event_cb = input,
    });
}
