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
    
    var view_cards_request = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile, Components.Request }, .{});
    var entity_cards_request_Iter = view_cards_request.entityIterator();

    var view_cards_drag = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile, Components.Drag }, .{});
    var entity_cards_drag_Iter = view_cards_drag.entityIterator();

    // If there are cards being dragged, or cards being requested, don't do anything
    if (entity_cards_request_Iter.next() != null or entity_cards_drag_Iter.next() != null) {
        return;
    }

    var view_cards = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Tile }, .{ Components.Drag, Components.Request, Components.Moveable });
    var entity_cards_Iter = view_cards.entityIterator();

    while (entity_cards_Iter.next()) |entity_card| {
        const position_e1 = view_cards.getConst(Components.Position, entity_card);
        const lowest_position = utils.lowestPositionInPile(gamestate, position_e1);
        if (lowest_position.y == position_e1.y) {
            std.debug.print("Made a new Moveable!\n", .{});
            gamestate.world.addTypes(entity_card, .{Components.Moveable});
        }
    }
}