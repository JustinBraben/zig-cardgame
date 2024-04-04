const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const zmath = @import("zmath");
const game = @import("../main.zig");
const core = @import("mach").core;

const Key = core.Key;
const Mods = core.KeyMods;

const Self = @This();

pub const KeyState = enum(u32) {
    press,
    repeat,
    release,
};

pub const Action = enum(u32) {
    directional_up,
    directional_down,
    directional_right,
    directional_left,
    scanner,
    inspect,
    new_game,
};

hotkeys: []Hotkey,

pub const Hotkey = struct {
    shortcut: [:0]const u8 = undefined,
    key: core.Key,
    mods: ?Mods = null,
    action: Action,
    state: bool = false,
    previous_state: bool = false,

    /// Returns true the frame the key was pressed.
    pub fn pressed(self: Hotkey) bool {
        return (self.state == true and self.state != self.previous_state);
    }

    /// Returns true while the key is pressed down.
    pub fn down(self: Hotkey) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released(self: Hotkey) bool {
        return (self.state == false and self.state != self.previous_state);
    }

    /// Returns true while the key is released.
    pub fn up(self: Hotkey) bool {
        return self.state == false;
    }
};

pub fn hotkey(self: *Self, action: Action) ?*Hotkey {
    var found: ?*Hotkey = null;
    for (self.hotkeys) |*hk| {
        if (hk.action == action) {
            if (hk.state or found == null) {
                found = hk;
            }
        }
    }
    return found;
}

test "Hotkey testing" {
    const testing_allocator = testing.allocator;
    var hotkeys = try initDefault(testing_allocator);
    defer testing_allocator.free(hotkeys.hotkeys);

    try testing.expectEqual(11, hotkeys.hotkeys.len);

    try testing.expect(hotkeys.hotkey(.directional_up) != null);
    try testing.expect(hotkeys.hotkey(.directional_down) != null);
    try testing.expect(hotkeys.hotkey(.directional_right) != null);
    try testing.expect(hotkeys.hotkey(.directional_left) != null);
    try testing.expect(hotkeys.hotkey(.scanner) != null);
    try testing.expect(hotkeys.hotkey(.inspect) != null);
    try testing.expect(hotkeys.hotkey(.new_game) != null);

    var hk = hotkeys.hotkey(.new_game);
    try testing.expectEqual(hotkeys.hotkey(.new_game), hk.?);

    hk = hotkeys.hotkey(.directional_up);
    try testing.expectEqual(hotkeys.hotkey(.directional_up), hk.?);
}

pub fn setHotkeyState(self: *Self, k: Key, mods: Mods, state: KeyState) void {
    for (self.hotkeys) |*hk| {
        if (hk.key == k) {
            if (state == .release or hk.mods == null) {
                hk.previous_state = hk.state;
                hk.state = switch (state) {
                    .release => false,
                    else => true,
                };
            } else if (hk.mods) |md| {
                if (@as(u8, @bitCast(md)) == @as(u8, @bitCast(mods))) {
                    hk.previous_state = hk.state;
                    hk.state = switch (state) {
                        .release => false,
                        else => true,
                    };
                }
            }
        }
    }
}

pub fn initDefault(allocator: std.mem.Allocator) !Self {
    var hotkeys = std.ArrayList(Hotkey).init(allocator);

    // const os = builtin.target.os.tag;
    // const windows = os == .windows;
    // const macos = os == .macos;

    {
        try hotkeys.append(.{
            .shortcut = "up arrow",
            .key = Key.up,
            .action = .directional_up,
        });

        try hotkeys.append(.{
            .shortcut = "down arrow",
            .key = Key.down,
            .action = .directional_down,
        });

        try hotkeys.append(.{
            .shortcut = "left arrow",
            .key = Key.left,
            .action = .directional_left,
        });

        try hotkeys.append(.{
            .shortcut = "right arrow",
            .key = Key.right,
            .action = .directional_right,
        });

        try hotkeys.append(.{
            .shortcut = "w",
            .key = Key.w,
            .action = .directional_up,
        });

        try hotkeys.append(.{
            .shortcut = "s",
            .key = Key.s,
            .action = .directional_down,
        });

        try hotkeys.append(.{
            .shortcut = "a",
            .key = Key.a,
            .action = .directional_left,
        });

        try hotkeys.append(.{
            .shortcut = "d",
            .key = Key.d,
            .action = .directional_right,
        });

        try hotkeys.append(.{
            .shortcut = "r",
            .key = Key.r,
            .action = .new_game
        });

        try hotkeys.append(.{
            .shortcut = "tab",
            .key = Key.tab,
            .action = .scanner,
        });

        try hotkeys.append(.{
            .shortcut = "left shift",
            .key = Key.left_shift,
            .action = .inspect,
            .mods = .{
                .alt = false,
                .caps_lock = false,
                .control = false,
                .shift = true,
                .num_lock = false,
                .super = false,
            },
        });
    }

    return .{ .hotkeys = try hotkeys.toOwnedSlice() };
}