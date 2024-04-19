const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
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

    var last_moved_entity_pos: ?Components.Position = null;
    var last_moved_entity_card_suit: ?Components.CardSuit = null;
    var last_moved_entity_card_value: ?Components.CardValue = null;
    var last_moved_entity_card_stack: ?Components.Stack = null;

    while (entity_with_request_Iter.next()) |entity_with_request| {
        var position_e1 = view_with_request.get(Components.Position, entity_with_request);
        var stack_e1 = view_with_request.get(Components.Stack, entity_with_request);
        const position_e1_with_offset: Components.Position = .{ .x = position_e1.x + tile_half_size[0], .y = position_e1.y - tile_half_size[1] };
        const card_suit_e1 = view_with_request.getConst(Components.CardSuit, entity_with_request);
        const card_value_e1 = view_with_request.getConst(Components.CardValue, entity_with_request);
        while(entity_exclude_request_Iter.next()) |entity_without_request| {
            const position_e2 = view_exclude_request.getConst(Components.Position, entity_without_request);
            const stack_e2 = view_exclude_request.getConst(Components.Stack, entity_without_request);
            const card_suit_e2 = view_exclude_request.getConst(Components.CardSuit, entity_without_request);
            const card_value_e2 = view_exclude_request.getConst(Components.CardValue, entity_without_request);
            if (utils.positionWithinArea(position_e1_with_offset, position_e2)){
                std.debug.print("Found collision! Between {} of {} and {} of {}\n", .{card_value_e1, card_suit_e1, card_value_e2, card_suit_e2});
                std.debug.print("All cards requested should snap below sequentially\n", .{});
                // Snaps entity_with_request to entity_without_request to make a stack
                // position_e1.x = position_e2.x;
                // position_e1.y = position_e2.y - tile_half_size[1];

                // TODO: only change position if the move is valid
                // Checks if the move is valid
                if (isCardValidMove(card_suit_e1, card_value_e1, card_suit_e2, card_value_e2)) {
                    position_e1.x = position_e2.x;
                    position_e1.y = position_e2.y - tile_half_size[1];


                    stack_e1.index = stack_e2.index + 1;
                    // stack_e2.index += 1;
                    // stack_e1.index = stack_e2.index - 1;

                    std.debug.print("Valid move!\n", .{});
                    std.debug.print("Requested entity stack index : {}\n", .{stack_e1.index});
                    std.debug.print("Collided entity stack index : {}\n", .{stack_e2.index});

                    last_moved_entity_pos = .{ .x = position_e1.x, .y = position_e1.y };
                    last_moved_entity_card_suit = card_suit_e1;
                    last_moved_entity_card_value = card_value_e1;
                    last_moved_entity_card_stack = stack_e1.*;

                    gamestate.world.remove(Components.Request, entity_with_request);
                }
                else {
                    std.debug.print("Invalid move!\n", .{});
                }
            }
        }
    }

    // Next we need to update the position of all the cards below the one that just moved
    // Keep looping until no more cards with request are found
    var request_found = true;
    if (last_moved_entity_pos == null or last_moved_entity_card_suit == null or last_moved_entity_card_value == null or last_moved_entity_card_stack == null) {
        request_found = false;
    }
    else {
        std.debug.print("Last moved card is {s} of {s}\n", .{@tagName(last_moved_entity_card_value.?), @tagName(last_moved_entity_card_suit.?)});
    }

    while(request_found) {
        var view_all_requests = gamestate.world.view(.{Components.Stack, Components.Request, Components.CardSuit, Components.CardValue, Components.Position}, .{});
        var entity_all_requests_Iter = view_all_requests.entityIterator();

        var count: usize = 0;
        while (entity_all_requests_Iter.next()) |entity_all_requests| {
            var position_e1 = view_with_request.get(Components.Position, entity_all_requests);
            var stack_e1 = view_with_request.get(Components.Stack, entity_all_requests);
            const card_suit_e1 = view_with_request.getConst(Components.CardSuit, entity_all_requests);
            const card_value_e1 = view_with_request.getConst(Components.CardValue, entity_all_requests);
            
            if (isCardValidMove(card_suit_e1, card_value_e1, last_moved_entity_card_suit.?, last_moved_entity_card_value.?)) {
                position_e1.x = last_moved_entity_pos.?.x;
                position_e1.y = last_moved_entity_pos.?.y - tile_half_size[1];

                stack_e1.index = last_moved_entity_card_stack.?.index + 1;

                last_moved_entity_pos = .{ .x = position_e1.x, .y = position_e1.y };
                last_moved_entity_card_suit = card_suit_e1;
                last_moved_entity_card_value = card_value_e1;
                last_moved_entity_card_stack = stack_e1.*;

                std.debug.print("Moving card below the last moved\n", .{});
                gamestate.world.remove(Components.Request, entity_all_requests);
            }
            count += 1;
        }
        
        // Out of entities with requests, or the loop is wrong breakout
        if (count == 0 or count > 52) {
            request_found = false;
        }
    }

    // After going through the top block, we need to delete request component from all entities.
    var view_all_requests = gamestate.world.view(.{Components.Request}, .{});
    var entity_all_requests_Iter = view_all_requests.entityIterator();
    while (entity_all_requests_Iter.next()) |entity_all_requests| {
        gamestate.world.remove(Components.Request, entity_all_requests);
    }
}

fn isCardValidMove(card_suit_e1: Components.CardSuit, card_value_e1: Components.CardValue, card_suit_e2: Components.CardSuit, card_value_e2: Components.CardValue) bool {
    switch (card_suit_e1) {
        .Clubs, .Spades => {
            if (card_suit_e2 == .Hearts or card_suit_e2 == .Diamonds) {
                if (@intFromEnum(card_value_e1) == @intFromEnum(card_value_e2) - 1) {
                    return true;
                }
            }  
        },
        .Hearts, .Diamonds => {
            if (card_suit_e2 == .Clubs or card_suit_e2 == .Spades) {
                if (@intFromEnum(card_value_e1) == @intFromEnum(card_value_e2) - 1) {
                    return true;
                }
            }
        }
    }

    return false;
}
test "Testing isCardValidMove" {
    try testing.expect(isCardValidMove(.Clubs, .Queen, .Hearts, .King));
    try testing.expect(isCardValidMove(.Clubs, .Three, .Diamonds, .Four));
    try testing.expect(isCardValidMove(.Hearts, .Six, .Spades, .Seven));
    try testing.expect(isCardValidMove(.Hearts, .Ten, .Clubs, .Jack));

    try testing.expect(isCardValidMove(.Spades, .Queen, .Hearts, .King));
    try testing.expect(isCardValidMove(.Spades, .Three, .Diamonds, .Four));
    try testing.expect(isCardValidMove(.Diamonds, .Six, .Spades, .Seven));
    try testing.expect(isCardValidMove(.Diamonds, .Ten, .Clubs, .Jack));

    // These are expected to fail
    try testing.expect(!isCardValidMove(.Clubs, .Queen, .Hearts, .Queen));
    try testing.expect(!isCardValidMove(.Clubs, .Three, .Clubs, .Two));
    try testing.expect(!isCardValidMove(.Hearts, .Six, .Hearts, .Five));
    try testing.expect(!isCardValidMove(.Hearts, .Ten, .Hearts, .Nine));
    try testing.expect(!isCardValidMove(.Clubs, .Three, .Diamonds, .Three));

    try testing.expect(!isCardValidMove(.Spades, .Queen, .Hearts, .Queen));
}