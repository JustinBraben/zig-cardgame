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
pub const Tile = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
};

pub const CardValue = enum(u8) {
    Ace = 1,
    Two = 2,
    Three = 3,
    Four = 4,
    Five = 5,
    Six = 6,
    Seven = 7,
    Eight = 8,
    Nine = 9,
    Ten = 10,
    Jack = 11,
    Queen = 12,
    King = 13,
};
pub const CardSuit = enum(u8) { 
    Spades = 0, 
    Hearts = 1, 
    Diamonds = 2, 
    Clubs = 3 
};
pub const DeckOrder = struct {
    index: usize = 0,
};
pub const IsShuffled = struct {};

pub const SpriteRenderer = sprites.SpriteRenderer;
pub const SpriteAnimator = sprites.SpriteAnimator;

pub const Request = struct {};
pub const Drag = struct {
    start: Position,
    end: Position,
};
pub const Moveable = struct {};

pub const Camera = struct {};