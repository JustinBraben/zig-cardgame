const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const components = game.components;

pub fn run(gamestate: *GameState) !void {

    // const uniforms = gfx.UniformBufferObject{
    //     .mvp = zmath.transpose(
    //         zmath.orthographicRh(
    //             @as(f32, @floatFromInt(game.settings.window_width)),
    //             @as(f32, @floatFromInt(game.settings.window_height)),
    //             0.1,
    //             1000
    //         )
    //     ),
    // };

    const uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(
            game.state.camera.renderTextureMatrix()
        ),
    };
    // std.debug.print("mvp is : {any}\n", .{uniforms.mvp});

    {
        try gamestate.batcher.begin(.{
            .pipeline_handle = gamestate.pipeline_default,
            .bind_group_handle = gamestate.bind_group_default,
            .output_handle = gamestate.default_texture.view_handle,
        });

        // const position = zmath.f32x4(
        //     -@as(f32, @floatFromInt(gamestate.default_texture.image.width)) / 2, 
        //     -@as(f32, @floatFromInt(gamestate.default_texture.image.height)) / 2, 
        //     0, 
        //     0
        // );

        const position = zmath.f32x4(
            -@as(f32, @floatFromInt(game.state.default_texture.image.width)) / 2,
            -@as(f32, @floatFromInt(game.state.default_texture.image.height)) / 2,
            0,
            0
        );

        try gamestate.batcher.texture(position, &gamestate.default_texture, .{});

        try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    }

    const final_uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(
            zmath.orthographicLh(game.settings.design_size[0], game.settings.design_size[1], -100, 100)
        ),
    };

    {
        gamestate.batcher.begin(.{
            .pipeline_handle = gamestate.pipeline_default,
            .bind_group_handle = gamestate.bind_group_default,
            .output_handle = gamestate.default_texture.view_handle,
        }) catch unreachable;

        const position = zmath.f32x4(
            -@as(f32, @floatFromInt(game.state.default_texture.image.width)) / 2,
            -@as(f32, @floatFromInt(game.state.default_texture.image.height)) / 2,
            0,
            0
        );

        try gamestate.batcher.texture(position, &gamestate.default_texture, .{});

        try gamestate.batcher.end(final_uniforms, gamestate.uniform_buffer_default);
    }

    // const post_uniforms = gfx.UniformBufferObject{ .mvp = zmath.transpose(game.state.camera.frameBufferMatrix()) };

    // {
    //     gamestate.batcher.begin(.{
    //         .pipeline_handle = gamestate.pipeline_default,
    //         .bind_group_handle = gamestate.bind_group_default,
    //         .output_handle = gamestate.default_texture.view_handle,
    //     }) catch unreachable;

    //     gamestate.batcher.texture(zmath.f32x4s(0), &gamestate.default_texture, .{}) catch unreachable;

    //     gamestate.batcher.end(post_uniforms, gamestate.uniform_buffer_default) catch unreachable;
    // }
}