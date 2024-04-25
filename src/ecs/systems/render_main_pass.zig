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

    // TODO: Remove this eventually
    // Old way of rendering sprites without positioning based on render order
    // {
    //     try gamestate.batcher.begin(.{
    //         .pipeline_handle = gamestate.pipeline_default,
    //         .bind_group_handle = gamestate.bind_group_default,
    //         .output_handle = gamestate.default_output.view_handle,
    //     });
    //     var view = gamestate.world.view(.{ Components.Position, Components.SpriteRenderer }, .{});
    //     var iter = view.entityIterator();
    //     while (iter.next()) |entity| {
    //         const pos = view.getConst(Components.Position, entity);
    //         const position = utils.toF32x4(pos);
    //         const renderer = view.getConst(Components.SpriteRenderer, entity);
    //         gamestate.batcher.sprite(
    //             position, 
    //             &gamestate.default_texture,
    //             gamestate.atlas.sprites[renderer.index],
    //             .{
    //                 .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
    //                 .rotation = 0.0,
    //                 .flip_x = false,
    //                 .flip_y = false,
    //             },
    //         ) catch unreachable;
    //     }
    //     try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    // }

    {   // Draw sprites and order them by y position
        try gamestate.batcher.begin(.{
            .pipeline_handle = gamestate.pipeline_default,
            .bind_group_handle = gamestate.bind_group_default,
            .output_handle = gamestate.default_output.view_handle,
        });
        var position_order_group = gamestate.world.group(.{}, .{ Components.Position, Components.SpriteRenderer }, .{});
        const SortPositionContext = struct {
            fn sort(_: void, a: Components.Position, b: Components.Position) bool {
                return a.y < b.y;
            }
        };
        position_order_group.sort(Components.Position, {}, SortPositionContext.sort);
        var group_iter_sorted = position_order_group.iterator();
        while (group_iter_sorted.next()) |entity| {
            const pos = position_order_group.getConst(Components.Position, entity);
            const position = utils.toF32x4(pos);
            const renderer = position_order_group.getConst(Components.SpriteRenderer, entity);
            try gamestate.batcher.sprite(
                position, 
                &gamestate.default_texture,
                gamestate.atlas.sprites[renderer.index],
                .{
                    .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
                    .rotation = 0.0,
                    .flip_x = false,
                    .flip_y = false,
                },
            );
        }
        try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
    }

    // try gamestate.batcher.begin(.{
    //     .pipeline_handle = gamestate.pipeline_default,
    //     .bind_group_handle = gamestate.bind_group_default,
    //     .output_handle = gamestate.default_output.view_handle,
    // });
    // {   // Draw sprites for foundation pile first
    //     var foundation_pile_view = gamestate.world.view(.{ Components.Position, Components.SpriteRenderer, Components.FoundationPile }, .{});
    //     var foundation_pile_iter = foundation_pile_view.entityIterator();
    //     while (foundation_pile_iter.next()) |entity_foundation_pile| {
    //         const pos = foundation_pile_view.getConst(Components.Position, entity_foundation_pile);
    //         const position = utils.toF32x4(pos);
    //         const renderer = foundation_pile_view.getConst(Components.SpriteRenderer, entity_foundation_pile);
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
    // }

    // {   // Then draw open piles
    //     var open_pile_view = gamestate.world.view(.{ Components.Position, Components.SpriteRenderer, Components.OpenPile }, .{ });
    //     var open_pile_iter = open_pile_view.entityIterator();
    //     while (open_pile_iter.next()) |entity_open_pile| {
    //         const pos = open_pile_view.getConst(Components.Position, entity_open_pile);
    //         const position = utils.toF32x4(pos);
    //         const renderer = open_pile_view.getConst(Components.SpriteRenderer, entity_open_pile);
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
    // }

    // {   // Then draw the cards on the table without drag/request in order
    //     // var table_view = gamestate.world.view(.{ Components.Position, Components.SpriteRenderer }, .{ Components.Drag, Components.Request, Components.FoundationPile, Components.OpenPile });
    //     // var table_iter = table_view.entityIterator();
    //     // while (table_iter.next()) |entity_table| {
    //     //     const pos = table_view.getConst(Components.Position, entity_table);
    //     //     const position = utils.toF32x4(pos);
    //     //     const renderer = table_view.getConst(Components.SpriteRenderer, entity_table);
    //     //     try gamestate.batcher.sprite(
    //     //         position, 
    //     //         &gamestate.default_texture,
    //     //         gamestate.atlas.sprites[renderer.index],
    //     //         .{
    //     //             .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
    //     //             .rotation = 0.0,
    //     //             .flip_x = false,
    //     //             .flip_y = false,
    //     //         },
    //     //     );
    //     // }

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
    //         if (!gamestate.world.has(Components.FoundationPile, entity) and !gamestate.world.has(Components.OpenPile, entity)){
    //             try gamestate.batcher.sprite(
    //                 position, 
    //                 &gamestate.default_texture,
    //                 gamestate.atlas.sprites[renderer.index],
    //                 .{
    //                     .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
    //                     .rotation = 0.0,
    //                     .flip_x = false,
    //                     .flip_y = false,
    //                 },
    //             );
    //         }
    //     }
    // }

    // {   // Then draw the cards on the table with drag in order
    //     var moving_cards_view = gamestate.world.view(.{ Components.Position, Components.SpriteRenderer, Components.Drag }, .{});
    //     var moving_cards_iter = moving_cards_view.entityIterator();
    //     while (moving_cards_iter.next()) |entity_moving_cards| {
    //         const pos = moving_cards_view.getConst(Components.Position, entity_moving_cards);
    //         const position = utils.toF32x4(pos);
    //         const renderer = moving_cards_view.getConst(Components.SpriteRenderer, entity_moving_cards);
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
    // }
    // try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);

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
