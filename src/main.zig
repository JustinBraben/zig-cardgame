const std = @import("std");
const log = std.log.scoped(.main);
const core = @import("mach").core;
const gpu = core.gpu;
const zigimg = @import("zigimg");
const zmath = @import("zmath");
const GameState = @import("game_state.zig").GameState;
const Components = @import("ecs/components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;
pub const gfx = @import("gfx/gfx.zig");

pub const shaders = @import("shaders.zig");

pub const UniformBufferObject = struct {
    mvp: zmath.Mat,
};

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

pub var state: *GameState = undefined;

pub fn init(app: *App) !void {
    try core.init(.{});
    core.setFrameRateLimit(60);
    const allocator = gpa.allocator();

    const base_folder = try std.fs.realpathAlloc(allocator, "../../");
    defer allocator.free(base_folder);
    std.debug.print("base folder : {s}\n", .{base_folder});

    state = try GameState.init(allocator);

    app.* = .{
        .timer = try core.Timer.start(),
        .title_timer = try core.Timer.start(),
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

    //state.render();
    try state.renderUsingBatch();

    // const batcher_commands = try state.batcher.finish();
    // defer batcher_commands.release();

    // if (core.swap_chain.getCurrentTextureView()) |back_buffer_view| {
    //     defer back_buffer_view.release();

    //     var encoder = core.device.createCommandEncoder(null);

    //     {
    //         const color_attachment = gpu.RenderPassColorAttachment{
    //             .view = back_buffer_view,
    //             // sky blue background color:
    //             .clear_value = .{ .r = 0.52, .g = 0.8, .b = 0.92, .a = 1.0 },
    //             .load_op = .clear,
    //             .store_op = .store,
    //         };

    //         const render_pass_info = gpu.RenderPassDescriptor.init(.{
    //             .color_attachments = &.{color_attachment},
    //         });
    //     }
    // }

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Textured quad [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}

fn render(app: *App) !void {
    if (core.swap_chain.getCurrentTextureView()) |back_buffer_view| {
        const color_attachment = gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            // sky blue background color:
            .clear_value = .{ .r = 0.52, .g = 0.8, .b = 0.92, .a = 1.0 },
            .load_op = .clear,
            .store_op = .store,
        };

        const encoder = core.device.createCommandEncoder(null);
        const render_pass_info = gpu.RenderPassDescriptor.init(.{
            .color_attachments = &.{color_attachment},
        });

        // const proj = zmath.orthographicRh(
        //     @as(f32, @floatFromInt(core.size().width)),
        //     @as(f32, @floatFromInt(core.size().height)),
        //     0.1,
        //     1000,
        // );
        // const view = zmath.lookAtRh(
        //     zmath.Vec{ 0, 1000, 0, 1 },
        //     zmath.Vec{ 0, 0, 0, 1 },
        //     zmath.Vec{ 0, 0, 1, 0 },
        // );
        // const mvp = zmath.mul(view, proj);
        // _ = mvp;
        // std.debug.print("MVP: {any}\n", .{mvp});
        // std.debug.print("Camera : {any}\n", .{state.camera.frameBufferMatrix()});
        const ubo = UniformBufferObject{
            .mvp = zmath.transpose(state.camera.frameBufferMatrix()),
        };
        _ = ubo;

        // Draw the sprite batch
        const pass = encoder.beginRenderPass(&render_pass_info);
        pass.setPipeline(state.pipeline_default);
        pass.end();
        pass.release();

        // Submit the frame.
        var command = encoder.finish(null);
        encoder.release();
        const queue = core.queue;
        queue.submit(&[_]*gpu.CommandBuffer{command});
        command.release();
        core.swap_chain.present();
        back_buffer_view.release();

        _ = app;
    }
}
