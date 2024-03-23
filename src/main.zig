const std = @import("std");
const log = std.log.scoped(.main);
const core = @import("mach").core;
const gpu = core.gpu;
const zigimg = @import("zigimg");
const zmath = @import("zmath");
const GameState = @import("game_state.zig").GameState;
const Components = @import("ecs/components/components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;
const RenderMainPass = @import("ecs/systems/render_main_pass.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const settings = @import("settings.zig");

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
pub var content_scale: [2]f32 = undefined;
pub var window_size: [2]f32 = undefined;
pub var framebuffer_size: [2]f32 = undefined;

pub fn init(app: *App) !void {
    try core.init(.{
        .size = .{ .width = settings.window_width, .height = settings.window_height },
    });
    core.setFrameRateLimit(60);
    const descriptor = core.descriptor;
    window_size = .{ @floatFromInt(core.size().width), @floatFromInt(core.size().height) };
    framebuffer_size = .{ @floatFromInt(descriptor.width), @floatFromInt(descriptor.height) };
    content_scale = .{ 
        framebuffer_size[0] / window_size[0],
        framebuffer_size[1] / window_size[1],
    };
    const allocator = gpa.allocator();

    const base_folder = try std.fs.realpathAlloc(allocator, "../../");
    defer allocator.free(base_folder);
    std.debug.print("base folder : {s}\n", .{base_folder});

    state = try GameState.init(allocator);

    // var all_entities = state.world.entities();
    // while (all_entities.next()) |entity| {
    //     std.debug.print("Entity : {any}\n", .{entity});
    // }

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

    // try state.renderUsingBatch();
    try state.renderUsingNewTextureAndCamera();

    // const time = app.timer.read();
    // const model = zmath.mul(0, zmath.rotationZ(time * (std.math.pi / 2.0)));
    // const view = zmath.lookAtLh(
    //     state.camera.position[0],
    //     state.camera.position[1],
    //     state.camera.position[2],   
    // );

    // {   // Main Render pass
    //     try RenderMainPass.run(state);
    //     if (core.swap_chain.getCurrentTexture()) |back_buffer_view| {
    //         const batcher_commands = try state.batcher.finish();
    //         defer back_buffer_view.release();

            
    //         core.queue.submit(&[_]*gpu.CommandBuffer{batcher_commands});
    //         batcher_commands.release();
    //         core.swap_chain.present();
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
