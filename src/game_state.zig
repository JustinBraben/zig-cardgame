const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("mach").core;
const gpu = core.gpu;
const ecs = @import("zig-ecs");

pub const GameState = struct {
    allocator: Allocator = undefined,
    delta_time: f32 = 0.0,
    game_time: f32 = 0.0,
    world: *ecs.Registry = undefined,
    pipeline_default: *gpu.RenderPipeline = undefined,
    bind_group_default: *gpu.BindGroup = undefined,
    uniform_buffer_default: *gpu.Buffer = undefined,

    pub fn init(allocator: Allocator) !*GameState {
        var self = try allocator.create(GameState);
        self.allocator = allocator;
        return self;
    }

    pub fn deinit(self: *GameState) void {
        self.allocator.destroy(self);
    }
};