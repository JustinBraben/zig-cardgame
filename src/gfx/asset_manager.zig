const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.asset_manager);
const assert = std.debug.assert;
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
    pub fn init(allocator: Allocator) !AssetManager {
        return .{ .allocator = allocator, .texture_map = std.StringArrayHashMap(Texture).init(allocator) };
    }

    pub fn fillTextureMap(self: *AssetManager, directoryPath: []const u8) !void {
        const real_directory_path = try std.fs.realpathAlloc(self.allocator, directoryPath);
        defer self.allocator.free(real_directory_path);

        var assets_directory = std.fs.openDirAbsolute(real_directory_path, .{ .iterate = true }) catch |err| {
            return err;
        };
        defer assets_directory.close();

        var files = assets_directory.walk(self.allocator) catch |err| {
            return err;
        };
        defer files.deinit();

        while (try files.next()) |file| {
            // var img = try zigimg.Image.fromFilePath(allocator, file.path);
            // defer img.deinit();
            if (std.mem.endsWith(u8, file.path, ".png")) {
                const format = if (builtin.os.tag == .windows) "{s}\\{s}" else "{s}/{s}";
                const full_path = try std.fmt.allocPrint(self.allocator, format, .{ real_directory_path, file.basename });
                defer self.allocator.free(full_path);
                // std.debug.print("full path : {s}\n", .{full_path});
                // std.debug.print("file path : {s}, base : {s}\n", .{file.path, file.basename});
                var trimmed_basename = std.mem.splitScalar(u8, file.basename, '.');
                try self.texture_map.put(try self.allocator.dupe(u8, trimmed_basename.first()), try Texture.loadFromFilePath(self.allocator, full_path, .{}));
            }
        }
    }

    pub fn deinit(self: *AssetManager) void {
        for (self.texture_map.keys()) |key| {
            std.debug.print("Freeing asset : {s}\n", .{key});
            self.allocator.free(key);
        }

        self.texture_map.clearAndFree();
    }
};
