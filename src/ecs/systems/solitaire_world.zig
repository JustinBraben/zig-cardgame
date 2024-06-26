const std = @import("std");
const assert = std.debug.assert;
const zmath = @import("zmath");
const GameState = @import("../../game_state.zig").GameState;
const game = @import("../../main.zig");
const gfx = game.gfx;
const Components = @import("../components/components.zig");
const utils = @import("../../utils.zig");

// Systems are functions that operate on the game state
const AnimationSprite = @import("animation_sprite.zig");

const MovementDrag = @import("movement_drag.zig");
const Stack = @import("stack.zig");
const EnsureMoveable = @import("ensure_moveable.zig");
const EnsureOpenPile = @import("ensure_openpile.zig");

const FoundationPileSystem = @import("foundationpile_system.zig");

const ScanMouse = @import("scan_mouse.zig");

const CameraFollow = @import("camera_follow.zig");

const RenderMainPass = @import("render_main_pass.zig");

/// Main function to progress the game state 
/// This function is called every update() in main.zig 
pub fn progress(gamestate: *GameState) !void {

    AnimationSprite.run(gamestate);

    ScanMouse.run(gamestate);

    MovementDrag.run(gamestate);
    Stack.run(gamestate);
    EnsureMoveable.run(gamestate);
    EnsureOpenPile.run(gamestate);
    FoundationPileSystem.run(gamestate);

    CameraFollow.run(gamestate);

    try RenderMainPass.renderSprites(gamestate);
}