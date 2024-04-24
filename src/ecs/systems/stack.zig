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
    // Requirements for request entities
    var view_with_request = gamestate.world.view(.{ Components.Stack, Components.Request, Components.CardSuit, Components.CardValue, Components.Position, Components.Drag }, .{});
    var entity_with_request_Iter = view_with_request.entityIterator();

    // Requirements for entities without request
    var view_exclude_request = gamestate.world.view(.{ Components.Stack, Components.CardSuit, Components.CardValue, Components.Position, Components.Moveable}, .{Components.Request});
    var entity_exclude_request_Iter = view_exclude_request.entityIterator();

    // Requirements for open piles
    var view_open_piles = gamestate.world.view(.{Components.OpenPile, Components.Position}, .{});
    var entity_open_piles_Iter = view_open_piles.entityIterator();

    // Requirements for foundation piles
    var view_foundation_piles = gamestate.world.view(.{Components.FoundationPile, Components.Position}, .{});
    var entity_foundation_piles_Iter = view_foundation_piles.entityIterator();

    const tile_half_size = utils.getTileHalfSize();

    var last_moved_entity_pos: ?Components.Position = null;
    var last_moved_entity_card_suit: ?Components.CardSuit = null;
    var last_moved_entity_card_value: ?Components.CardValue = null;
    var last_moved_entity_card_stack: ?Components.Stack = null;

    var at_least_one_collision = false;

    while (entity_with_request_Iter.next()) |entity_with_request| {
        var position_e1 = view_with_request.get(Components.Position, entity_with_request);
        var stack_e1 = view_with_request.get(Components.Stack, entity_with_request);
        // const drag_e1 = view_with_request.getConst(Components.Drag, entity_with_request);
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

                    gamestate.world.removeIfExists(Components.Request, entity_with_request);
                    gamestate.world.removeIfExists(Components.Drag, entity_with_request);

                    at_least_one_collision = true;
                }
                else {
                    // position_e1.x = drag_e1.start.x;
                    // position_e1.y = drag_e1.start.y;
                    std.debug.print("Invalid move!\n", .{});
                    // gamestate.world.removeIfExists(Components.Request, entity_with_request);
                    // gamestate.world.removeIfExists(Components.Drag, entity_with_request);
                }
            }
        }

        // TODO: Make a loop for foundation piles
        while(entity_foundation_piles_Iter.next()) |entity_foundation_pile| {
            const position_e2 = view_foundation_piles.getConst(Components.Position, entity_foundation_pile);

            if (utils.positionWithinArea(position_e1_with_offset, position_e2)){
                
                if (gamestate.world.has(Components.CardSuit, entity_foundation_pile) and gamestate.world.has(Components.CardValue, entity_foundation_pile)) {
                    const card_suit_e2 = gamestate.world.getConst(Components.CardSuit, entity_foundation_pile);
                    const card_value_e2 = gamestate.world.getConst(Components.CardValue, entity_foundation_pile);
                    if (isValidFoundationCardMove(card_suit_e1, card_value_e1, card_suit_e2, card_value_e2)) {
                        std.debug.print("ValidFoundationCardMove! Between {} of {} and foundation pile\n", .{card_value_e1, card_suit_e1});
                        position_e1.x = position_e2.x;
                        position_e1.y = position_e2.y;
                        stack_e1.index = 0;

                        last_moved_entity_pos = .{ .x = position_e1.x, .y = position_e1.y };
                        last_moved_entity_card_suit = card_suit_e1;
                        last_moved_entity_card_value = card_value_e1;
                        last_moved_entity_card_stack = stack_e1.*;

                        gamestate.world.addOrReplace(entity_foundation_pile, card_suit_e1);
                        gamestate.world.addOrReplace(entity_foundation_pile, card_value_e1);

                        gamestate.world.removeIfExists(Components.Request, entity_with_request);
                        gamestate.world.removeIfExists(Components.Drag, entity_with_request);

                        // gamestate.world.removeIfExists(Components.SpriteRenderer, entity_foundation_pile);
                        // gamestate.world.remove(Components.FoundationPile, entity_foundation_pile);
                        // gamestate.world.removeIfExists(Components.Position, entity_foundation_pile);

                        at_least_one_collision = true;
                    }
                }
                else if (isValidFoundationCardMove(card_suit_e1, card_value_e1, null, null)) {
                    std.debug.print("ValidFoundationCardMove! Between {} of {} and foundation pile\n", .{card_value_e1, card_suit_e1});
                    position_e1.x = position_e2.x;
                    position_e1.y = position_e2.y;
                    stack_e1.index = 0;

                    last_moved_entity_pos = .{ .x = position_e1.x, .y = position_e1.y };
                    last_moved_entity_card_suit = card_suit_e1;
                    last_moved_entity_card_value = card_value_e1;
                    last_moved_entity_card_stack = stack_e1.*;

                    gamestate.world.addOrReplace(entity_foundation_pile, card_suit_e1);
                    gamestate.world.addOrReplace(entity_foundation_pile, card_value_e1);

                    gamestate.world.removeIfExists(Components.Request, entity_with_request);
                    gamestate.world.removeIfExists(Components.Drag, entity_with_request);

                    // gamestate.world.removeIfExists(Components.SpriteRenderer, entity_foundation_pile);
                    // gamestate.world.remove(Components.FoundationPile, entity_foundation_pile);
                    // gamestate.world.removeIfExists(Components.Position, entity_foundation_pile);

                    at_least_one_collision = true;
                }
            }
        }

        // Collision with open piles
        while (entity_open_piles_Iter.next()) |entity_open_pile| {
            const position_e2 = view_open_piles.getConst(Components.Position, entity_open_pile);
            if (utils.positionWithinArea(position_e1_with_offset, position_e2)){
                if (isValidOpenPileCardMove(card_value_e1)) {
                    std.debug.print("ValidOpenPileCardMove! Between {} of {} and open pile\n", .{card_value_e1, card_suit_e1});
                    position_e1.x = position_e2.x;
                    position_e1.y = position_e2.y;
                    stack_e1.index = 0;

                    last_moved_entity_pos = .{ .x = position_e1.x, .y = position_e1.y };
                    last_moved_entity_card_suit = card_suit_e1;
                    last_moved_entity_card_value = card_value_e1;
                    last_moved_entity_card_stack = stack_e1.*;

                    gamestate.world.removeIfExists(Components.Request, entity_with_request);
                    gamestate.world.removeIfExists(Components.Drag, entity_with_request);

                    // gamestate.world.removeIfExists(Components.SpriteRenderer, entity_open_pile);
                    gamestate.world.remove(Components.OpenPile, entity_open_pile);
                    // gamestate.world.removeIfExists(Components.Position, entity_open_pile);

                    at_least_one_collision = true;
                }
            }
        }

    }

    // If no collisions were found, set the position of each entity with request to the drag start position
    if (!at_least_one_collision) {
        entity_with_request_Iter = view_with_request.entityIterator();
        while (entity_with_request_Iter.next()) |entity_with_request| {
            var position_e1 = view_with_request.get(Components.Position, entity_with_request);
            const drag_e1 = view_with_request.getConst(Components.Drag, entity_with_request);
            // const position_e1_with_offset: Components.Position = .{ .x = position_e1.x + tile_half_size[0], .y = position_e1.y - tile_half_size[1] };

            position_e1.x = drag_e1.start.x - drag_e1.offset.x;
            position_e1.y = drag_e1.start.y - drag_e1.offset.y;

            gamestate.world.removeIfExists(Components.Request, entity_with_request);
            gamestate.world.removeIfExists(Components.Drag, entity_with_request);
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
                gamestate.world.removeIfExists(Components.Request, entity_all_requests);
                gamestate.world.removeIfExists(Components.Drag, entity_all_requests);
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

    // var view_all_drags = gamestate.world.view(.{Components.Drag}, .{});
    // var entity_all_drags_Iter = view_all_drags.entityIterator();
    // while (entity_all_drags_Iter.next()) |entity_all_drags| {
    //     gamestate.world.remove(Components.Drag, entity_all_drags);
    // }
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

fn isValidFoundationCardMove(card_suit_e1: Components.CardSuit, card_value_e1: Components.CardValue, card_suit_e2: ?Components.CardSuit, card_value_e2: ?Components.CardValue) bool {
    if (card_suit_e2 == null and card_value_e2 == null) {
        if (card_value_e1 == .Ace) {
            return true;
        } else {
            return false;
        }
    }
    
    switch (card_suit_e1) {
        .Clubs => {
            if (card_suit_e2 == .Clubs) {
                if (@intFromEnum(card_value_e1) == @intFromEnum(card_value_e2.?) + 1) {
                    return true;
                }
            }
        },
        .Spades => {
            if (card_suit_e2 == .Spades) {
                if (@intFromEnum(card_value_e1) == @intFromEnum(card_value_e2.?) + 1) {
                    return true;
                }
            }
        },
        .Hearts => {
            if (card_suit_e2 == .Hearts) {
                if (@intFromEnum(card_value_e1) == @intFromEnum(card_value_e2.?) + 1) {
                    return true;
                }
            }
        },
        .Diamonds => {
            if (card_suit_e2 == .Diamonds) {
                if (@intFromEnum(card_value_e1) == @intFromEnum(card_value_e2.?) + 1) {
                    return true;
                }
            }
        }
    }

    return false;
}

/// Checks if the card can be moved to an open pile
/// Currently any card or stack of cards can be moved to an open pile
fn isValidOpenPileCardMove(card_value_e1: Components.CardValue) bool {
    switch (card_value_e1) {
        .King => return true,
        else => return true,
    }

    return false;
}