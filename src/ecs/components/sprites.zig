const game = @import("../../main.zig");
const gfx = game.gfx;

pub const SpriteRenderer = struct {
    index: usize = 0,
    flip_x: bool = false,
    flip_y: bool = false,
    order: usize = 0,
};

pub const SpriteAnimator = struct {
    animation: []usize,
    frame: usize = 0,
    elapsed: f32 = 0,
    fps: usize = 8,
    state: State = State.pause,

    pub const State = enum {
        pause,
        play,
    };
};
