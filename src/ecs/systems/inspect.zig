const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const ecs = @import("zig-ecs");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

var inspect_tile: ?Components.Tile = null;
var inspect_time: f32 = 0.0;
// var inspect_target: ecs.entity_t = 0;
var last_width: f32 = 0.0;
var secondary: bool = false;

pub fn run(gamestate: *GameState) void {
    var inspect: bool = false;

    if (gamestate.mouse.button(.secondary)) |bt| {
        if (bt.released()){
            secondary = !secondary;
        }

        if (secondary) {
            inspect = true;
        }
    }
    if (gamestate.hotkeys.hotkey(.inspect)) |hk| {
        if (hk.down()) {
            inspect = true;
        }
    }

    gamestate.scanner_state = inspect;

    if (gamestate.mouse.button(.primary)) |btn| {
        if (btn.pressed()) {
            const mouse_tile = gamestate.mouse.tile();
            var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue }, .{});
            var entityIter = view.entityIterator();

            while (entityIter.next()) |entity| {
                const card_suite = view.getConst(Components.CardSuit, entity);
                const card_value = view.getConst(Components.CardValue, entity);
                const tile = view.getConst(Components.Tile, entity);
                if (tile.x == mouse_tile[0] and tile.y == mouse_tile[1]) {
                    std.debug.print("Found card on tile clicked, {any} of {any}\n", .{card_value, card_suite});
                }
            }
        }
    }
}