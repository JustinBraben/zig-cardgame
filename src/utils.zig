pub const std = @import("std");
pub const Components = @import("ecs/components/components.zig");
pub const settings = @import("settings.zig");
const game = @import("main.zig");

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

    const half_width = @as(f32, @floatFromInt(game.settings.window_width / 2));
    const half_height = @as(f32, @floatFromInt(game.settings.window_height / 2));
    const tile_pos_x = @as(f32, @floatFromInt(self.x)) * game.settings.pixels_per_unit;
    const tile_pos_y = @as(f32, @floatFromInt(self.y)) * game.settings.pixels_per_unit;

    return .{
        .x = tile_pos_x / half_width,
        .y = tile_pos_y / half_height,
    };
}

/// Converts pixel to tile coordinates
pub fn pixelToTileCoords(self: Components.Position) Components.Tile {
    const half_width = @as(f32, @floatFromInt(game.settings.window_width / 2));
    const half_height = @as(f32, @floatFromInt(game.settings.window_height / 2));
    const tile_pos_x = @divFloor((self.x - half_width), game.settings.pixels_per_unit);
    const tile_pos_y = @divFloor((half_height - self.y), game.settings.pixels_per_unit);

    return .{
        .x = @as(i32, @intFromFloat(tile_pos_x)),
        .y = @as(i32, @intFromFloat(tile_pos_y)),
    };
}

pub fn tile(p: f32) i32 {
    return @as(i32, @intFromFloat(@round(p / game.settings.pixels_per_unit)));
}

test "Tile position to pixel position" {
    const tile_1 = Components.Tile{ .x = 0, .y = 0 };
    const tile_2 = Components.Tile{ .x = 2, .y = 0 };
    const tile_3 = Components.Tile{ .x = 0, .y = -3 };
    const tile_4 = Components.Tile{ .x = 0, .y = 4 };
    const tile_5 = Components.Tile{ .x = -5, .y = -5 };

    const pos_1 = Components.Position{ .x = 0, .y = 0 };
    const pos_2 = Components.Position{ .x = 0.05, .y = 0};
    const pos_3 = Components.Position{ .x = 0, .y = -0.125 };
    const pos_4 = Components.Position{ .x = 0, .y = 0.166666671 };
    const pos_5 = Components.Position{ .x = -0.125, .y = -0.208333328 };
    
    try std.testing.expectEqual(pos_1, tileToPixelCoords(tile_1));
    try std.testing.expectEqual(pos_2, tileToPixelCoords(tile_2));
    try std.testing.expectEqual(pos_3, tileToPixelCoords(tile_3));
    try std.testing.expectEqual(pos_4, tileToPixelCoords(tile_4));
    try std.testing.expectEqual(pos_5, tileToPixelCoords(tile_5));
}