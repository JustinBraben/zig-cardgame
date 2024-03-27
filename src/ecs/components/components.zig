const std = @import("std");
const zmath = @import("zmath");
const game = @import("../../main.zig");
const ecs = @import("zig-ecs");

const sprites = @import("sprites.zig");

pub const Position = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
};

pub const CardValue = enum {
    Ace,
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Ten,
    Jack,
    Queen,
    King,
};

pub const CardSuit = enum { Spades, Hearts, Diamonds, Clubs };

pub const Tile = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
};

pub const SpriteRenderer = sprites.SpriteRenderer;
pub const SpriteAnimator = sprites.SpriteAnimator;


pub const Camera = struct {};