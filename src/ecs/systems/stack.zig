const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

pub fn run(gamestate: *GameState) void {
    var view = gamestate.world.view(.{ Components.Stack, Components.Request, Components.Position}, .{});
    var entityIter = view.entityIterator();
    while (entityIter.next()) |entity| {
        const stack = view.getConst(Components.Stack, entity);
    }
}