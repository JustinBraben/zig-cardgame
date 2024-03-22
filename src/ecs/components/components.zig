pub const Position = struct { 
    x: f32,
    y: f32,
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
};