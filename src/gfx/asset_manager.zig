const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Sprite = @import("sprite.zig").Sprite;
const Animation = @import("animation.zig").Animation;
const zigimg = @import("zigimg");
const Texture = @import("texture.zig").Texture;

pub const AssetManager = struct {
    allocator: Allocator,
    sprites: []Sprite = undefined,
    animations: []Animation = undefined,
    texture_map: std.StringArrayHashMap(Texture) = undefined,

    /// Pass the AssetManager the directory containing your assets
    pub fn initFromDirectory(allocator: Allocator, directoryPath: []const u8) !*AssetManager {
        const real_directory_path = try std.fs.realpathAlloc(allocator, directoryPath);
        defer allocator.free(real_directory_path);

        var assets_directory = std.fs.openDirAbsolute(real_directory_path, .{ .iterate = true }) catch |err| {
            return err;
        };
        defer assets_directory.close();

        var files = assets_directory.walk(allocator) catch |err| {
            return err;
        };
        defer files.deinit();

        var self = try allocator.create(AssetManager);
        self.allocator = allocator;
        self.texture_map = std.StringArrayHashMap(Texture).init(allocator);

        while(try files.next()) |file| {
            // var img = try zigimg.Image.fromFilePath(allocator, file.path);
            // defer img.deinit();
            if (std.mem.endsWith(u8, file.path, ".png")) {
                const full_path = try std.fmt.allocPrint(allocator, "{s}\\{s}", .{real_directory_path, file.basename});
                defer allocator.free(full_path);
                try self.texture_map.put(
                    try allocator.dupe(u8, file.basename), 
                    try Texture.loadFromFilePath(allocator, full_path, .{})
                );
            }
        }

        try self.texture_map.reIndex();

        return self;
    }

    pub fn deinit(self: *AssetManager) void {
        
        for (self.texture_map.keys()) |key| {
            std.debug.print("Freeing asset : {s}\n", .{key});
            self.allocator.free(key);
        }

        self.texture_map.clearAndFree();
    }
};