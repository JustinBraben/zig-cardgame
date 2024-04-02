const game = @import("../../main.zig");
const gfx = game.gfx;
const zmath = @import("zmath");

pub const SpriteRenderer = struct {
    index: usize = 0,
    flip_x: bool = false,
    flip_y: bool = false,
    color: [4]f32 = zmath.f32x4s(1.0),
    frag_mode: gfx.Batcher.SpriteOptions.FragRenderMode = .standard,
    vert_mode: gfx.Batcher.SpriteOptions.VertRenderMode = .standard,
    order: usize = 0,
    reflect: bool = false,
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
