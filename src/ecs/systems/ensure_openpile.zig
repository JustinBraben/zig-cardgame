const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");
const settings = @import("../../settings.zig");

pub fn run(gamestate: *GameState) void {

    var view_cards_request = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile, Components.Request }, .{});
    var entity_cards_request_Iter = view_cards_request.entityIterator();

    var view_cards_drag = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile, Components.Drag }, .{});
    var entity_cards_drag_Iter = view_cards_drag.entityIterator();

    // If there are cards being dragged, or cards being requested, don't do anything
    if (entity_cards_request_Iter.next() != null or entity_cards_drag_Iter.next() != null) {
        return;
    }
    
    const starting_x: f32 = -200.0;
    const starting_y: f32 = 96.0;
    const end_x: f32 = 286.0;

    var current_x: f32 = starting_x;
    while (current_x <= end_x) {

        const position = Components.Position{.x = current_x, .y = starting_y};
        const lowest_position = utils.lowestPositionInPile(gamestate, position);
        var found_empty_pile = false;

        var view_piles = gamestate.world.view(.{ Components.Position, Components.OpenPile }, .{});
        var entity_cards_Iter = view_piles.entityIterator();
        while(entity_cards_Iter.next()) |entity_card| {
            const position_e1 = view_piles.getConst(Components.Position, entity_card);
            if (position_e1.x == current_x and position_e1.y == starting_y) {
                found_empty_pile = true;
            }
        }

        if (!found_empty_pile and lowest_position.y == std.math.floatMax(f32)){
            // Must add an entity to denote open pile free for use
            const entity = gamestate.world.create();
            gamestate.world.add(entity, Components.Position{.x = current_x, .y = starting_y});
            gamestate.world.addTypes(entity, .{Components.OpenPile});
            std.debug.print("Added an open pile!\n", .{});
        }

        current_x += 54;
    }
    

    // var view_cards_request = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile, Components.Request }, .{});
    // var entity_cards_request_Iter = view_cards_request.entityIterator();

    // var view_cards_drag = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile, Components.Drag }, .{});
    // var entity_cards_drag_Iter = view_cards_drag.entityIterator();

    // // If there are cards being dragged, or cards being requested, don't do anything
    // if (entity_cards_request_Iter.next() != null or entity_cards_drag_Iter.next() != null) {
    //     return;
    // }

    // var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{ Components.Drag, Components.Request, Components.Moveable });
    // var entity_cards_Iter = view_cards.entityIterator();

    // while (entity_cards_Iter.next()) |entity_card| {
    //     const position_e1 = view_cards.getConst(Components.Position, entity_card);
    //     const lowest_position = utils.lowestPositionInPile(gamestate, position_e1);
    //     if (lowest_position.y == position_e1.y) {
    //         std.debug.print("Made a new Moveable!\n", .{});
    //         gamestate.world.addTypes(entity_card, .{Components.Moveable});
    //     }
    // }
}