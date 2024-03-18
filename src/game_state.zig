const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.game_state);
const core = @import("mach").core;
const gpu = core.gpu;
const ecs = @import("zig-ecs");
const Registry = ecs.Registry;
const AssetManager = @import("gfx/asset_manager.zig").AssetManager;
const Components =  @import("ecs/components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;
const Prefabs = @import("ecs/prefabs.zig").Prefabs;

const assets_directory = "../../assets";

pub const GameState = struct {
    allocator: Allocator = undefined,
    delta_time: f32 = 0.0,
    game_time: f32 = 0.0,
    world: *Registry = undefined,
    prefabs: Prefabs = undefined,
    pipeline_default: *gpu.RenderPipeline = undefined,
    bind_group_default: *gpu.BindGroup = undefined,
    uniform_buffer_default: *gpu.Buffer = undefined,
    asset_manager: *AssetManager = undefined,

    pub fn init(allocator: Allocator) !*GameState {
        var self = try allocator.create(GameState);
        self.allocator = allocator;
        self.world = try allocator.create(Registry);
        self.world.* = Registry.init(allocator);
        self.prefabs = try Prefabs.init(allocator);
        self.prefabs.create(self.world);
        self.asset_manager = try AssetManager.initFromDirectory(allocator, assets_directory);

        // var view = self.world.view(.{ Position, CardSuit }, .{});
        // var iter = view.entityIterator();
        // while (iter.next()) |entity| {
        //     const position = view.getConst(Position, entity);
        //     std.debug.print("Position : {any}\n", .{position});
        // }

        return self;
    }

    pub fn deinit(self: *GameState) void {
        self.asset_manager.deinit();
        self.allocator.destroy(self);
    }
};