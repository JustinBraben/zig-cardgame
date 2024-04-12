const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

/// This system is used to handle stacks of cards that are being dragged around the screen.
/// It will look for any entities with a `Components.Stack` and `Components.Request` component.
/// It will then look for other entities excluding a `Components.Stack` and `Components.Position` component.
/// It will then check if the stack is being dragged over any of the entities without a `Components.Stack` and `Components.Position` component.
pub fn run(gamestate: *GameState) void {
    var view_with_request = gamestate.world.view(.{ Components.Stack, Components.Request, Components.CardSuit, Components.CardValue, Components.Position}, .{});
    var entity_with_request_Iter = view_with_request.entityIterator();

    var view_exclude_request = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position}, .{Components.Request});
    var entity_exclude_request_Iter = view_exclude_request.entityIterator();

    const tile_half_size = utils.getTileHalfSize();

    while (entity_with_request_Iter.next()) |entity_with_request| {
        var position_e1 = view_with_request.get(Components.Position, entity_with_request);
        const position_e1_with_offset: Components.Position = .{ .x = position_e1.x + tile_half_size[0], .y = position_e1.y - tile_half_size[1] };
        const card_suit_e1 = view_with_request.getConst(Components.CardSuit, entity_with_request);
        const card_value_e1 = view_with_request.getConst(Components.CardValue, entity_with_request);
        while(entity_exclude_request_Iter.next()) |entity_without_request| {
            const position_e2 = view_exclude_request.getConst(Components.Position, entity_without_request);
            const card_suit_e2 = view_exclude_request.getConst(Components.CardSuit, entity_without_request);
            const card_value_e2 = view_exclude_request.getConst(Components.CardValue, entity_without_request);
            if (utils.positionWithinArea(position_e1_with_offset, position_e2)){
                std.debug.print("Found collision! Between {} of {} and {} of {}\n", .{card_value_e1, card_suit_e1, card_value_e2, card_suit_e2});

                // Snaps entity_with_request to entity_without_request to make a stack
                position_e1.x = position_e2.x;
                position_e1.y = position_e2.y - tile_half_size[1];
            }
        }
    }

    // After going through the top block, we need to delete request component from all entities.
    var view_all_requests = gamestate.world.view(.{Components.Request}, .{});
    var entity_all_requests_Iter = view_all_requests.entityIterator();
    while (entity_all_requests_Iter.next()) |entity_all_requests| {
        gamestate.world.remove(Components.Request, entity_all_requests);
    }
}