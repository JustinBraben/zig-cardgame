const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.batcher);
const assert = std.debug.assert;
const zmath = @import("zmath");
const core = @import("mach").core;
const gpu = core.gpu;
const GameState = @import("../game_state.zig").GameState;
const game = @import("../main.zig");

pub const Animation = @import("animation.zig").Animation;
pub const Assetmanager = @import("asset_manager.zig").AssetManager;
pub const Batcher = @import("batcher.zig").Batcher;
pub const Texture = @import("texture.zig").Texture;
pub const Camera = @import("Camera.zig").Camera;

pub const Vertex = struct {
    position: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
    uv: [2]f32 = [_]f32{ 0.0, 0.0 },
    color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 },
    data: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
};

pub const UniformBufferObject = struct {
    mvp: zmath.Mat,
};

pub fn init(state: *GameState) !void {
    const default_shader_module = core.device.createShaderModuleWGSL("shader.wgsl", game.shaders.default);

    defer default_shader_module.release();

    const blend = gpu.BlendState{
        .color = .{
            .operation = .add,
            .src_factor = .src_alpha,
            .dst_factor = .one_minus_src_alpha,
        },
        .alpha = .{
            .operation = .add,
            .src_factor = .src_alpha,
            .dst_factor = .one_minus_src_alpha,
        },
    };

    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };

    const default_fragment = gpu.FragmentState.init(.{
        .module = default_shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &default_fragment,
        .vertex = gpu.VertexState.init(.{
            .module = default_shader_module,
            .entry_point = "vertex_main",
        })
    };

    state.pipeline_default = core.device.createRenderPipeline(&pipeline_descriptor);

    state.uniform_buffer_default = core.device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(UniformBufferObject),
        .mapped_at_creation = .false,
    });

    // const pipeline_layout_default = state.pipeline_default.getBindGroupLayout(0);

    // const sampler = core.device.createSampler(&.{
    //     .mag_filter = .linear,
    //     .min_filter = .linear,
    // });

    // state.bind_group_default = core.device.createBindGroup(
    //     &gpu.BindGroup.Descriptor.init(.{
    //         .layout = pipeline_layout_default,
    //         .entries = &.{
    //             gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)),
    //             gpu.BindGroup.Entry.sampler(1, sampler),
    //             gpu.BindGroup.Entry.textureView(2, texture_view),
    //             gpu.BindGroup.Entry.buffer(3, sprites_buffer, 0, @sizeOf(Sprite) * app.sprites.items.len),
    //         }
    //     })
    // )
}