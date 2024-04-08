const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

// TODO: Allow dragging from the initial position of the click
// Translate for how off the click is from the center of the card
pub fn run(gamestate: *GameState) void {

    if (gamestate.mouse.button(.primary)) |btn| {
        const initial_pos = btn.pressed_position;
        const tile_half_size = utils.getTileHalfSize();

        if (btn.pressed()) {
            std.debug.print("Mouse initial position pressed x : {}, y : {}\n", .{initial_pos[0], initial_pos[1]});
            var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue }, .{});
            var entityIter = view.entityIterator();
            while (entityIter.next()) |entity| {
                const entity_pos = view.getConst(Components.Position, entity);
                if (utils.positionWithinArea(.{ .x = initial_pos[0], .y = initial_pos[1]}, entity_pos)){
                    std.debug.print("Found card pressed at position x : {}, y : {}\n", .{entity_pos.x, entity_pos.y});
                    const drag = Components.Drag{ 
                        .start = .{ .x = initial_pos[0], .y = initial_pos[1]}, 
                        .end = .{ .x = initial_pos[0], .y = initial_pos[1]}
                    };
                    gamestate.world.addOrReplace(entity, drag);
                }
            }
        }

        if (btn.down()) {
            const current_pos = gamestate.mouse.position;
            const current_world_pos = game.state.camera.screenToWorld(zmath.f32x4(current_pos[0], current_pos[1], 0, 0));

            var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Drag }, .{});
            var entityIter = view.entityIterator();
            while (entityIter.next()) |entity| {
                var drag = view.get(Components.Drag, entity);
                var pos = view.get(Components.Position, entity);
                drag.end = .{ .x = current_world_pos[0] - tile_half_size[0], .y = current_world_pos[1] + tile_half_size[1]};
                pos.x = drag.end.x;
                pos.y = drag.end.y;
            }
        }

        if (btn.released()) {
            const final_pos = btn.released_position;
            var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Drag }, .{});
            var entityIter = view.entityIterator();
            while (entityIter.next()) |entity| {
                var pos = view.get(Components.Position, entity);
                pos.x = final_pos[0] - tile_half_size[0];
                pos.y = final_pos[1] + tile_half_size[1];
                gamestate.world.remove(Components.Drag, entity);
            }
        }
    }
}