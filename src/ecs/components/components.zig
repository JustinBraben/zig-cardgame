pub const Position = struct { 
    x: f32, 
    y: f32,
};

pub const CardSuit = enum { Spades, Hearts, Diamonds, Clubs };

pub const Tile = struct {
    x: i32 = 0,
    y: i32 = 0,
    counter: u64 = 0,
};