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

pub fn run(gamestate: *GameState) !void {
    var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{ Components.Drag, Components.Request, Components.Moveable });
    var entity_cards_Iter = view_cards.entityIterator();

    var view_cards_2 = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{ Components.Drag, Components.Request, Components.Moveable });
    var entity_cards_Iter_2 = view_cards_2.entityIterator();

    // Use a map (key: x value of the card, value: y value of the card) to store the front cards of the stacks
    var map_front_cards = std.AutoHashMap(i32, f32).init(gamestate.allocator);
    defer map_front_cards.deinit();

    while (entity_cards_Iter.next()) |entity_card| {
        const position_e1 = view_cards.getConst(Components.Position, entity_card);
        const tile_e1 = view_cards.getConst(Components.Tile, entity_card);

        var y_min: f32 = position_e1.y;

        while (entity_cards_Iter_2.next()) |entity_card_2| {
            const position_e2 = view_cards_2.getConst(Components.Position, entity_card_2);
            const tile_e2 = view_cards_2.getConst(Components.Tile, entity_card_2);
            // if (utils.positionsEqual(position_e1, position_e2)){
            //     continue;
            // }
            
            if (tile_e1.x == tile_e2.x) {

                // const position_e1_int = @as(i64, @intFromFloat(position_e1.x));
                // We want to look at cards in the same x position
                // And find the furthest down card of the stack
                // If the card is the front card of the stack, we can move it to the other stack
                // Thus is should be have Moveable component
                if (utils.isFrontCard(gamestate, position_e1, position_e2)){
                    y_min = @min(y_min, position_e2.y);
                    if (map_front_cards.get(tile_e1.x)) |y| {
                        y_min = @min(y_min, y);
                    }
                }
                try map_front_cards.put(tile_e1.x, y_min);
            }
        }
    }

    // std.debug.print("Front cards map count : {}!\n", .{map_front_cards.count()});


    // TODO: Make this add moveable to the front cards of the stacks
    // entity_cards_Iter = view_cards.entityIterator();
    // while (entity_cards_Iter.next()) |entity_card| {
    //     const position_e1 = view_cards.getConst(Components.Position, entity_card);
    //     const tile_e1 = view_cards.getConst(Components.Tile, entity_card);

    //     const tile_to_position = utils.tileToPixelCoords(tile_e1);
    //     const position_at_tile_x = (tile_to_position.x + (settings.pixel_spacing_x * @as(f32, @floatFromInt(tile_e1.x)))) - 200.0;

    //     if (map_front_cards.get(tile_e1.x)) |y| {
    //         if (position_e1.x == position_at_tile_x and position_e1.y == y) {
    //             // std.debug.print("Made a new Moveable!\n", .{});
    //             gamestate.world.addTypes(entity_card, .{Components.Moveable});
    //         }
    //     }
    // }
}