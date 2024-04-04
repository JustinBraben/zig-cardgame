const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

pub fn run(gamestate: *GameState) void {

    var view = gamestate.world.view(.{ Components.SpriteRenderer, Components.SpriteAnimator }, .{});
    var entityIter = view.entityIterator();

    while (entityIter.next()) |entity| {
        var spriteRenderer = view.get(Components.SpriteRenderer, entity);
        var spriteAnimator = view.get(Components.SpriteAnimator, entity);

        if (spriteAnimator.state == .play) {
            spriteAnimator.elapsed += gamestate.delta_time;

            if (spriteAnimator.elapsed > (1.0 / @as(f32, @floatFromInt(spriteAnimator.fps)))) {
                spriteAnimator.elapsed = 0.0;
                

                if (spriteAnimator.frame < spriteAnimator.animation.len - 1) {
                    spriteAnimator.frame += 1;
                } else {
                    spriteAnimator.frame = 0;
                }
                spriteRenderer.index = spriteAnimator.animation[spriteAnimator.frame];
            }
        }
    }
    
}