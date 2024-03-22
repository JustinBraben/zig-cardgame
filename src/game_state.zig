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
const Components = @import("ecs/components/components.zig");
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

pub const UniformBufferObject = struct {
    mvp: zmath.Mat,
};

const vertices = [_]Vertex{
    .{ .pos = .{ 0.5, 0.5 }, .uv = .{ 1, 0 } },    // bottom-left
    .{ .pos = .{ -0.5, 0.5 }, .uv = .{ 0, 0 } },   // bottom-right
    .{ .pos = .{ -0.5, -0.5 }, .uv = .{ 0, 1 } },  // top-right
    .{ .pos = .{ 0.5, -0.5 }, .uv = .{ 1, 1 } },   // top-left
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
    uniform_buffer_default: *gpu.Buffer = undefined,
    batcher: gfx.Batcher = undefined,
    default_texture: gfx.Texture = undefined,

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
        const default_fragment = gpu.FragmentState.init(.{
            .module = shader_module,
            .entry_point = "frag_main",
            .targets = &.{color_target},
        });
        const default_vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vertex_main",
            .buffers = &.{vertex_buffer_layout},
        });
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
            .fragment = &default_fragment,
            .vertex = default_vertex,
            // .primitive = .{ .cull_mode = .back },
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

        const base_folder = try std.fs.realpathAlloc(allocator, "../../");
        defer allocator.free(base_folder);
        const png_relative_path = "assets/Cards_v2.png";
        // const png_relative_path = "assets/cards.png";
        const format = if (builtin.os.tag == .windows) "{s}\\{s}" else "{s}/{s}";
        const image_full_path = try std.fmt.allocPrint(self.allocator, format, .{ base_folder, png_relative_path });
        defer self.allocator.free(image_full_path);

        self.default_texture = try gfx.Texture.loadFromFilePath(
            self.allocator,
            image_full_path, .{ .format = core.descriptor.format }
        );

        const texture_view = self.default_texture.handle.createView(&gpu.TextureView.Descriptor{});

        const bind_group_layout = pipeline.getBindGroupLayout(0);
        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = bind_group_layout,
                .entries = &.{
                    gpu.BindGroup.Entry.sampler(0, self.default_texture.sampler_handle),
                    gpu.BindGroup.Entry.textureView(1, texture_view),
                },
            }),
        );

        self.uniform_buffer_default = core.device.createBuffer(&.{
            .usage = . { .copy_dst = true, .uniform = true},
            .size = @sizeOf(UniformBufferObject),
            .mapped_at_creation = .false,
        });
        // const uniforms = gfx.UniformBufferObject{
        //     .mvp = zmath.transpose(
        //         zmath.orthographicRh(
        //             @as(f32, @floatFromInt(core.size().width)),
        //             @as(f32, @floatFromInt(core.size().height)), 
        //             0.1, 
        //             1000
        //         )
        //     ),
        // };

        self.batcher = try gfx.Batcher.init(allocator, 1);
        // try self.batcher.begin(.{
        //     .pipeline_handle = pipeline,
        //     .bind_group_handle = bind_group,
        //     .output_handle = texture_view,
        //     .clear_color = .{ .r = 0.52, .g = 0.8, .b = 0.92, .a = 1.0 },
        // });
        // std.debug.print("Batcher vertices before adding texture : {any}\n", .{self.batcher.vertices.len});
        // try self.batcher.texture(zmath.f32x4s(0), &self.default_texture, .{});
        // try self.batcher.end(uniforms, self.uniform_buffer_default);
        // std.debug.print("Batcher vertices after adding texture : {any}\n", .{self.batcher.vertices.len});
        // std.debug.print("Batcher vertices after adding texture : {any}\n", .{self.batcher.vertices});
        texture_view.release();
        bind_group_layout.release();

        self.pipeline_default = pipeline;
        self.vertex_buffer_default = vertex_buffer;
        self.index_buffer_default = index_buffer;
        self.bind_group_default = bind_group;
        return self;
    }

    pub fn render(self: *GameState) void {
        if (core.swap_chain.getCurrentTextureView()) |back_buffer_view| {
            // Clear color for the background
            const color_attachment = gpu.RenderPassColorAttachment{
                .view = back_buffer_view,
                // sky blue background color:
                .clear_value = .{ .r = 0.52, .g = 0.8, .b = 0.92, .a = 1.0 },
                .load_op = .clear,
                .store_op = .store,
            };

            const encoder = core.device.createCommandEncoder(null);
            const render_pass_info = gpu.RenderPassDescriptor.init(.{
                .color_attachments = &.{color_attachment},
            });

            const pass = encoder.beginRenderPass(&render_pass_info);
            pass.setPipeline(self.pipeline_default);
            pass.setVertexBuffer(0, self.vertex_buffer_default, 0, @sizeOf(Vertex) * vertices.len);
            pass.setIndexBuffer(self.index_buffer_default, .uint32, 0, @sizeOf(u32) * index_data.len);
            pass.setBindGroup(0, self.bind_group_default, &.{});
            pass.drawIndexed(index_data.len, 1, 0, 0, 0);
            pass.end();
            pass.release();

            var command = encoder.finish(null);
            encoder.release();

            const queue = core.queue;
            queue.submit(&[_]*gpu.CommandBuffer{command});
            command.release();
            core.swap_chain.present();
            back_buffer_view.release();
        }
    }

    pub fn renderUsingBatch(self: *GameState) !void {
        const texture_view = self.default_texture.handle.createView(&gpu.TextureView.Descriptor{});
        const uniforms = gfx.UniformBufferObject{
        .mvp = zmath.transpose(
                zmath.orthographicRh(
                    @as(f32, @floatFromInt(core.size().width)),
                    @as(f32, @floatFromInt(core.size().height)),
                    0.1,
                    1000
                )
            ),
        };

        const position = zmath.f32x4(0.5, -0.5, -0.5, 0.5);
        // _ = position;

        try self.batcher.begin(.{
            .pipeline_handle = self.pipeline_default,
            .bind_group_handle = self.bind_group_default,
            .output_handle = texture_view,
            .clear_color = .{ .r = 0.52, .g = 0.8, .b = 0.92, .a = 1.0 },
        });
        try self.batcher.texture(position, &self.default_texture, .{});
        try self.batcher.end(uniforms, self.uniform_buffer_default);

        var batcher_commands = try self.batcher.finish();
        
        core.queue.submit(&[_]*gpu.CommandBuffer{batcher_commands});
        batcher_commands.release();
        core.swap_chain.present();
    }

    pub fn deinit(self: *GameState) void {
        self.pipeline_default.release();
        self.vertex_buffer_default.release();
        self.index_buffer_default.release();
        self.bind_group_default.release();
        self.uniform_buffer_default.release();
        self.default_texture.deinit();
        self.batcher.deinit();
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