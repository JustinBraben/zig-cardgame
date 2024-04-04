const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

pub fn run(gamestate: *GameState) void {
    const scaled_size: [2]f32 = .{ game.settings.design_width * gamestate.camera.zoom, game.settings.design_height * gamestate.camera.zoom };
    const size_diff: [2]f32 = .{ @abs(scaled_size[0] - game.window_size[0]), @abs(scaled_size[1] - game.window_size[1]) };
    const offset: [2]f32 = .{ size_diff[0] / scaled_size[0] / 2.0, size_diff[1] / scaled_size[1] / 2.0 };

    const remaining: [2]f32 = .{ 1.0 - offset[0] * 2.0, 1.0 - offset[1] * 2.0 };

    const mouse_x: f32 = utils.lerp(offset[0], offset[0] + remaining[0], gamestate.mouse.position[0] / game.window_size[0]);
    const mouse_y: f32 = utils.lerp(offset[1], offset[1] + remaining[1], gamestate.mouse.position[1] / game.window_size[1]);

    gamestate.scanner_position[0] = mouse_x;
    gamestate.scanner_position[1] = mouse_y;

    if (gamestate.scanner_state) {
        if (gamestate.scanner_time < 1.0) {
            gamestate.scanner_time = @min(1.0, gamestate.scanner_time + gamestate.delta_time);
        } else {
            //game.state.scanner_time = 0.0;
        }
    } else {
        // 
        if (gamestate.scanner_time > 0.0)
            gamestate.scanner_time = @max(0.0, gamestate.scanner_time - gamestate.delta_time);
    }
}