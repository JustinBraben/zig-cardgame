const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

pub fn run(gamestate: *GameState) void {

    var cameraView = gamestate.world.view(.{ Components.Camera, Components.Position }, .{});
    var cameraIter = cameraView.entityIterator();

    while (cameraIter.next()) |entity| {
        const position = cameraView.get(Components.Position, entity);
        gamestate.camera.position = zmath.f32x4(position.x, position.y, position.z, 0);
    }
    
}