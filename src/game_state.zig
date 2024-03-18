const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("mach").core;
const gpu = core.gpu;
const ecs = @import("zig-ecs");
const AssetManager = @import("gfx/asset_manager.zig").AssetManager;

const assets_directory = "../../assets";

pub const GameState = struct {
    allocator: Allocator = undefined,
    delta_time: f32 = 0.0,
    game_time: f32 = 0.0,
    world: *ecs.Registry = undefined,
    pipeline_default: *gpu.RenderPipeline = undefined,
    bind_group_default: *gpu.BindGroup = undefined,
    uniform_buffer_default: *gpu.Buffer = undefined,
    asset_manager: *AssetManager = undefined,

    pub fn init(allocator: Allocator) !*GameState {
        var self = try allocator.create(GameState);
        self.allocator = allocator;
        self.asset_manager = try AssetManager.initFromDirectory(allocator, assets_directory);
        return self;
    }

    pub fn deinit(self: *GameState) void {
        self.asset_manager.deinit();
        self.allocator.destroy(self);
    }
};