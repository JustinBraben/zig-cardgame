const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

pub const FinalUniforms = extern struct {
    mvp: zmath.Mat,
    output_channel: i32 = 0,
};

pub fn run(gamestate: *GameState) !void {

    const final_uniforms = FinalUniforms{ .mvp = zmath.transpose(zmath.orthographicLh(game.settings.design_size[0], game.settings.design_size[1], -100, 100)), .output_channel = 0 };

    gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default,
        .bind_group_handle = gamestate.bind_group_default,
        .output_handle = gamestate.default_texture.view_handle,
    }) catch unreachable;

    const position = zmath.f32x4(-@as(f32, @floatFromInt(gamestate.default_texture.image.width)) / 2, -@as(f32, @floatFromInt(gamestate.default_texture.image.height)) / 2, 0, 0);

    gamestate.batcher.texture(position, &gamestate.default_texture, .{ .data_2 = game.state.scanner_time }) catch unreachable;

    gamestate.batcher.end(final_uniforms, gamestate.uniform_buffer_default) catch unreachable;

    const uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(gamestate.camera.frameBufferMatrix()),
    };
    // std.debug.print("camera mvp : {any}\n", .{uniforms.mvp});

    gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default,
        .bind_group_handle = gamestate.bind_group_default,
        .output_handle = gamestate.default_texture.view_handle,
    }) catch unreachable;

    gamestate.batcher.texture(zmath.f32x4s(0), &gamestate.default_texture, .{}) catch unreachable;

    gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default) catch unreachable;
}