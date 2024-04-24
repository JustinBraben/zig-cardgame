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

    // Loop through foundation piles (not open ones)
    // See if there are any cards at the position
    // If no card is found there, add an open foundation pile component to the foundation entity
    // var view_foundation_piles = gamestate.world.view(.{ Components.Position, Components.FoundationPile }, .{Components.OpenFoundationPile});
    // var entity_foundation_pile_Iter = view_foundation_piles.entityIterator();

    // while(entity_foundation_pile_Iter.next()) |entity_foundation_pile| {
    //     const position_e1 = view_foundation_piles.getConst(Components.Position, entity_foundation_pile);
    //     var found_card_at_foundation_pile = false;

    //     var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{});
    //     var entity_cards_Iter = view_cards.entityIterator();

    //     while(entity_cards_Iter.next()) |entity_card| {
    //         const position_e2 = view_cards.getConst(Components.Position, entity_card);
    //         if (utils.positionsEqual(position_e1, position_e2)) {
    //             found_card_at_foundation_pile = true;
    //         }
    //     }

    //     if (!found_card_at_foundation_pile) {
    //         std.debug.print("Foundation now open!\n", .{});
    //         gamestate.world.addTypes(entity_foundation_pile, .{Components.OpenFoundationPile});
    //     }
    // }

    // Loop through open foundation piles
    // See if there are any cards at the position
    // var view_open_foundation_piles = gamestate.world.view(.{ Components.Position, Components.FoundationPile, Components.OpenFoundationPile }, .{});
    // var entity_open_foundation_pile_Iter = view_open_foundation_piles.entityIterator();

    // var open_foundation_piles_count: usize = 0;

    // while(entity_open_foundation_pile_Iter.next()) |entity_open_foundation_pile| {
    //     const position_e1 = view_open_foundation_piles.getConst(Components.Position, entity_open_foundation_pile);

    //     var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{});
    //     var entity_cards_Iter = view_cards.entityIterator();

    //     var cards_count: usize = 0;
    //     var card_found_at_open_foundation_pile = false;

    //     while(entity_cards_Iter.next()) |entity_card| {

    //         const position_e2 = view_cards.getConst(Components.Position, entity_card);

    //         // std.debug.print("pos_e1 x : {}, y : {}\n", .{position_e1.x, position_e1.y});
    //         // std.debug.print("pos_e2 x : {}, y : {}\n", .{position_e2.x, position_e2.y});

    //         // If a single card is found at the foundation pile, mark to remove the open foundation pile component on the foundation entity
    //         if (utils.positionWithinArea(position_e1, position_e2)) {
    //             std.debug.print("Foundation no longer open!\n", .{});
    //             gamestate.world.remove(Components.OpenFoundationPile, entity_open_foundation_pile);
    //             card_found_at_open_foundation_pile = true;
    //         }

    //         cards_count += 1;
    //     }

    //     // if (!card_found_at_open_foundation_pile) {
    //     //     std.debug.print("Foundation no longer open!\n", .{});
    //     //     gamestate.world.remove(Components.OpenFoundationPile, entity_open_foundation_pile);
    //     // }

    //     open_foundation_piles_count += 1;
    //     // std.debug.print("Cards count : {}\n", .{cards_count});
    //     // std.debug.print("Foundation x : {}, y : {} . Card found : {}\n", .{position_e1.x, position_e1.y, card_found_at_open_foundation_pile});
    // }

    // std.debug.print("Open foundation piles : {}\n", .{open_foundation_piles_count});
    
    // // const starting_x: f32 = -38.0;
    // // const starting_y: f32 = 192.0;
    // // const end_x: f32 = 124.0;
    // // var current_x: f32 = starting_x;

    // // This loop just makes sure to make OpenFoundationPiles if they don't exist and they should
    // while (current_x <= end_x) {

    //     const position = Components.Position{.x = current_x, .y = starting_y};
    //     var found_open_foundation_pile = false;

    //     // Loop through open foundation piles
    //     // See if there are any cards at the position
    //     // If a single card is found, remove the open foundation pile component
    //     var view_open_foundation_piles = gamestate.world.view(.{ Components.Position, Components.FoundationPile, Components.OpenFoundationPile }, .{});
    //     var entity_open_foundation_pile_Iter = view_open_foundation_piles.entityIterator();
        
    //     var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{});
    //     var entity_cards_Iter = view_cards.entityIterator();

    //     while(entity_open_foundation_pile_Iter.next()) |entity_open_foundation_pile| {
    //         const position_e1 = view_open_foundation_piles.getConst(Components.Position, entity_open_foundation_pile);
            
    //         while(entity_cards_Iter.next()) |entity_card| {

    //             const position_e2 = view_cards.getConst(Components.Position, entity_card);

    //             if (utils.positionsEqual(position_e1, position_e2)) {
    //                 gamestate.world.removeIfExists(Components.OpenFoundationPile, entity_open_foundation_pile);
    //             }
    //         }
    //     }

    //     // var view_open_foundation_piles = gamestate.world.view(.{ Components.Position, Components.FoundationPile, Components.OpenFoundationPile }, .{});
    //     // var entity_piles_Iter = view_open_foundation_piles.entityIterator();
    //     // while(entity_piles_Iter.next()) |entity_open_foundation_pile| {
    //     //     const position_e1 = view_open_foundation_piles.getConst(Components.Position, entity_open_foundation_pile);
    //     //     if (utils.positionsEqual(position_e1, position)) {
    //     //         found_open_foundation_pile = true;
    //     //     }
    //     // }

    //     // if (!found_open_foundation_pile){

    //     //     var found_card_at_foundation_pile = false;
    //     //     var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{});
    //     //     var entity_cards_Iter = view_cards.entityIterator();
    //     //     while (entity_cards_Iter.next()) |entity_card| {
    //     //         const position_e1 = view_cards.getConst(Components.Position, entity_card);
    //     //         if (utils.positionsEqual(position_e1, position)) {
    //     //             found_card_at_foundation_pile = true;
    //     //         }
    //     //     }

    //     //     if (!found_card_at_foundation_pile) {
    //     //         const entity = gamestate.world.create();
    //     //         gamestate.world.add(entity, position);
    //     //         gamestate.world.addTypes(entity, .{Components.OpenFoundationPile});
                
    //     //         // 53 is index of the back of the card
    //     //         gamestate.world.addOrReplace(entity, Components.SpriteRenderer{
    //     //             .index = 53,
    //     //         });
    //     //         std.debug.print("Added an open foundation pile!\n", .{});
    //     //     }

    //     //     // // Must add an entity to denote open pile free for use
    //     //     // const entity = gamestate.world.create();
    //     //     // gamestate.world.add(entity, position);
    //     //     // gamestate.world.addTypes(entity, .{Components.FoundationPile});
            
    //     //     // // 53 is index of the back of the card
    //     //     // gamestate.world.addOrReplace(entity, Components.SpriteRenderer{
    //     //     //     .index = 53,
    //     //     // });
    //     //     // std.debug.print("Added an open foundation pile!\n", .{});
    //     // }

    //     current_x += 54;
    // }
}