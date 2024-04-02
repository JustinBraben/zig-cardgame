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
    const uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(gamestate.camera.frameBufferMatrix()),
    };

    // Render the playing table
    // try gamestate.batcher.begin(.{
    //     .pipeline_handle = gamestate.pipeline_game_window,
    //     .bind_group_handle = gamestate.bind_group_game_window,
    // });
    // // Draw the playing table texture
    // // const pos = zmath.f32x4(-640, -320, 100, 0);
    // const pos = gamestate.camera.worldToScreen(
    //     zmath.f32x4(
    //         -1.0 * (@as(f32, @floatFromInt(game.settings.design_width)) / 2.0),
    //         (@as(f32, @floatFromInt(game.settings.design_height)) / 2.0),
    //         0,
    //         0
    //         )
    //     );
    // try gamestate.batcher.texture(pos, &gamestate.game_window_texture, .{});
    // try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);

    // Render the sprites
    try gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default,
        .bind_group_handle = gamestate.bind_group_default,
        // .output_handle = gamestate.default_output.view_handle,
    });
    var view = gamestate.world.view(.{ Components.Tile, Components.SpriteRenderer }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const tile = view.getConst(Components.Tile, entity);
        // const tile_pos = utils.tileToPixelCoords(tile);
        // const position = utils.toF32x4(tile_pos);
        const position = zmath.f32x4(
            @as(f32, @floatFromInt(tile.x)) * game.settings.pixels_per_unit_x,
            @as(f32, @floatFromInt(tile.y)) * game.settings.pixels_per_unit_y,
            @as(f32, @floatFromInt(tile.z)) * 32, 
            0
        );
        
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

    // try gamestate.batcher.begin(.{
    //     .pipeline_handle = gamestate.pipeline_default,
    //     .bind_group_handle = gamestate.bind_group_default,
    //     .output_handle = gamestate.default_output.view_handle,
    // });

    // try gamestate.batcher.texture(zmath.f32x4s(0), &gamestate.default_output, .{});

    // try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
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
        var view = gamestate.world.view(.{ Components.Tile, Components.SpriteRenderer }, .{});
        var iter = view.entityIterator();
        while (iter.next()) |entity| {
            const tile = view.getConst(Components.Tile, entity);
            // const tile_pos = utils.tileToPixelCoords(tile);
            // const position = utils.toF32x4(tile_pos);
            const position = zmath.f32x4(
                (@as(f32, @floatFromInt(tile.x)) * game.settings.pixels_per_unit_x),
                (@as(f32, @floatFromInt(tile.y)) * game.settings.pixels_per_unit_y),
                @as(f32, @floatFromInt(tile.z)) * 32, 
                0
            );
            const renderer = view.getConst(Components.SpriteRenderer, entity);
            try gamestate.batcher.sprite(
                position, 
                &gamestate.default_texture,
                gamestate.atlas.sprites[renderer.index],
                .{
                    .color = renderer.color,
                    .vert_mode = renderer.vert_mode,
                    .frag_mode = renderer.frag_mode,
                    .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
                    .flip_x = false,
                    .flip_y = false,
                    .rotation = 0.0,
                },
            );
        }
        try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    }
    
    {
        try gamestate.batcher.begin(.{
            .pipeline_handle = gamestate.pipeline_default,
            .bind_group_handle = gamestate.bind_group_default,
            .output_handle = gamestate.game_window_output.view_handle,
        });
        try gamestate.batcher.texture(zmath.f32x4s(0.0), &gamestate.default_texture, .{});
        try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    }

    // TODO: Fix how we draw sprites to an output texture
    // This should not fail, because drawing sprites to the output texture should look different
    // assert(!std.mem.eql(u8, gamestate.game_window_output.image.pixels.asBytes(), gamestate.default_output.image.pixels.asBytes()));

    uniforms = gfx.UniformBufferObject{ 
        .mvp = zmath.transpose(gamestate.camera.frameBufferMatrix()),
    };
    try gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default,
        .bind_group_handle = gamestate.bind_group_default,
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
