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
    var prng: std.Random.DefaultPrng = undefined;
};

fn swap(comptime T: type, a: *T, b: *T) void {
    const temp = a.*;
    a.* = b.*;
    b.* = temp;
}

fn rgbToFloat(c: u8) f32 {
    return @as(f32, @floatFromInt(c)) / 255.0;
}

fn randColor() ColorRGB {
    const rand = state.prng.random();

    var res = ColorRGB{};
    res.r = rand.intRangeAtMost(u8, 0, 255);
    res.g = rand.intRangeAtMost(u8, 0, 255);
    res.b = rand.intRangeAtMost(u8, 0, 255);

    return res;
}

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

const Quad = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

fn render_quad(quad: Quad, color: ColorRGB) void {
    const vertices = [_]f32{
        quad.x,          quad.y,          0.0, rgbToFloat(color.r), rgbToFloat(color.g), rgbToFloat(color.b), 1.0,
        quad.x + quad.w, quad.y,          0.0, rgbToFloat(color.r), rgbToFloat(color.g), rgbToFloat(color.b), 1.0,
        quad.x,          quad.y + quad.h, 0.0, rgbToFloat(color.r), rgbToFloat(color.g), rgbToFloat(color.b), 1.0,
        quad.x + quad.w, quad.y + quad.h, 0.0, rgbToFloat(color.r), rgbToFloat(color.g), rgbToFloat(color.b), 1.0,
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

const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,
};

const Piece = struct {
    pos: [4]Vec2,
    offset: Vec2,
    id: ShapesID,
};

const Shapes = enum {
    const I = Piece{ .pos = .{ .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 }, .{ .x = 3, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapesID.I };
    const O = Piece{ .pos = .{ .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapesID.O };
    const T = Piece{ .pos = .{ .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapesID.T };
    const S = Piece{ .pos = .{ .{ .x = 1, .y = 0 }, .{ .x = 2, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapesID.S };
    const Z = Piece{ .pos = .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapesID.Z };
    const J = Piece{ .pos = .{ .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapesID.J };
    const L = Piece{ .pos = .{ .{ .x = 2, .y = 1 }, .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapesID.L };
};

const ShapesID = enum(u8) {
    I = 1,
    O = 2,
    T = 3,
    S = 4,
    Z = 5,
    J = 6,
    L = 7,
};

const Rotation = enum(u8) {
    cw = 0,
    counter_cw = 1,
};

const game = struct {
    const cell_size: i32 = 16;
    const rows: i32 = 20;
    const cols: i32 = 10;
    const playfield_pos = Vec2{ .x = @as(f32, @floatFromInt(win_width - cols * cell_size)) / 2.0, .y = @as(f32, @floatFromInt(win_height - rows * cell_size)) / 2.0 };
    var current_piece: Piece = undefined;
    var piece_exists: bool = false;
    const input = struct {
        var up: bool = false;
        var down: bool = false;
        var left: bool = false;
        var right: bool = false;
        var rotate_left: bool = false;
        var rotate_right: bool = false;
    };
    var check_mat: [rows][cols]i32 = .{.{0} ** cols} ** rows;
};

fn init_game() void {
    game.piece_exists = false;
}

fn getRandomPiece() Piece {
    const rand = state.prng.random();
    const pieces = [_]Piece{ Shapes.I, Shapes.O, Shapes.T, Shapes.S, Shapes.Z, Shapes.J, Shapes.L };
    const choice = rand.intRangeLessThan(u8, 0, pieces.len);
    return pieces[choice];
}

fn floatToUsize(f: f32) usize {
    return @as(usize, @intFromFloat(f));
}

fn rotatePiece(rotation: Rotation) bool {
    var rows: usize = 0;
    var cols: usize = 0;
    if (@as(u8, @intFromEnum(game.current_piece.id)) > @as(u8, @intFromEnum(ShapesID.O))) {
        rows = 3;
        cols = 3;
    } else {
        rows = 4;
        cols = 4;
    }

    var mat: [][]i32 = state.allocator.alloc([]i32, rows) catch unreachable;
    for (mat) |*i| {
        i.* = state.allocator.alloc(i32, cols) catch unreachable;
    }
    defer {
        for (0..mat.len) |i| {
            state.allocator.free(mat[i]);
        }
        state.allocator.free(mat);
    }

    for (0..4) |i| {
        mat[floatToUsize(game.current_piece.pos[i].y)][floatToUsize(game.current_piece.pos[i].x)] = 1;
    }

    // reverse rows
    {
        var i: usize = 0;
        var j: usize = 0;
        while (i < rows) : (i += 1) {
            while (j < i) : (j += 1) {
                swap(i32, &mat[i][j], &mat[j][i]);
            }
        }
    }
    {
        var i: usize = 0;
        var j: usize = 0;
        while (i < rows - i) : (i += 1) {
            while (j < cols) : (j += 1) {
                if (rotation == Rotation.cw) {
                    swap(i32, &mat[i][j], &mat[j][(cols - 1) - i]);
                }
                if (rotation == Rotation.counter_cw) {
                    swap(i32, &mat[i][j], &mat[(rows - 1) - i][j]);
                }
            }
        }
    }

    // copies the rotated piece to a temp piece
    var temp_piece: Piece = undefined;
    var cnt: usize = 0;
    for (0..rows) |i| {
        for (0..cols) |j| {
            if (mat[i][j] == 1) {
                temp_piece.pos[cnt].x = @as(f32, @floatFromInt(j));
                temp_piece.pos[cnt].y = @as(f32, @floatFromInt(i));
                cnt += 1;
            }
        }
    }

    // checks if temp piece collides
    for (0..4) |i| {
        if (game.check_mat[floatToUsize(temp_piece.pos[i].y + game.current_piece.offset.y)][floatToUsize(temp_piece.pos[i].x + game.current_piece.offset.x)] > 0) {
            std.debug.print("asd\n", .{});
            return false;
        }
    }

    game.current_piece = temp_piece;
    std.debug.print("asd\n", .{});
    return true;
}

fn checkPieceCollision(dir: i32) void {
    var p = &game.current_piece;

    // checks out of bounds
    for (0..4) |i| {
        while (p.pos[i].x + p.offset.x < 0) {
            p.offset.x += 1;
        }
        while (p.pos[i].x + p.offset.x > game.cols - 1) {
            p.offset.x -= 1;
        }
    }

    // checks collision between pieces
    for (0..4) |i| {
        const x = @as(usize, @intFromFloat(p.pos[i].x + p.offset.x));
        const y = @as(usize, @intFromFloat(p.pos[i].y + p.offset.y));
        // check this because of the Shapes enum
        if (game.check_mat[y][x] > 0) {
            if (dir == 1) {
                p.offset.x += 1;
            }
            if (dir == 2) {
                p.offset.x -= 1;
            }
        }
    }
}

fn print_mat() void {
    for (game.check_mat) |i| {
        for (i) |j| {
            print("{d} ", .{j});
        }
        print("\n", .{});
    }
}

fn render_frame() void {
    if (!game.piece_exists) {
        game.current_piece = getRandomPiece();
        game.current_piece.offset.x = 3;
        game.current_piece.offset.y = 0;
        game.piece_exists = true;
    }

    //  std.debug.print("_z key pressed rotate left bool: {s}\n", .{if (game.input.rotate_left) "true" else "false"});
    if (game.input.left) {
        std.debug.print("check left\n", .{});
        game.current_piece.offset.x -= 1;
        checkPieceCollision(1);
    }
    if (game.input.right) {
        game.current_piece.offset.x += 1;
        checkPieceCollision(2);
    }

    if (game.input.rotate_right) {
        std.debug.print("rotate right\n", .{});
        _ = rotatePiece(Rotation.cw);
    }
    if (game.input.rotate_left) {
        std.debug.print("rotate left\n", .{});
        _ = rotatePiece(Rotation.counter_cw);
    }

    // renders piece
    const p = game.current_piece;
    for (0..4) |i| {
        const cell = Quad{ .x = game.playfield_pos.x + (p.pos[i].x + p.offset.x) * game.cell_size, .y = game.playfield_pos.y + (p.pos[i].y + p.offset.y) * game.cell_size, .w = game.cell_size, .h = game.cell_size };
        render_quad(cell, .{ .r = 255, .g = 0, .b = 0 });
    }

    // renders playfield
    render_quad(.{ .x = game.playfield_pos.x - game.cell_size, .y = game.playfield_pos.y, .w = game.cell_size, .h = game.cell_size * game.rows }, .{ .r = 255, .g = 255, .b = 255 });
    render_quad(.{ .x = game.playfield_pos.x + game.cell_size * game.cols, .y = game.playfield_pos.y, .w = game.cell_size, .h = game.cell_size * game.rows }, .{ .r = 255, .g = 255, .b = 255 });
    render_quad(.{ .x = game.playfield_pos.x - game.cell_size, .y = game.playfield_pos.y + game.rows * game.cell_size, .w = game.cell_size * (game.cols + 2), .h = game.cell_size }, .{ .r = 255, .g = 255, .b = 255 });

    game.input.up = false;
    game.input.down = false;
    game.input.left = false;
    game.input.right = false;
    game.input.rotate_left = false;
    game.input.rotate_right = false;
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
        .clear_value = .{ .r = rgbToFloat(40), .g = rgbToFloat(40), .b = rgbToFloat(40), .a = 1 },
    };

    state.prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });

    init_game();
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

    render_frame();

    if (state.quad_vertices.items.len > 0) {
        sg.updateBuffer(state.bind.vertex_buffers[0], sg.asRange(state.quad_vertices.items));
        sg.updateBuffer(state.bind.index_buffer, sg.asRange(state.quad_indices.items));
    }

    //  print("quads: {d}\nvertices: {d}\nindices: {d}\n\n", .{ state.quad_count, state.quad_vertices.items.len, state.quad_indices.items.len });

    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);
    sg.applyUniforms(shader_quad.UB_vs_params, sg.asRange(&state.vs_params));
    sg.draw(0, state.quad_count * 6, 1);
    sg.endPass();
    sg.commit();
}

export fn input_cb(e: ?*const sapp.Event) void {
    const event = e;
    if (event.?.type == .KEY_DOWN) {
        //      print("key down", .{});
        switch (event.?.key_code) {
            .UP => {
                game.input.up = true;
                print("up", .{});
            },
            .DOWN => {
                game.input.down = true;
                print("down", .{});
            },
            .LEFT => {
                game.input.left = true;
                print("left", .{});
            },
            .RIGHT => {
                game.input.right = true;
                print("right", .{});
            },
            .Z => {
                game.input.rotate_left = true;
                std.debug.print("z key pressed rotate left bool: {s}\n", .{if (game.input.rotate_left) "true" else "false"});
            },
            .X => {
                game.input.rotate_right = true;
                std.debug.print("x key pressed rotate right bool: {s}\n", .{if (game.input.rotate_right) "true" else "false"});
            },
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
        .event_cb = input_cb,
    });
}
