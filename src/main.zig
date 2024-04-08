const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.main);
const assert = std.debug.assert;
const core = @import("mach").core;
const gpu = core.gpu;
const zigimg = @import("zigimg");
const zmath = @import("zmath");
const GameState = @import("game_state.zig").GameState;
pub const Components = @import("ecs/components/components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;
const SolitaireWorld = @import("ecs/systems/solitaire_world.zig");
const RenderMainPass = @import("ecs/systems/render_main_pass.zig");
const RenderFinalPass = @import("ecs/systems/render_final_pass.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const settings = @import("settings.zig");

pub const shaders = @import("shaders.zig");

pub const UniformBufferObject = struct {
    mvp: zmath.Mat,
};

test {
    // TODO: refactor code so we can use this here:
    // testing.refAllDeclsRecursive(@This());
    _ = @import("utils.zig");
    _ = @import("input/Hotkeys.zig");
    _ = @import("input/Mouse.zig");
}

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
    // core.setFrameRateLimit(60);
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

    // std.debug.print("default output before renderSprites : {any}\n", .{state.default_output.image.pixels});
    // try RenderMainPass.renderSprites(state);
    // std.debug.print("default output after renderSprites : {any}\n", .{state.default_output.image.pixels});

    state.createSolitaire() catch |err| {
        std.debug.print("Error creating solitaire: {}\n", .{err});
    };

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

pub fn updateMainThread(_: *App) !bool {
    return false;
}

pub fn update(app: *App) !bool {
    state.delta_time = app.timer.lap();
    state.game_time += state.delta_time;

    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .key_press => |key_press| {
                state.hotkeys.setHotkeyState(key_press.key, key_press.mods, .press);
            },
            .key_repeat => |key_repeat| {
                state.hotkeys.setHotkeyState(key_repeat.key, key_repeat.mods, .repeat);
            },
            .key_release => |key_release| {
                state.hotkeys.setHotkeyState(key_release.key, key_release.mods, .release);
            },
            .mouse_motion => |mouse_motion| {
                state.mouse.position = .{ @floatCast(mouse_motion.pos.x), @floatCast(mouse_motion.pos.y) };
            },
            .mouse_press => |mouse_press| {
                state.mouse.setButtonState(mouse_press.button, mouse_press.mods, .press);
                // std.debug.print("Current Camera position, x : {}, y: {}\n", .{state.camera.position[0], state.camera.position[1]});
            },
            .mouse_release => |mouse_release| {
                state.mouse.setButtonState(mouse_release.button, mouse_release.mods, .release);
            },
            .close => return true,
            .framebuffer_resize => |size| {
                framebuffer_size[0] = @floatFromInt(size.width);
                framebuffer_size[1] = @floatFromInt(size.height);
                window_size[0] = @floatFromInt(core.size().width);
                window_size[1] = @floatFromInt(core.size().height);
                settings.window_width = core.size().width;
                settings.window_height = core.size().height;
                content_scale = .{
                    framebuffer_size[0] / window_size[0],
                    framebuffer_size[1] / window_size[1],
                };
                state.camera.frameBufferResize();
            },
            else => {},
        }
    }

    const n: bool = if (state.hotkeys.hotkey(.directional_up)) |hk| hk.down() else false;
    const s: bool = if (state.hotkeys.hotkey(.directional_down)) |hk| hk.down() else false;
    const e: bool = if (state.hotkeys.hotkey(.directional_right)) |hk| hk.down() else false;
    const w: bool = if (state.hotkeys.hotkey(.directional_left)) |hk| hk.down() else false;

    if (n) {
        state.camera.position[1] += 1.0;
    }
    if (s) {
        state.camera.position[1] -= 1.0;
    }
    if (e) {
        state.camera.position[0] += 1.0;
    }
    if (w) {
        state.camera.position[0] -= 1.0;
    }

    const start_new_game: bool = if (state.hotkeys.hotkey(.new_game)) |hk| hk.released() else false;
    if (start_new_game) {
        state.createSolitaire() catch |err| {
            std.debug.print("Error creating solitaire: {}\n", .{err});
        };
    }

    // The world progresses through this main function
    // Any systems that need to run will be called here
    try SolitaireWorld.progress(state);

    const batcher_commands = try state.batcher.finish();
    defer batcher_commands.release();

    core.queue.submit(&[_]*gpu.CommandBuffer{batcher_commands});
    core.swap_chain.present();

    for (state.hotkeys.hotkeys) |*hk| {
        hk.previous_state = hk.state;
    }

    for (state.mouse.buttons) |*button| {
        button.previous_state = button.state;
    }

    state.mouse.previous_position = state.mouse.position;

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
