pub const std = @import("std");
pub const Components = @import("ecs/components/components.zig");
pub const settings = @import("settings.zig");

/// Converts tile to pixel coordinates
pub fn tileToPixelCoords(self: Components.Tile) Components.Position {
    // TODO: This should multiply by the tile size. 
    return .{
        .x = @as(f32, @floatFromInt(self.x)) * settings.pixels_per_unit,
        .y = @as(f32, @floatFromInt(self.y)) * settings.pixels_per_unit,
    };
}

/// Converts pixel to tile coordinates
pub fn pixelToTileCoords(self: Components.Position) Components.Tile {
    return .{
        .x = @as(i32, @intFromFloat(@round(self.x / settings.pixels_per_unit))),
        .y = @as(i32, @intFromFloat(@round(self.y / settings.pixels_per_unit))),
    };
}