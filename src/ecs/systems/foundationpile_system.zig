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

    // TODO: Instead, loop through FoundationPiles and get their position
    // Use a utils helper function to find cards at that position
    // Determine the highest value card at that position
    // Ensure the highest value card Moveable
    // Ensure the rest of the cards at that position are not Moveable
    var view_foundation_piles = gamestate.world.view(.{ Components.Position, Components.FoundationPile }, .{});
    var entity_foundation_pile_Iter = view_foundation_piles.entityIterator();
    while(entity_foundation_pile_Iter.next()) |entity_foundation_pile| {
        const position_e1 = view_foundation_piles.getConst(Components.Position, entity_foundation_pile);

        const highest_card_value = utils.highestValueCardInFoundation(gamestate, position_e1);

        if (highest_card_value > 0){
            var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{});
            var entity_cards_Iter = view_cards.entityIterator();

            while(entity_cards_Iter.next()) |entity_card| {
                const position_e2 = view_cards.getConst(Components.Position, entity_card);
                const card_value = view_cards.getConst(Components.CardValue, entity_card);
                const card_suit = view_cards.getConst(Components.CardSuit, entity_card);

                if (utils.positionsEqual(position_e1, position_e2)) {

                    if (!gamestate.world.has(Components.CardInFoundationPile, entity_card)) {
                        gamestate.world.addTypes(entity_card, .{Components.CardInFoundationPile});
                    }

                    if (@intFromEnum(card_value) == highest_card_value) {
                        gamestate.world.addOrReplace(entity_foundation_pile, card_value);
                        gamestate.world.addOrReplace(entity_foundation_pile, card_suit);
                        
                        if (!gamestate.world.has(Components.Moveable, entity_card)) {
                            gamestate.world.addTypes(entity_card, .{Components.Moveable});
                        }
                    }
                    else {
                        if (gamestate.world.has(Components.Moveable, entity_card)) {
                            gamestate.world.remove(Components.Moveable, entity_card);
                        }
                    }

                    // if (!gamestate.world.has(Components.CardInFoundationPile, entity_card)) {
                    //     gamestate.world.addTypes(entity_card, .{Components.CardInFoundationPile});
                    // }

                    // if (@intFromEnum(card_value) < highest_card_value) {
                    //     gamestate.world.removeIfExists(Components.Moveable, entity_card);
                    // } else {
                        
                    //     if (!gamestate.world.has(Components.Moveable, entity_card)){
                    //         // gamestate.world.addTypes(entity_card, .{Components.Moveable});
                    //     }
                    // }
                }
            }
        } else {
            gamestate.world.removeIfExists(Components.CardValue, entity_foundation_pile);
            gamestate.world.removeIfExists(Components.CardSuit, entity_foundation_pile);
        }
        
        // else {
        //     if (!gamestate.world.has(Components.OpenFoundationPile, entity_foundation_pile)) {
        //         gamestate.world.addTypes(entity_foundation_pile, .{Components.OpenFoundationPile});
        //     }
        // }

        // var found_card_at_foundation_pile = false;

        // while(entity_cards_Iter.next()) |entity_card| {
        //     const position_e2 = view_cards.getConst(Components.Position, entity_card);
        //     if (utils.positionsEqual(position_e1, position_e2)) {
        //         found_card_at_foundation_pile = true;
        //     }
        // }

        // if (!found_card_at_foundation_pile) {
        //     // std.debug.print("No cards found at foundation!\n", .{});
        //     // gamestate.world.addTypes(entity_foundation_pile, .{Components.OpenFoundationPile});
        // }
    }
}