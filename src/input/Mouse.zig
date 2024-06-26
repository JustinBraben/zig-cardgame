const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const zmath = @import("zmath");
const utils = @import("../utils.zig");
const game = @import("../main.zig");
const core = @import("mach").core;

const ecs = @import("zig-ecs");

const builtin = @import("builtin");

const Mods = core.KeyMods;
const MouseButton = core.MouseButton;

const Self = @This();

pub const ButtonState = enum {
    press,
    release,
};

pub const Button = struct {
    button: MouseButton,
    mods: ?Mods = null,
    action: Action,
    state: bool = false,
    previous_state: bool = false,
    pressed_position: [2]f32 = .{ 0.0, 0.0 },
    released_position: [2]f32 = .{ 0.0, 0.0 },
    pressed_tile: [2]i32 = .{ 0, 0 },
    released_tile: [2]i32 = .{ 0, 0 },
    pressed_mods: Mods = std.mem.zeroes(Mods),
    released_mods: Mods = std.mem.zeroes(Mods),

    /// Returns true the frame the key was pressed.
    pub fn pressed(self: Button) bool {
        return (self.state == true and self.state != self.previous_state);
    }

    /// Returns true while the key is pressed down.
    pub fn down(self: Button) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released(self: Button) bool {
        return (self.state == false and self.state != self.previous_state);
    }

    /// Returns true while the key is released.
    pub fn up(self: Button) bool {
        return self.state == false;
    }
};

pub const Action = enum {
    primary,
    secondary,
};

buttons: []Button,
position: [2]f32 = .{ 0.0, 0.0 },
previous_position: [2]f32 = .{ 0.0, 0.0 },
scroll_x: ?f32 = null,
scroll_y: ?f32 = null,

pub fn button(self: *Self, action: Action) ?*Button {
    for (self.buttons) |*current_button| {
        if (current_button.action == action) {
            return current_button;
        }
    }
    return null;
}

test "Button testing" {
    const testing_allocator = testing.allocator;
    var buttons = try initDefault(testing_allocator);
    defer testing_allocator.free(buttons.buttons);

    try testing.expectEqual(2, buttons.buttons.len);

    try testing.expect(buttons.button(.primary) != null);
    try testing.expect(buttons.button(.secondary) != null);

    var btn = buttons.button(.primary);
    try testing.expectEqual(buttons.button(.primary), btn.?);

    btn = buttons.button(.secondary);
    try testing.expectEqual(buttons.button(.secondary), btn.?);
}

pub fn tile(self: *Self) [2]i32 {
    const world_position = game.state.camera.screenToWorld(zmath.f32x4(self.position[0], self.position[1], 0, 0));
    const current_tile = utils.pixelToTileCoords(.{ .x = world_position[0], .y = world_position[1] });
    return .{
        current_tile.x,
        current_tile.y,
    };
}

pub fn setButtonState(self: *Self, b: MouseButton, mods: Mods, state: ButtonState) void {
    for (self.buttons) |*bt| {
        if (bt.button == b) {
            const world_position = game.state.camera.screenToWorld(zmath.f32x4(self.position[0], self.position[1], 0, 0));
            const current_tile = utils.pixelToTileCoords(.{ .x = world_position[0], .y = world_position[1] });
            if (state == .release or bt.mods == null) {
                bt.previous_state = bt.state;
                switch (state) {
                    .press => {
                        bt.state = true;
                        bt.pressed_mods = mods;
                        bt.pressed_position[0] = world_position[0];
                        bt.pressed_position[1] = world_position[1];
                        bt.pressed_tile[0] = current_tile.x;
                        bt.pressed_tile[1] = current_tile.y;
                    },
                    else => {
                        bt.state = false;
                        bt.released_mods = mods;
                        bt.released_position[0] = world_position[0];
                        bt.released_position[1] = world_position[1];
                        bt.released_tile[0] = current_tile.x;
                        bt.released_tile[1] = current_tile.y;
                    },
                }
            } else if (bt.mods) |md| {
                if (@as(u8, @bitCast(md)) == @as(u8, @bitCast(mods))) {
                    bt.previous_state = bt.state;
                    switch (state) {
                        .press => {
                            bt.state = true;
                            bt.pressed_mods = mods;
                            bt.pressed_tile[0] = current_tile.x;
                            bt.pressed_tile[1] = current_tile.y;
                        },
                        else => {
                            bt.state = false;
                            bt.released_mods = mods;
                            bt.released_tile[0] = current_tile.x;
                            bt.released_tile[1] = current_tile.y;
                        },
                    }
                }
            }

            // Debug
            // std.debug.print("Mouse pressed at this position, x : {}, y : {}\n", .{ self.position[0], self.position[1] });
            // std.debug.print("Mouse pressed at this world position, x : {}, y : {}\n", .{world_position[0], world_position[1]});
            // const current_tile = utils.pixelToTileCoords(.{ .x = world_position[0], .y = world_position[1] });
            // std.debug.print("Tile pressed : x {}, y {}\n", .{current_tile.x, current_tile.y});
            // std.debug.print("Tile pressed : x {}, y {}\n", .{utils.tile(world_position[0]), utils.tile(world_position[1])});
        }
    }
}

pub fn initDefault(allocator: std.mem.Allocator) !Self {
    var buttons = std.ArrayList(Button).init(allocator);

    {
        try buttons.append(.{
            .button = MouseButton.left,
            .action = Action.primary,
        });

        try buttons.append(.{
            .button = MouseButton.right,
            .action = Action.secondary,
        });
    }

    return .{ .buttons = try buttons.toOwnedSlice() };
}