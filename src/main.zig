// TODO: implement a better solution to the quad arrays

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

inline fn floatToUsize(f: f32) usize {
    return @as(usize, @intFromFloat(f));
}

inline fn i32ToUsize(i: i32) usize {
    return @as(usize, @intCast(i));
}

inline fn usizeToI32(u: usize) i32 {
    return @as(i32, @intCast(u));
}

inline fn i32ToFloat(i: i32) f32 {
    return @as(f32, @floatFromInt(i));
}

fn swap(comptime T: type, a: *T, b: *T) void {
    const temp = a.*;
    a.* = b.*;
    b.* = temp;
}

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
    var vertices: [1500]Vertex = .{0} ** 1500;
    var vertex_count: u32 = 0;
    var quad_vertices = ArrayList(f32).init(allocator);
    var quad_indices = ArrayList(u16).init(allocator);
    var _quad_vertices: [10000]f32 = .{0} ** 10000;
    var _quad_indices: [2048]i16 = .{0} ** 2048;
    var quad_count: u32 = 0;

    var index_count: u32 = 0;
    var prng: std.Random.DefaultPrng = undefined;
};

const ColorRGB = struct {
    r: u8,
    g: u8,
    b: u8,
};

const Vertex = struct {
    x: f32,
    y: f32,
};

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

fn pushIndex(index: i16) void {
    state._quad_indices[@as(usize, @intCast(state.index_count))] = index;
    state.index_count += 1;
}

fn pushVertex(vertex: Vertex) void {
    state.vertices[state.vertex_count] = vertex;
    state.vertex_count += 1;
}

fn pushQuad(quad: Quad) void {
    pushVertex(Vertex{ .x = quad.x, .y = quad.y });
    pushVertex(Vertex{ .x = quad.x + quad.w, .y = quad.y });
    pushVertex(Vertex{ .x = quad.x, .y = quad.y + quad.h });
    pushVertex(Vertex{ .x = quad.x + quad.w, .y = quad.y + quad.h });
}

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
        state._quad_vertices[state.vertex_count] = v;
        state.vertex_count += 1;
    }

    pushIndex((@as(i16, @intCast(state.quad_count)) * 4) + 0);
    pushIndex((@as(i16, @intCast(state.quad_count)) * 4) + 1);
    pushIndex((@as(i16, @intCast(state.quad_count)) * 4) + 2);
    pushIndex((@as(i16, @intCast(state.quad_count)) * 4) + 2);
    pushIndex((@as(i16, @intCast(state.quad_count)) * 4) + 1);
    pushIndex((@as(i16, @intCast(state.quad_count)) * 4) + 3);

    state.quad_count += 1;
}

const Vec2 = struct {
    x: i32 = 0,
    y: i32 = 0,
};

const Piece = struct {
    pos: [4]Vec2,
    offset: Vec2,
    id: ShapeID,
    color: ColorRGB,
};

const Colors = enum {
    const red = ColorRGB{ .r = 187, .g = 54, .b = 42 };
    const green = ColorRGB{ .r = 152, .g = 151, .b = 54 };
    const yellow = ColorRGB{ .r = 206, .g = 156, .b = 62 };
    const blue = ColorRGB{ .r = 85, .g = 131, .b = 135 };
    const pink = ColorRGB{ .r = 166, .g = 102, .b = 133 };
    const aquamarine = ColorRGB{ .r = 116, .g = 156, .b = 111 };
    const orange = ColorRGB{ .r = 214, .g = 93, .b = 14 };
};

const Shapes = enum {
    const I = Piece{ .pos = .{ .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 }, .{ .x = 3, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapeID.I, .color = Colors.red };
    const O = Piece{ .pos = .{ .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapeID.O, .color = Colors.green };
    const T = Piece{ .pos = .{ .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapeID.T, .color = Colors.yellow };
    const S = Piece{ .pos = .{ .{ .x = 1, .y = 0 }, .{ .x = 2, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapeID.S, .color = Colors.blue };
    const Z = Piece{ .pos = .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapeID.Z, .color = Colors.pink };
    const J = Piece{ .pos = .{ .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapeID.J, .color = Colors.aquamarine };
    const L = Piece{ .pos = .{ .{ .x = 2, .y = 1 }, .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .offset = .{ .x = 0, .y = 0 }, .id = ShapeID.L, .color = Colors.orange };
};

const ShapeID = enum(u8) {
    NONE = 0,
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

const Queue = struct {};

const game = struct {
    const cell_size: i32 = 16;
    const rows: i32 = 20;
    const cols: i32 = 10;
    const playfield_pos = Vec2{ .x = (win_width - cols * cell_size) / 2, .y = (win_height - rows * cell_size) / 2 };
    const piece_bag_preview = Vec2{ .x = playfield_pos.x + cols * cell_size, .y = playfield_pos.y };
    var piece_bag: [14]Piece = undefined;
    var bag_piece_count: u8 = 0;
    var current_piece: Piece = undefined;
    var piece_exists: bool = false;
    const input = struct {
        var up: bool = false;
        var down: bool = false;
        var left: bool = false;
        var right: bool = false;
        var rotate_cw: bool = false;
        var rotate_counter_cw: bool = false;
        var space: bool = false;
    };
    var check_mat: [rows][cols]i32 = .{.{0} ** cols} ** rows;
    var frames: u64 = 0;
    var lines_cleared: i32 = 0;
};

fn gameInit() void {
    game.piece_exists = false;
    refillBag();
}

fn getRandomPiece() Piece {
    const rand = state.prng.random();
    const pieces = [_]Piece{ Shapes.I, Shapes.O, Shapes.T, Shapes.S, Shapes.Z, Shapes.J, Shapes.L };
    const choice = rand.intRangeLessThan(u8, 0, pieces.len);
    return pieces[choice];
}

fn getPieceFromEnum(id: ShapeID) Piece {
    const pieces = [_]Piece{ Shapes.I, Shapes.O, Shapes.T, Shapes.S, Shapes.Z, Shapes.J, Shapes.L };
    return pieces[@as(usize, @intFromEnum(id)) - 1];
}

fn rotatePiece(rotation: Rotation) bool {
    const rows: usize = if (@as(u8, @intFromEnum(game.current_piece.id)) > @as(u8, @intFromEnum(ShapeID.O))) 3 else 4;
    const cols: usize = rows;

    var mat: [4][4]i32 = .{.{0} ** 4} ** 4;
    //  @memset(&mat, 0);

    for (0..4) |i| {
        mat[i32ToUsize(game.current_piece.pos[i].y)][i32ToUsize(game.current_piece.pos[i].x)] = 1;
    }

    // transpose matrix
    {
        var i: usize = 0;
        var j: usize = 0;
        while (i < rows) : (i += 1) {
            j = 0;
            while (j < i) : (j += 1) {
                swap(i32, &mat[i][j], &mat[j][i]);
            }
        }
    }

    // reverse rows if rotation clockwise, cols if anti clockwise
    {
        var i: usize = 0;
        var j: usize = 0;
        while (i < rows - i) : (i += 1) {
            j = 0;
            while (j < cols) : (j += 1) {
                if (rotation == Rotation.cw) {
                    swap(i32, &mat[j][i], &mat[j][(cols - 1) - i]);
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
                temp_piece.pos[cnt].x = @as(i32, @intCast(j));
                temp_piece.pos[cnt].y = @as(i32, @intCast(i));
                cnt += 1;
            }
        }
    }

    // checks if temp piece collides
    for (0..4) |i| {
        if (temp_piece.pos[i].x + game.current_piece.offset.x < 0 or temp_piece.pos[i].x + game.current_piece.offset.x > game.cols - 1) {
            continue;
        }
        if (game.check_mat[i32ToUsize(temp_piece.pos[i].y + game.current_piece.offset.y)][i32ToUsize(temp_piece.pos[i].x + game.current_piece.offset.x)] > 0) {
            return false;
        }
    }

    for (0..4) |i| {
        game.current_piece.pos[i].x = temp_piece.pos[i].x;
        game.current_piece.pos[i].y = temp_piece.pos[i].y;
    }
    return true;
}

// this should be called only when a piece is placed
fn clearLines() u8 {
    var line: u8 = 0;
    var lines_cleared: u8 = 0;
    var i: i32 = game.rows - 1;
    var j: usize = 0;
    while (i >= 0) : (i -= 1) {
        j = 0;
        while (j < game.cols) : (j += 1) {
            if (game.check_mat[i32ToUsize(i)][j] < 1) {
                line = 0;
                break;
            } else {
                line += 1;
            }
        }
        if (line >= 10) {
            var k: usize = 0;
            while (k < game.cols) : (k += 1) {
                game.check_mat[i32ToUsize(i)][k] = 0;
            }

            var l: usize = i32ToUsize(i);
            while (l > 0) : (l -= 1) {
                k = 0;
                while (k < game.cols) : (k += 1) {
                    game.check_mat[l][k] = game.check_mat[l - 1][k];
                }
            }
            lines_cleared += 1;
        }
    }

    return lines_cleared;
}

fn checkPlacePiece() bool {
    const p = game.current_piece;
    for (0..4) |i| {
        if (p.pos[i].y + p.offset.y + 1 < game.rows) {
            if (game.check_mat[i32ToUsize((p.pos[i].y + p.offset.y) + 1)][i32ToUsize(p.pos[i].x + p.offset.x)] > 0) {
                return true;
            }
        }

        if (p.pos[i].y + p.offset.y >= game.rows - 1) {
            return true;
        }
    }
    return false;
}

// maybe rename it to lock piece?
fn placePiece() void {
    const p = game.current_piece;
    for (0..4) |i| {
        game.check_mat[i32ToUsize(p.pos[i].y + p.offset.y)][i32ToUsize(p.pos[i].x + p.offset.x)] = @as(i32, @intFromEnum(p.id));
    }
    game.piece_exists = false;
}

fn hardDrop() void {
    const p = game.current_piece;
    var offset = p.offset.y;
    var check: i8 = 0;
    while (true) {
        for (0..4) |i| {
            if (p.pos[i].y + offset < game.rows - 1 and game.check_mat[i32ToUsize(p.pos[i].y + offset + 1)][i32ToUsize(p.pos[i].x + p.offset.x)] < 1) {
                check += 1;
            } else {
                check = 0;
            }
        }
        if (check == 4) {
            check = 0;
            offset += 1;
        } else {
            break;
        }
    }
    game.current_piece.offset.y = offset;
    placePiece();
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
        const x = @as(usize, @intCast(p.pos[i].x + p.offset.x));
        const y = @as(usize, @intCast(p.pos[i].y + p.offset.y));
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

fn getGhostPieceOffset() i32 {
    const p = game.current_piece;
    var offset = p.offset.y;
    var check: i8 = 0;
    while (true) {
        for (0..4) |i| {
            if (p.pos[i].y + offset < game.rows - 1 and game.check_mat[i32ToUsize(p.pos[i].y + offset + 1)][i32ToUsize(p.pos[i].x + p.offset.x)] < 1) {
                check += 1;
            } else {
                check = 0;
            }
        }
        if (check == 4) {
            check = 0;
            offset += 1;
        } else {
            break;
        }
    }

    return offset;
}

fn refillBag() void {
    while (game.bag_piece_count < game.piece_bag.len) {
        var repeat = false;
        const randomPiece = getRandomPiece();
        // checks if piece already exist in the bag
        // maybe convert this to a function
        // check if doesnt matter if piece count < or <=
        for (game.piece_bag[if (game.bag_piece_count < 7) 0 else 7..game.bag_piece_count]) |piece| {
            if (randomPiece.id == piece.id) {
                repeat = true;
                break;
            }
        }
        if (repeat) continue;
        game.piece_bag[game.bag_piece_count] = randomPiece;
        game.bag_piece_count += 1;
    }
}

fn getNextBagPiece() Piece {
    const res = game.piece_bag[0];
    for (0..game.bag_piece_count - 1) |i| {
        game.piece_bag[i] = game.piece_bag[i + 1];
    }
    game.piece_bag[game.bag_piece_count - 1].id = .NONE;
    game.bag_piece_count -= 1;

    return res;
}

fn printMat(mat: [][]i32) void {
    for (0..mat.len) |i| {
        for (0..mat[i].len) |j| {
            std.debug.print("{d} ", .{mat[i][j]});
        }
        std.debug.print("\n", .{});
    }
}

fn printQuadInfo() void {
    std.log.debug("quad count: {d}", .{state.quad_count});
    std.log.debug("vertex count: {d}", .{state.vertex_count});
    std.log.debug("index count: {d}", .{state.index_count});
    std.log.debug("vertex buffer size: {d}", .{state.vertex_count * @sizeOf(f32)});
    std.log.debug("index buffer size: {d}\n\n", .{state.index_count * @sizeOf(f32)});

    //  print("quads: {d}\nvertices: {d}\nindices: {d}\n\n", .{ state.quad_count, state.quad_vertices.items.len, state.quad_indices.items.len });

}

fn printBagInfo() void {
    std.log.debug("bag", .{});
    for (0..game.piece_bag.len) |i| {
        std.log.debug("{d}: {d}", .{ i, @as(i32, @intFromEnum(game.piece_bag[i].id)) });
    }
    std.debug.print("\n", .{});
}

fn render_frame() void {
    if (game.input.left) {
        std.debug.print("check left\n", .{});
        game.current_piece.offset.x -= 1;
        checkPieceCollision(1);
    }
    if (game.input.right) {
        game.current_piece.offset.x += 1;
        checkPieceCollision(2);
    }

    if (game.input.rotate_cw) {
        std.debug.print("rotate right\n", .{});
        _ = rotatePiece(Rotation.cw);
        checkPieceCollision(1);
    }
    if (game.input.rotate_counter_cw) {
        std.debug.print("rotate left\n", .{});
        _ = rotatePiece(Rotation.counter_cw);
        checkPieceCollision(2);
    }
    if (game.input.space) {
        hardDrop();
    }

    if (!game.piece_exists) {
        if (game.bag_piece_count <= 7) {
            refillBag();
        }
        game.current_piece = getNextBagPiece();
        game.current_piece.offset.x = 3;
        game.current_piece.offset.y = 0;
        game.piece_exists = true;
    }

    if (game.frames % 12 == 0) {
        if (checkPlacePiece()) {
            placePiece();
        } else {
            game.current_piece.offset.y += 1;
        }
    }
    game.lines_cleared += clearLines();

    const p = game.current_piece;
    for (0..4) |i| {
        //renders ghost piece
        const ghost_cell = Quad{ .x = i32ToFloat(game.playfield_pos.x + (p.pos[i].x + p.offset.x) * game.cell_size), .y = i32ToFloat(game.playfield_pos.y + (p.pos[i].y + getGhostPieceOffset()) * game.cell_size), .w = game.cell_size, .h = game.cell_size };
        render_quad(ghost_cell, ColorRGB{ .r = p.color.r / 2, .g = p.color.g / 2, .b = p.color.b / 2 });
        // renders piece
        const cell = Quad{ .x = i32ToFloat(game.playfield_pos.x + (p.pos[i].x + p.offset.x) * game.cell_size), .y = i32ToFloat(game.playfield_pos.y + (p.pos[i].y + p.offset.y) * game.cell_size), .w = game.cell_size, .h = game.cell_size };

        render_quad(cell, p.color);
    }

    // renders playfield
    render_quad(.{ .x = i32ToFloat(game.playfield_pos.x - game.cell_size), .y = i32ToFloat(game.playfield_pos.y), .w = game.cell_size, .h = game.cell_size * game.rows }, .{ .r = 255, .g = 255, .b = 255 });
    render_quad(.{ .x = i32ToFloat(game.playfield_pos.x + game.cell_size * game.cols), .y = i32ToFloat(game.playfield_pos.y), .w = game.cell_size, .h = game.cell_size * game.rows }, .{ .r = 255, .g = 255, .b = 255 });
    render_quad(.{ .x = i32ToFloat(game.playfield_pos.x - game.cell_size), .y = i32ToFloat(game.playfield_pos.y + game.rows * game.cell_size), .w = game.cell_size * (game.cols + 2), .h = game.cell_size }, .{ .r = 255, .g = 255, .b = 255 });

    // renders pieces in the matrix
    for (0..game.check_mat.len) |i| {
        for (0..game.check_mat[i].len) |j| {
            if (game.check_mat[i][j] > 0) {
                const cell = Quad{ .x = i32ToFloat(game.playfield_pos.x + usizeToI32(j) * game.cell_size), .y = i32ToFloat(game.playfield_pos.y + usizeToI32(i) * game.cell_size), .w = game.cell_size, .h = game.cell_size };
                // check this ajsdasdj
                render_quad(cell, getPieceFromEnum(@as(ShapeID, @enumFromInt(game.check_mat[i][j]))).color);
            }
        }
    }

    for (0..4) |i| {
        for (0..4) |j| {
            const cell = Quad{
                .x = i32ToFloat(game.piece_bag[i].pos[j].x * game.cell_size + game.piece_bag_preview.x + (game.cell_size * 2)),
                .y = i32ToFloat(game.piece_bag[i].pos[j].y * game.cell_size + game.piece_bag_preview.y + (usizeToI32(i) * 5 * game.cell_size)),
                .w = game.cell_size,
                .h = game.cell_size,
            };
            render_quad(cell, game.piece_bag[i].color);
        }
    }

    game.input.up = false;
    game.input.down = false;
    game.input.left = false;
    game.input.right = false;
    game.input.rotate_counter_cw = false;
    game.input.rotate_cw = false;
    game.input.space = false;

    game.frames += 1;
}

export fn init() void {
    stime.setup();
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // a vertex buffer
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .size = 20000,
        .usage = .DYNAMIC,
        .type = .VERTEXBUFFER,
    });

    state.bind.index_buffer = sg.makeBuffer(.{
        .size = 2048,
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

    gameInit();
}

export fn frame() void {
    state.quad_count = 0;
    state.vertex_count = 0;
    state.index_count = 0;
    state.bind.vertex_buffer_offsets[0] = 0;
    state.bind.index_buffer_offset = 0;

    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });

    render_frame();

    const vertices = state._quad_vertices[0..state.vertex_count];
    const indices = state._quad_indices[0..state.index_count];
    if (state.quad_count > 0) {
        sg.updateBuffer(state.bind.vertex_buffers[0], sg.asRange(vertices));
        sg.updateBuffer(state.bind.index_buffer, sg.asRange(indices));
    }

    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);
    sg.applyUniforms(shader_quad.UB_vs_params, sg.asRange(&state.vs_params));
    sg.draw(0, state.quad_count * 6, 1);
    sg.endPass();
    sg.commit();

    printQuadInfo();
    printBagInfo();
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
                game.input.rotate_counter_cw = true;
                std.debug.print("z key pressed rotate left bool: {s}\n", .{if (game.input.rotate_counter_cw) "true" else "false"});
            },
            .X => {
                game.input.rotate_cw = true;
                std.debug.print("x key pressed rotate right bool: {s}\n", .{if (game.input.rotate_cw) "true" else "false"});
            },
            .SPACE => {
                game.input.space = true;
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
