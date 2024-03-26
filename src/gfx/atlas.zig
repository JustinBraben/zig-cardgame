const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Sprite = @import("sprite.zig").Sprite;
const Animation = @import("animation.zig").Animation;

pub const Atlas = struct {
    sprites: []Sprite,
    animations: []Animation,

    pub fn initFromFilePath(allocator: Allocator, filePath: []const u8) !Atlas {
        std.debug.print("Atlas, Opening file : {s}\n", .{filePath});

        const sprites_animations_file = try std.fs.cwd().openFile(filePath, .{ .mode = .read_only});
        defer sprites_animations_file.close();
        const file_size = (try sprites_animations_file.stat()).size;
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);
        try sprites_animations_file.reader().readNoEof(buffer);

        const options = std.json.ParseOptions{ .duplicate_field_behavior = .use_first, .ignore_unknown_fields = true };
        const parsed = std.json.parseFromSlice(Atlas, allocator, buffer, options) catch {
            try std.fs.cwd().writeFile("test.json", buffer);
            return error.ParsingFailed;
        };
        defer parsed.deinit();

        return .{
            .sprites = try allocator.dupe(Sprite, parsed.value.sprites),
            .animations = try allocator.dupe(Animation, parsed.value.animations),
        };
    }
};