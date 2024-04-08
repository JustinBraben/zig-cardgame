const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const ecs = @import("zflecs");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

pub fn run(gamestate: *GameState) !void {
    var uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(gamestate.camera.renderTextureMatrix()),
    };

    {
        // Render the playing table to default output texture
        try gamestate.batcher.begin(.{
            .pipeline_handle = gamestate.pipeline_game_window,
            .bind_group_handle = gamestate.bind_group_game_window,
            .output_handle = gamestate.default_output.view_handle,
        });
        const position = zmath.f32x4s(0);
        gamestate.batcher.texture(position, &gamestate.game_window_texture, .{}) catch unreachable;
        try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    }


    {
        // Render the sprites to the default output texture
        try gamestate.batcher.begin(.{
            .pipeline_handle = gamestate.pipeline_default,
            .bind_group_handle = gamestate.bind_group_default,
            .output_handle = gamestate.default_output.view_handle,
        });
        var view = gamestate.world.view(.{ Components.Position, Components.SpriteRenderer }, .{});
        var iter = view.entityIterator();
        while (iter.next()) |entity| {
            const pos = view.getConst(Components.Position, entity);
            const position = utils.toF32x4(pos);
            const renderer = view.getConst(Components.SpriteRenderer, entity);
            gamestate.batcher.sprite(
                position, 
                &gamestate.default_texture,
                gamestate.atlas.sprites[renderer.index],
                .{
                    .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
                    .rotation = 0.0,
                    .flip_x = false,
                    .flip_y = false,
                },
            ) catch unreachable;
        }
        try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    }

    uniforms = gfx.UniformBufferObject{ 
        .mvp = zmath.transpose(gamestate.camera.frameBufferMatrix()),
    };
    try gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default_output,
        .bind_group_handle = gamestate.bind_group_default_output,
    });
    try gamestate.batcher.texture(zmath.f32x4s(0), &gamestate.default_output, .{});
    try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
}

pub fn renderSprites(gamestate: *GameState) !void {
    var uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(gamestate.camera.renderTextureMatrix()),
    };

    {
        try gamestate.batcher.begin(.{
            .pipeline_handle = gamestate.pipeline_default,
            .bind_group_handle = gamestate.bind_group_default,
            .output_handle = gamestate.default_output.view_handle,
        });
        var view = gamestate.world.view(.{ Components.Position, Components.SpriteRenderer }, .{});
        var iter = view.entityIterator();
        while (iter.next()) |entity| {
            const pos = view.getConst(Components.Position, entity);
            const position = utils.toF32x4(pos);
            const renderer = view.getConst(Components.SpriteRenderer, entity);
            gamestate.batcher.sprite(
                position, 
                &gamestate.default_texture,
                gamestate.atlas.sprites[renderer.index],
                .{
                    .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
                    .rotation = 0.0,
                    .flip_x = false,
                    .flip_y = false,
                },
            ) catch unreachable;
        }
        try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    }

    // {   // Draw sprites and order them by y position
    //     // This draws in the correct order, but it crashes when recreating the solitaire game
    //     try gamestate.batcher.begin(.{
    //         .pipeline_handle = gamestate.pipeline_default,
    //         .bind_group_handle = gamestate.bind_group_default,
    //         .output_handle = gamestate.default_output.view_handle,
    //     });
    //     var position_order_group = gamestate.world.group(.{}, .{ Components.Position, Components.SpriteRenderer }, .{});
    //     const SortPositionContext = struct {
    //         fn sort(_: void, a: Components.Position, b: Components.Position) bool {
    //             return a.y < b.y;
    //         }
    //     };
    //     position_order_group.sort(Components.Position, {}, SortPositionContext.sort);
    //     var group_iter_sorted = position_order_group.iterator();
    //     while (group_iter_sorted.next()) |entity| {
    //         const pos = position_order_group.getConst(Components.Position, entity);
    //         const position = utils.toF32x4(pos);
    //         const renderer = position_order_group.getConst(Components.SpriteRenderer, entity);
    //         try gamestate.batcher.sprite(
    //             position, 
    //             &gamestate.default_texture,
    //             gamestate.atlas.sprites[renderer.index],
    //             .{
    //                 .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
    //                 .rotation = 0.0,
    //                 .flip_x = false,
    //                 .flip_y = false,
    //             },
    //         );
    //     }
    //     try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    // }
    
    // {
    //     try gamestate.batcher.begin(.{
    //         .pipeline_handle = gamestate.pipeline_default,
    //         .bind_group_handle = gamestate.bind_group_default,
    //         .output_handle = gamestate.game_window_output.view_handle,
    //     });
    //     try gamestate.batcher.texture(zmath.f32x4s(0.0), &gamestate.default_texture, .{});
    //     try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    // }

    // TODO: Fix how we draw sprites to an output texture
    // This should not fail, because drawing sprites to the output texture should look different
    // assert(!std.mem.eql(u8, gamestate.game_window_output.image.pixels.asBytes(), gamestate.default_output.image.pixels.asBytes()));

    uniforms = gfx.UniformBufferObject{ 
        .mvp = zmath.transpose(gamestate.camera.frameBufferMatrix()),
    };
    try gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default_output,
        .bind_group_handle = gamestate.bind_group_default_output,
    });
    // const pos = gamestate.camera.worldToScreen(
    //     zmath.f32x4(
    //         -1.0 * (@as(f32, @floatFromInt(game.settings.design_width)) / 2.0),
    //         (@as(f32, @floatFromInt(game.settings.design_height)) / 2.0),
    //         0,
    //         0
    //         )
    //     );
    try gamestate.batcher.texture(zmath.f32x4s(0), &gamestate.default_output, .{ .data_2 = gamestate.game_time});
    try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
}

pub fn renderTable(gamestate: *GameState) !void {

    const mvp = zmath.transpose(gamestate.camera.renderTextureMatrix());

    var uniforms = gfx.UniformBufferObject{
        .mvp = mvp,
    };

    // Render the playing table to game_window_output texture
    try gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_game_window,
        .bind_group_handle = gamestate.bind_group_game_window,
        .output_handle = gamestate.game_window_output.view_handle,
    });
    const position = zmath.f32x4s(0);
    gamestate.batcher.texture(position, &gamestate.game_window_texture, .{}) catch unreachable;
    try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);


    // Render the game_window_output texture to the framebuffer (screen)
    uniforms = gfx.UniformBufferObject{ 
        .mvp = zmath.transpose(gamestate.camera.frameBufferMatrix()),
    };
    try gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_game_window,
        .bind_group_handle = gamestate.bind_group_game_window,
    });
    try gamestate.batcher.texture(zmath.f32x4s(0), &gamestate.game_window_output, .{});
    try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
}
