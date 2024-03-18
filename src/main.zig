const std = @import("std");
const log = std.log.scoped(.main);
const core = @import("mach").core;
const gpu = core.gpu;
const zigimg = @import("zigimg");
const GameState = @import("game_state.zig").GameState;
const Components =  @import("ecs/components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;

pub const App = @This();

const JSONSprite = struct {
    pos: []f32,
    size: []f32,
    world_pos: []f32,
};
const SpriteSheet = struct {
    width: f32,
    height: f32,
};
const JSONData = struct {
    sheet: SpriteSheet,
    sprites: []JSONSprite,
};
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

timer: core.Timer,
title_timer: core.Timer,
pipeline: *gpu.RenderPipeline,

pub var state: *GameState = undefined;

pub fn init(app: *App) !void {
    try core.init(.{});
    core.setFrameRateLimit(60);
    const allocator = gpa.allocator();

    const base_folder = try std.fs.realpathAlloc(allocator, "../../");
    defer allocator.free(base_folder);
    std.debug.print("base folder : {s}\n", .{base_folder});

    state = try GameState.init(allocator);
    // std.debug.print("texture keys : {any}", .{state.asset_manager.texture_map.keys()});
    
    var view = state.world.view(.{ Position, CardSuit }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.getConst(Position, entity);
        std.debug.print("Position : {any}\n", .{position});
    }

    const cards_json_path = try std.fs.realpathAlloc(allocator, "../../assets/cards_data.json");
    defer allocator.free(cards_json_path);
    const sprites_file = try std.fs.cwd().openFile(cards_json_path, . { .mode = .read_only});
    defer sprites_file.close();
    const file_size = (try sprites_file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    try sprites_file.reader().readNoEof(buffer);
    const root = try std.json.parseFromSlice(JSONData, allocator, buffer, .{});
    defer root.deinit();

    const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    // Fragment state
    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });
    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_main",
        },
    };
    const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

    app.* = .{ 
        .timer = try core.Timer.start(),
        .title_timer = try core.Timer.start(),
        .pipeline = pipeline 
    };
}

pub fn deinit(app: *App) void {
    defer core.deinit();
    defer state.deinit();
    _ = app;
}

pub fn update(app: *App) !bool {

    state.delta_time = app.timer.lap();
    state.game_time += state.delta_time;

    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => return true,
            else => {},
        }
    }

    const queue = core.queue;
    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = std.mem.zeroes(gpu.Color),
        .load_op = .clear,
        .store_op = .store,
    };

    const encoder = core.device.createCommandEncoder(null);
    const render_pass_info = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });
    const pass = encoder.beginRenderPass(&render_pass_info);
    pass.setPipeline(app.pipeline);
    pass.draw(3, 1, 0, 0);
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    queue.submit(&[_]*gpu.CommandBuffer{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Triangle [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}