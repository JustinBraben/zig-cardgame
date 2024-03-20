const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.game_state);
const core = @import("mach").core;
const gpu = core.gpu;
const ecs = @import("zig-ecs");
const zmath = @import("zmath");
const zigimg = @import("zigimg");
const Registry = ecs.Registry;
const AssetManager = @import("gfx/asset_manager.zig").AssetManager;
const Components = @import("ecs/components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;
const Prefabs = @import("ecs/prefabs.zig").Prefabs;
pub const gfx = @import("gfx/gfx.zig");
pub const shaders = @import("shaders.zig");

const assets_directory = "../../assets";

const Vertex = struct {
    pos: @Vector(2, f32),
    uv: @Vector(2, f32),
};

const vertices = [_]Vertex{
    .{ .pos = .{ -0.5, -0.5 }, .uv = .{ 1, 1 } },
    .{ .pos = .{ 0.5, -0.5 }, .uv = .{ 0, 1 } },
    .{ .pos = .{ 0.5, 0.5 }, .uv = .{ 0, 0 } },
    .{ .pos = .{ -0.5, 0.5 }, .uv = .{ 1, 0 } },
};

const index_data = [_]u32{ 0, 1, 2, 2, 3, 0 };

pub const GameState = struct {
    allocator: Allocator = undefined,
    delta_time: f32 = 0.0,
    game_time: f32 = 0.0,
    world: *Registry = undefined,
    pipeline_default: *gpu.RenderPipeline = undefined,
    vertex_buffer_default: *gpu.Buffer = undefined,
    index_buffer_default: *gpu.Buffer = undefined,
    bind_group_default: *gpu.BindGroup = undefined,
    // asset_manager: *AssetManager = undefined,

    pub fn init(allocator: Allocator) !*GameState {
        var self = try allocator.create(GameState);
        self.allocator = allocator;
        self.world = try allocator.create(Registry);
        self.world.* = Registry.init(allocator);

        const shader_module = core.device.createShaderModuleWGSL("textured-quad.wgsl", shaders.textured_quad);
        defer shader_module.release();

        const vertex_attributes = [_]gpu.VertexAttribute{
            .{ .format = .float32x4, .offset = @offsetOf(Vertex, "pos"), .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
        };
        const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
            .array_stride = @sizeOf(Vertex),
            .step_mode = .vertex,
            .attributes = &vertex_attributes,
        });

        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };
        const fragment = gpu.FragmentState.init(.{
            .module = shader_module,
            .entry_point = "frag_main",
            .targets = &.{color_target},
        });
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
            .fragment = &fragment,
            .vertex = gpu.VertexState.init(.{
                .module = shader_module,
                .entry_point = "vertex_main",
                .buffers = &.{vertex_buffer_layout},
            }),
            .primitive = .{ .cull_mode = .back },
        };
        const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

        const vertex_buffer = core.device.createBuffer(&.{
            .usage = .{ .vertex = true },
            .size = @sizeOf(Vertex) * vertices.len,
            .mapped_at_creation = .true,
        });
        const vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertices.len);
        @memcpy(vertex_mapped.?, vertices[0..]);
        vertex_buffer.unmap();

        const index_buffer = core.device.createBuffer(&.{
            .usage = .{ .index = true },
            .size = @sizeOf(u32) * index_data.len,
            .mapped_at_creation = .true,
        });
        const index_mapped = index_buffer.getMappedRange(u32, 0, index_data.len);
        @memcpy(index_mapped.?, index_data[0..]);
        index_buffer.unmap();

        const sampler = core.device.createSampler(&.{ .mag_filter = .linear, .min_filter = .linear });
        const queue = core.queue;

        const base_folder = try std.fs.realpathAlloc(allocator, "../../");
        defer allocator.free(base_folder);
        const png_relative_path = "assets/Cards_v2.png";
        const format = if (builtin.os.tag == .windows) "{s}\\{s}" else "{s}/{s}";
        const image_full_path = try std.fmt.allocPrint(self.allocator, format, .{ base_folder, png_relative_path });
        defer self.allocator.free(image_full_path);
        var img = try zigimg.Image.fromFilePath(allocator, image_full_path);
        defer img.deinit();
        const img_size = gpu.Extent3D{
            .width = @as(u32, @intCast(img.width)),
            .height = @as(u32, @intCast(img.height)),
        };
        const texture = core.device.createTexture(&.{
            .size = img_size,
            .format = .rgba8_unorm,
            .usage = .{
                .texture_binding = true,
                .copy_dst = true,
                .render_attachment = true,
            },
        });
        const data_layout = gpu.Texture.DataLayout{
                .bytes_per_row = @as(u32, @intCast(img.width * 4)),
                .rows_per_image = @as(u32, @intCast(img.height)),
        };
        switch (img.pixels) {
            .rgba32 => |pixels| queue.writeTexture(&.{ .texture = texture }, &data_layout, &img_size, pixels),
            .rgb24 => |pixels| {
                const data = try rgb24ToRgba32(allocator, pixels);
                defer data.deinit(allocator);
                queue.writeTexture(&.{ .texture = texture }, &data_layout, &img_size, data.rgba32);
            },
            else => @panic("unsupported image color format"),
        }

        const texture_view = texture.createView(&gpu.TextureView.Descriptor{});
        texture.release();

        const bind_group_layout = pipeline.getBindGroupLayout(0);
        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = bind_group_layout,
                .entries = &.{
                    gpu.BindGroup.Entry.sampler(0, sampler),
                    gpu.BindGroup.Entry.textureView(1, texture_view),
                },
            }),
        );
        sampler.release();
        texture_view.release();
        bind_group_layout.release();

        self.pipeline_default = pipeline;
        self.vertex_buffer_default = vertex_buffer;
        self.index_buffer_default = index_buffer;
        self.bind_group_default = bind_group;
        return self;
    }

    pub fn deinit(self: *GameState) void {
        self.pipeline_default.release();
        self.vertex_buffer_default.release();
        self.index_buffer_default.release();
        self.bind_group_default.release();
        self.allocator.destroy(self);
    }
};

fn rgb24ToRgba32(allocator: std.mem.Allocator, in: []zigimg.color.Rgb24) !zigimg.color.PixelStorage {
    const out = try zigimg.color.PixelStorage.init(allocator, .rgba32, in.len);
    var i: usize = 0;
    while (i < in.len) : (i += 1) {
        out.rgba32[i] = zigimg.color.Rgba32{ .r = in[i].r, .g = in[i].g, .b = in[i].b, .a = 255 };
    }
    return out;
}