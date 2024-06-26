const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
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
        const initial_pos_as_Position: Components.Position = .{ .x = initial_pos[0], .y = initial_pos[1]};

        if (btn.pressed()) {
            // std.debug.print("Mouse initial position pressed x : {}, y : {}\n", .{initial_pos[0], initial_pos[1]});
            var valid_stack_position_x: f32 = 0;
            var valid_stack_index: u8 = 0;
            var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Stack, Components.Moveable }, .{});
            var entityIter = view.entityIterator();
            while (entityIter.next()) |entity| {
                const entity_pos = view.getConst(Components.Position, entity);
                const entity_stack = view.getConst(Components.Stack, entity);

                // Check to see if there are any cards at the position of the mouse click
                if (utils.positionWithinArea(initial_pos_as_Position, entity_pos)){
                    if(utils.isFrontCard(gamestate, initial_pos_as_Position, entity_pos)) {
                        // std.debug.print("Found front card pressed at position x : {}, y : {}\n", .{entity_pos.x, entity_pos.y});
                        const drag = Components.Drag{ 
                            .start = .{ .x = initial_pos[0], .y = initial_pos[1]}, 
                            .end = .{ .x = initial_pos[0], .y = initial_pos[1]},
                            .offset = .{ .x = initial_pos[0] - entity_pos.x, .y = initial_pos[1] - entity_pos.y}
                        };
                        // std.debug.print("Offset x : {}, y : {}\n", .{drag.offset.x, drag.offset.y});
                        gamestate.world.addOrReplace(entity, drag);
                        valid_stack_position_x = entity_pos.x;
                        valid_stack_index = entity_stack.index;
                    }
                }

                // TODO: Use stack component to determine what card to drag
            }

            // TODO: Fix bug here that grabs cards beneath foundation stacks
            // give cards in foundation stack a component to denote they are in a foundation stack
            var view_for_stack = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Stack, Components.Moveable }, .{});
            entityIter = view_for_stack.entityIterator();
            while (entityIter.next()) |entity| {
                const entity_pos = view.getConst(Components.Position, entity);
                const entity_stack = view.getConst(Components.Stack, entity);
                if (entity_pos.x == valid_stack_position_x and entity_stack.index > valid_stack_index) {
                    const drag = Components.Drag{ 
                        .start = .{ .x = initial_pos[0], .y = initial_pos[1]}, 
                        .end = .{ .x = initial_pos[0], .y = initial_pos[1]},
                        .offset = .{ .x = initial_pos[0] - entity_pos.x, .y = initial_pos[1] - entity_pos.y}
                    };
                    gamestate.world.addOrReplace(entity, drag);
                }
            }
        }

        if (btn.down()) {
            const current_pos = gamestate.mouse.position;
            const current_world_pos = game.state.camera.screenToWorld(zmath.f32x4(current_pos[0], current_pos[1], 0, 0));

            var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Drag, Components.Stack }, .{});
            var entityIter = view.entityIterator();
            while (entityIter.next()) |entity| {
                var drag = view.get(Components.Drag, entity);
                var pos = view.get(Components.Position, entity);
                drag.end = .{ .x = current_world_pos[0] - drag.offset.x, .y = current_world_pos[1] - drag.offset.y};
                pos.x = drag.end.x;
                pos.y = drag.end.y;
            }
        }

        if (btn.released()) {
            const final_pos = btn.released_position;
            var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Drag, Components.Stack }, .{});
            var entityIter = view.entityIterator();
            while (entityIter.next()) |entity| {
                // const pos = view.getConst(Components.Position, entity);
                var drag = view.get(Components.Drag, entity);
                drag.end = .{ .x = final_pos[0] - drag.offset.x, .y = final_pos[1] - drag.offset.y};
                // const drag = view.getConst(Components.Drag, entity);
                // var pos = view.get(Components.Position, entity);
                // pos.x = final_pos[0] - drag.offset.x;
                // pos.y = final_pos[1] - drag.offset.y;
                // gamestate.world.remove(Components.Drag, entity);
                gamestate.world.addTypes(entity, .{Components.Request});
                // std.debug.print("Made request!\n", .{});
                std.debug.print("Request to Position x : {}, y : {}\n", .{drag.end.x, drag.end.y});
            }
        }
    }
}

// TODO: Make helper function to only grab the forefront card of a stack
// No cards behind the top card should be grabbed
fn getFrontCard(gamestate: *GameState, pos: Components.Position) !Components.Position {
    var position_list = std.ArrayList(Components.Position).init(gamestate.allocator);
    defer position_list.deinit();

    var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Stack }, .{});
    var entityIter = view.entityIterator();
    while (entityIter.next()) |entity| {
        const entity_pos = view.getConst(Components.Position, entity);
        if (utils.positionWithinArea(.{ .x = pos.x, .y = pos.y}, entity_pos)){
            // return view.get(Components.Position, entity);
            try position_list.append(view.get(Components.Position, entity));
        }
    }
    
    if (position_list.items.len == 0) {
        return error.OutOfRange;
    }

    if (position_list.items.len == 1) {
        return position_list.items[0];
    }

    var min_pos = position_list.items[0];
    for (position_list.items) |value| {
        const current_min_y = @min(min_pos.y, value.y);
        if (current_min_y == value.y) {
            min_pos = value;
        }
    }

    return min_pos;
}