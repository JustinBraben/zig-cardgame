const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Sprite = @import("sprite.zig").Sprite;
const Animation = @import("animation.zig").Animation;
const zigimg = @import("zigimg");

pub const AssetManager = struct {
    allocator: Allocator,
    sprites: []Sprite = undefined,
    animations: []Animation = undefined,

    /// Pass the AssetManager the directory containing your assets
    pub fn initFromDirectory(allocator: Allocator, directoryPath: []const u8) !AssetManager {
        const real_directory_path = try std.fs.realpathAlloc(allocator, directoryPath);
        defer allocator.free(real_directory_path);

        // const file = try std.fs.openFileAbsolute(real_directory_path, .{ .mode = .read_only });
        // defer file.close();

        var assets_directory = std.fs.openDirAbsolute(real_directory_path, .{ .iterate = true }) catch |err| {
            return err;
        };
        defer assets_directory.close();

        var files = assets_directory.walk(allocator) catch |err| {
            return err;
        };
        defer files.deinit();
        while(try files.next()) |file| {
            std.debug.print("file path : {s} , base name : {s}\n", .{file.path, file.basename});
            // var img = try zigimg.Image.fromFilePath(allocator, file.path);
            // defer img.deinit();
        }

        return .{
            .allocator = allocator,
        };
    }
};