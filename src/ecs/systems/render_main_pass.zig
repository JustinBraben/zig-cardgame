const std = @import("std");
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
    // std.debug.print("camera mvp : {any}\n", .{uniforms.mvp});

    gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default,
        .bind_group_handle = gamestate.bind_group_default,
        .output_handle = gamestate.default_texture.view_handle,
    }) catch unreachable;

    var view = gamestate.world.view(.{ Components.Tile, Components.SpriteRenderer }, .{});
    var iter = view.entityIterator();
    const size = utils.getTileSize();
    while (iter.next()) |entity| {
        const tile = view.getConst(Components.Tile, entity);
        const tile_pos = utils.tileToPixelCoords(tile);
        try gamestate.batcher.textureSquare(zmath.f32x4(tile_pos.x, tile_pos.y, 0, 0), .{ size.x, size.y }, .{});
    }

    try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
}

pub fn runSprite(gamestate: *GameState) !void {
    const uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(gamestate.camera.renderTextureMatrix()),
    };

    try gamestate.batcher.begin(.{
        .pipeline_handle = gamestate.pipeline_default,
        .bind_group_handle = gamestate.bind_group_default,
        .output_handle = gamestate.default_output.view_handle,
    });

    const pos = zmath.f32x4(-640, -320, 0, 0);

    gamestate.batcher.texture(pos, &gamestate.game_window_texture, .{}) catch unreachable;

    try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);

    // try gamestate.batcher.begin(.{
    //     .pipeline_handle = gamestate.pipeline_default,
    //     .bind_group_handle = gamestate.bind_group_default,
    //     .output_handle = gamestate.default_output.view_handle,
    // });

    // var view = gamestate.world.view(.{ Components.Tile, Components.SpriteRenderer }, .{});
    // var iter = view.entityIterator();
    // while (iter.next()) |entity| {
    //     const tile = view.getConst(Components.Tile, entity);
    //     // const tile_pos = utils.tileToPixelCoords(tile);
    //     // const position = utils.toF32x4(tile_pos);
    //     const position = zmath.f32x4(
    //         @as(f32, @floatFromInt(tile.x)) * game.settings.pixels_per_unit_x,
    //         @as(f32, @floatFromInt(tile.y)) * game.settings.pixels_per_unit_y,
    //         @as(f32, @floatFromInt(tile.z)) * 32, 
    //         0
    //     );
        
    //     const renderer = view.getConst(Components.SpriteRenderer, entity);
    //     gamestate.batcher.sprite(
    //         position, 
    //         &gamestate.default_texture,
    //         gamestate.atlas.sprites[renderer.index],
    //         .{
    //             .time = gamestate.game_time + @as(f32, @floatFromInt(renderer.order)),
    //             .rotation = 0.0,
    //             .flip_x = false,
    //             .flip_y = false,
    //         },
    //     ) catch unreachable;
    // }

    // try gamestate.batcher.end(uniforms, gamestate.uniform_buffer_default);
}
