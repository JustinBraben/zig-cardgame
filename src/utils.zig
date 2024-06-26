pub const std = @import("std");
pub const testing = std.testing;
pub const Components = @import("ecs/components/components.zig");
pub const settings = @import("settings.zig");
const game = @import("main.zig");
const GameState = @import("game_state.zig").GameState;
const zmath = @import("zmath");

pub fn toF32x4(self: Components.Position) zmath.F32x4 {
    return zmath.f32x4(self.x, self.y, 0.0, 0.0);
}

pub fn positionWithinArea(needle: Components.Position, haystack: Components.Position) bool {
    const x_within = (needle.x >= haystack.x) and (needle.x < haystack.x + game.settings.pixels_per_unit_x);
    const y_within = (needle.y >= (haystack.y - game.settings.pixels_per_unit_y)) and (needle.y < haystack.y);
    return (x_within and y_within);
}

pub fn getTileCentre(self: Components.Tile) Components.Position {
    return .{
        .x = (@as(f32, @floatFromInt(self.x)) * game.settings.pixels_per_unit_x) - (game.settings.pixels_per_unit_x / 2.0),
        .y = (@as(f32, @floatFromInt(self.y)) * game.settings.pixels_per_unit_y) - (game.settings.pixels_per_unit_y / 2.0),
    };
}

pub fn getTileFullSize() [2]f32 {
    return .{
        game.settings.pixels_per_unit_x,
        game.settings.pixels_per_unit_y,
    };
}

pub fn getTileHalfSize() [2]f32 {
    return .{
        (game.settings.pixels_per_unit_x / 2.0),
        (game.settings.pixels_per_unit_y / 2.0),
    };
}

pub fn getTileSize() Components.Position {
    return .{
        .x = settings.pixels_per_unit / @as(f32, @floatFromInt(game.settings.window_width)) * 2.0,
        .y = settings.pixels_per_unit / @as(f32, @floatFromInt(game.settings.window_height)) * 2.0,
    };
}

/// Converts tile to pixel coordinates
pub fn tileToPixelCoords(self: Components.Tile) Components.Position {
    // Currently need x and y to be between 1.0 and -1.0
    // Create a transfer function to convert between the two
    // Use the tile size and size of window to calculate the position
    // TODO: Eventually may need to change this to accomadate camera view

    return .{
        .x = (@as(f32, @floatFromInt(self.x)) * game.settings.pixels_per_unit_x),
        .y = (@as(f32, @floatFromInt(self.y)) * game.settings.pixels_per_unit_y),
        .z = 0,
    };
}

/// Converts pixel to tile coordinates
pub fn pixelToTileCoords(self: Components.Position) Components.Tile {
    return .{
        .x = @as(i32, @intFromFloat(@divFloor(self.x, game.settings.pixels_per_unit_x))),
        .y = @as(i32, @intFromFloat(@ceil(self.y / game.settings.pixels_per_unit_y))),
    };
}

pub fn tile(p: f32) i32 {
    return @as(i32, @intFromFloat(@round(p / game.settings.pixels_per_unit)));
}

pub fn positionApproxEq(a: Components.Position, b: Components.Position, tolerance: f32) bool {
    return (a.x - b.x < tolerance) and (a.y - b.y < tolerance);
}

test "Tile position to pixel position" {
    // TODO: should have the tolerance be by x and y separately
    // And have the tolerance be by pixels_per_unit_x and pixels_per_unit_y
    const tolerance_f32 = @sqrt(std.math.floatEps(f32));

    const tiles = [_]Components.Tile{
        .{ .x = 0, .y = 0 },
        .{ .x = 2, .y = 0 },
        .{ .x = 0, .y = -3 },
        // .{ .x = 0, .y = 4 },
        // .{ .x = -5, .y = -5 },
    };

    const expected_positions = [_]Components.Position{
        .{ .x = 0.0, .y = 0.0 },
        .{ .x = 88.0, .y = 0.0 },
        .{ .x = 0.0, .y = -192.00 },
        // .{ .x = 0, .y = 0.166666671 },
        // .{ .x = -0.125, .y = -0.208333328 },
    };

    for (tiles, expected_positions) |current_tile, expected_position| {
        const actual_position = tileToPixelCoords(current_tile);
        try testing.expect(positionApproxEq(expected_position, actual_position, tolerance_f32));
    }
}

pub fn tilePositionEq(a: Components.Tile, b: Components.Tile) bool {
    return a.x == b.x and a.y == b.y;
}

test "Pixel position to Tile position" {
    const positions = [_]Components.Position{
        .{ .x = 19, .y = 39 },
        .{ .x = 57, .y = -27 },
        .{ .x = -374, .y = 140 },
        .{ .x = 169, .y = 76 },
    };

    const expected_tiles = [_]Components.Tile{
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = 0 },
        .{ .x = -9, .y = 3 },
        .{ .x = 3, .y = 2 },
    };

    for (positions, expected_tiles) |position, expected_tile| {
        const actual_tile = pixelToTileCoords(position);
        try testing.expect(tilePositionEq(expected_tile, actual_tile));
    }
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

/// Returns true if the card is the front card of the stack
pub fn isFrontCard(gamestate: *GameState, pos: Components.Position, entity_pos_to_check: Components.Position) bool {
    var min_pos: Components.Position = .{ .x = std.math.floatMax(f32), .y = std.math.floatMax(f32) };
    var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Stack }, .{});
    var entityIter = view.entityIterator();
    while (entityIter.next()) |entity| {
        const entity_pos = view.getConst(Components.Position, entity);
        if (positionWithinArea(.{ .x = pos.x, .y = pos.y}, entity_pos)){
            min_pos.y = @min(min_pos.y, entity_pos.y);
        }
    }

    if (min_pos.y == entity_pos_to_check.y) {
        return true;
    }

    return false;
}

pub fn positionsEqual(a: Components.Position, b: Components.Position) bool {
    return a.x == b.x and a.y == b.y;
}

/// Determines the lowest position in a pile of cards
/// Used to determine moveable cards
/// Returns floatMax of f32 if no cards are found
pub fn lowestPositionInPile(gamestate: *GameState, pos: Components.Position) Components.Position {
    var min_pos: Components.Position = .{ .x = pos.x, .y = std.math.floatMax(f32) };
    var view = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Stack }, 
    .{ Components.CardInFoundationPile, Components.FoundationPile });
    var entityIter = view.entityIterator();
    while (entityIter.next()) |entity| {
        const entity_pos = view.getConst(Components.Position, entity);
        if (entity_pos.x == pos.x) {
            min_pos.y = @min(min_pos.y, entity_pos.y);
        }
        // if (positionWithinArea(.{ .x = pos.x, .y = pos.y}, entity_pos)){
        //     min_pos.y = @min(min_pos.y, entity_pos.y);
        // }
    }

    return min_pos;
}

/// Determines the highest card value in a foundation pile
/// 0 means no card found
pub fn highestValueCardInFoundation(gamestate: *GameState, foundation_pos: Components.Position) u8 {
    var max_value: u8 = 0;
    var view_cards = gamestate.world.view(.{ Components.Position, Components.Tile, Components.CardSuit, Components.CardValue, Components.Stack }, .{});
    var entity_card_Iter = view_cards.entityIterator();
    while (entity_card_Iter.next()) |entity| {
        const card_value = view_cards.getConst(Components.CardValue, entity);
        const card_pos = view_cards.getConst(Components.Position, entity);
        if (positionsEqual(card_pos, foundation_pos)) {
            max_value = @max(max_value, @intFromEnum(card_value));
        }
    }

    return max_value;
}