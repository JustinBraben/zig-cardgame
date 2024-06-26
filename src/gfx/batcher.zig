const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.batcher);
const assert = std.debug.assert;
const zmath = @import("zmath");
const game = @import("../main.zig");
const gfx = game.gfx;
const core = @import("mach").core;
const gpu = core.gpu;

// const vertices = [_]gfx.Vertex{
//     .{ .pos = .{ 0.5, 0.5 }, .uv = .{ 1, 0 } },    // bottom-left
//     .{ .pos = .{ -0.5, 0.5 }, .uv = .{ 0, 0 } },   // bottom-right
//     .{ .pos = .{ -0.5, -0.5 }, .uv = .{ 0, 1 } },  // top-right
//     .{ .pos = .{ 0.5, -0.5 }, .uv = .{ 1, 1 } },   // top-left
// };

// const index_data = [_]u32{ 0, 1, 2, 2, 3, 0 };

pub const Batcher = struct {
    allocator: Allocator,
    encoder: ?*core.gpu.CommandEncoder = null,
    vertices: []gfx.Vertex,
    vertex_buffer_handle: *core.gpu.Buffer,
    indices: []u32,
    index_buffer_handle: *core.gpu.Buffer,
    context: Context = undefined,
    state: State = .idle,
    vert_index: usize = 0,
    quad_count: usize = 0,
    start_count: usize = 0,

    /// Contains instructions on pipeline and binding for the current batch
    pub const Context = struct {
        pipeline_handle: *gpu.RenderPipeline,
        bind_group_handle: *gpu.BindGroup,
        // If output handle is null, render to the back buffer
        // otherwise, render to offscreen texture view handle
        output_handle: ?*gpu.TextureView = null,
        clear_color: core.gpu.Color = .{ .r = 0.52, .g = 0.8, .b = 0.92, .a = 1.0 },
    };

    /// Describes the current state of the Batcher
    pub const State = enum {
        progress,
        idle,
    };

    pub fn init(allocator: Allocator, max_quads: usize) !Batcher {
        const vertices = try allocator.alloc(gfx.Vertex, max_quads * 4);
        var indices = try allocator.alloc(u32, max_quads * 6);

        // Arrange index buffer for quads
        var i: usize = 0;
        while (i < max_quads) : (i += 1) {
            indices[i * 2 * 3 + 0] = @as(u32, @intCast(i * 4 + 0));
            indices[i * 2 * 3 + 1] = @as(u32, @intCast(i * 4 + 1));
            indices[i * 2 * 3 + 2] = @as(u32, @intCast(i * 4 + 2));
            indices[i * 2 * 3 + 3] = @as(u32, @intCast(i * 4 + 2));
            indices[i * 2 * 3 + 4] = @as(u32, @intCast(i * 4 + 3));
            indices[i * 2 * 3 + 5] = @as(u32, @intCast(i * 4 + 0));
        }

        const vertex_buffer_descriptor = .{
            .usage = .{ .copy_dst = true, .vertex = true },
            .size = vertices.len * @sizeOf(gfx.Vertex),
        };

        const vertex_buffer_handle = core.device.createBuffer(&vertex_buffer_descriptor);

        const index_buffer_descriptor = .{
            .usage = .{ .copy_dst = true, .index = true },
            .size = indices.len * @sizeOf(u32),
        };

        const index_buffer_handle = core.device.createBuffer(&index_buffer_descriptor);

        return .{
            .allocator = allocator,
            .vertices = vertices,
            .vertex_buffer_handle = vertex_buffer_handle,
            .indices = indices,
            .index_buffer_handle = index_buffer_handle,
        };
    }

    pub fn begin(self: *Batcher, context: Context) !void {
        if (self.state == .progress) return error.BeginCalledTwice;
        self.context = context;
        self.state = .progress;
        self.start_count = self.quad_count;
        if (self.encoder == null) {
            // std.debug.print("batcher encoder is null, creating\n", .{});
            self.encoder = core.device.createCommandEncoder(null);
        }
    }

    /// Returns true if vertices array has room for another quad
    pub fn hasCapacity(self: *Batcher) bool {
        return self.quad_count * 4 < self.vertices.len - 1;
    }

    /// Attempts to resize the buffers to hold a larger capacity
    pub fn resize(self: *Batcher, max_quads: usize) !void {
        if (max_quads <= self.quad_count) {
            return error.BufferTooSmall;
        }

        self.vertices = try self.allocator.realloc(self.vertices, max_quads * 4);
        self.indices = try self.allocator.realloc(self.indices, max_quads * 6);

        // Arrange index buffer for quads
        var i: usize = 0;
        while (i < max_quads) : (i += 1) {
            self.indices[i * 2 * 3 + 0] = @as(u32, @intCast(i * 4 + 0));
            self.indices[i * 2 * 3 + 1] = @as(u32, @intCast(i * 4 + 1));
            self.indices[i * 2 * 3 + 2] = @as(u32, @intCast(i * 4 + 3));
            self.indices[i * 2 * 3 + 3] = @as(u32, @intCast(i * 4 + 1));
            self.indices[i * 2 * 3 + 4] = @as(u32, @intCast(i * 4 + 2));
            self.indices[i * 2 * 3 + 5] = @as(u32, @intCast(i * 4 + 3));
        }

        std.log.warn("Batcher buffers resized, previous size: {d} - new size: {d}", .{ self.quad_count, max_quads });

        self.vertex_buffer_handle.release();
        self.index_buffer_handle.release();

        const vertex_buffer_handle = core.device.createBuffer(&.{
            .usage = .{ .copy_dst = true, .vertex = true },
            .size = self.vertices.len * @sizeOf(gfx.Vertex),
        });

        const index_buffer_handle = core.device.createBuffer(&.{
            .usage = .{ .copy_dst = true, .index = true },
            .size = self.indices.len * @sizeOf(u32),
        });

        self.vertex_buffer_handle = vertex_buffer_handle;
        self.index_buffer_handle = index_buffer_handle;
    }

    /// Attempts to append a new quad to the Batcher's buffers.
    /// If the buffer is full, attempt to resize the buffer first.
    pub fn append(self: *Batcher, quad: gfx.Quad) !void {
        if (self.state == .idle) return error.CallBeginFirst;
        if (!self.hasCapacity()) try self.resize(self.quad_count * 2);

        for (quad.vertices) |vertex| {
            self.vertices[self.vert_index] = vertex;
            self.vert_index += 1;
        }

        self.quad_count += 1;
    }

    pub const TextureOptions = struct {
        color: zmath.F32x4 = zmath.f32x4s(1.0),
        flip_y: bool = false,
        flip_x: bool = false,
        data_0: f32 = 0.0,
        data_1: f32 = 0.0,
        data_2: f32 = 0.0,
    };

    /// Appends a quad at the passed position set to the size needed to render the target texture.
    pub fn texture(self: *Batcher, position: zmath.F32x4, t: *gfx.Texture, options: TextureOptions) !void {
        const width = @as(f32, @floatFromInt(t.image.width));
        const height = @as(f32, @floatFromInt(t.image.height));
        const pos = zmath.trunc(position);

        var color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
        zmath.store(&color, options.color, 4);

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        const quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ pos[0], pos[1] + height, pos[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Bl
                .{
                    .position = [3]f32{ pos[0] + width, pos[1] + height, pos[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, min },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Br
                .{
                    .position = [3]f32{ pos[0] + width, pos[1], pos[2] },
                    .uv = [2]f32{ if (options.flip_x) min else max, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tr
                .{
                    .position = [3]f32{ pos[0], pos[1], pos[2] },
                    .uv = [2]f32{ if (options.flip_x) max else min, max },
                    .color = color,
                    .data = [3]f32{ options.data_0, options.data_1, options.data_2 },
                }, //Tl
            },
        };

        return self.append(quad);
    }

    pub fn textureSquare(self: *Batcher, position: zmath.F32x4, size: [2]f32, options: TextureOptions) !void {
        // const width = size[0];
        // const height = size[1];

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{ .pos = .{ position[0], position[1] + size[1]}, .uv = .{ if (options.flip_x) max else min, min } },         // bottom-left
                .{ .pos = .{ position[0] + size[0], position[1] + size[1] }, .uv = .{ if (options.flip_x) min else max, min } },                  // bottom-right
                .{ .pos = .{ position[0] + size[0], position[1] }, .uv = .{ if (options.flip_x) min else max, max } },         // top-right
                .{ .pos = .{ position[0], position[1] }, .uv = .{ if (options.flip_x) max else min, max } },                  // top-left
            }
        };
        
        // Set viewport of quad to the sprite
        // Use this if you just want a specific part of the texture
        // Currently hardcoded for 96x32 texture
        const x = 0.0;
        const y = 0.0;
        const width = @as(f32, @floatFromInt(32));
        const height = @as(f32, @floatFromInt(64));
        const tex_width = @as(f32, @floatFromInt(592));
        const tex_height = @as(f32, @floatFromInt(592));
        quad.setViewport(x, y, height, width, tex_width, tex_height);

        return self.append(quad);
    }

    pub fn oldTexture(self: *Batcher, position: zmath.F32x4, t: *gfx.Texture, options: TextureOptions) !void {
        // const width = @as(f32, @floatFromInt(t.image.width));
        // const height = @as(f32, @floatFromInt(t.image.height));
        // const pos = zmath.trunc(position);
        // Top left is first 2 values, bottom right is last 2 values
        _ = t;
        const width = @abs(position[0] - position[2]);
        const height = @abs(position[1] - position[3]);
        _ = width;

        // std.debug.print("Texture position: {any}\n", .{ position });
        // std.debug.print("Texture position truncated: {any}\n", .{ pos });

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        // const vertices = [_]gfx.Vertex{
        //     .{ .pos = .{ 0.5, 0.5 }, .uv = .{ 1, 0 } },    // bottom-left
        //     .{ .pos = .{ -0.5, 0.5 }, .uv = .{ 0, 0 } },   // bottom-right
        //     .{ .pos = .{ -0.5, -0.5 }, .uv = .{ 0, 1 } },  // top-right
        //     .{ .pos = .{ 0.5, -0.5 }, .uv = .{ 1, 1 } },   // top-left
        // };

        // const index_data = [_]u32{ 0, 1, 2, 2, 3, 0 };

        const quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{ .pos = .{ position[0], position[1] + height }, .uv = .{ if (options.flip_x) min else max, min } }, // bottom-left
                .{ .pos = .{ position[2], position[3] }, .uv = .{ if (options.flip_x) max else min, min } }, // bottom-right
                .{ .pos = .{ position[2], position[3] - height }, .uv = .{ if (options.flip_x) max else min, max } }, // top-right
                .{ .pos = .{ position[0], position[1] }, .uv = .{ if (options.flip_x) min else max, max } }, // top-left
            },
        };

        // const quad = gfx.Quad{
        //     .vertices = [_]gfx.Vertex{
        //         .{ .pos = .{ pos[0], pos[1] + height}, .uv = [2]f32{ if (options.flip_x) max else min, min }},          //Bottom left
        //         .{ .pos = .{ pos[0] + width, pos[1] + height}, .uv = [2]f32{ if (options.flip_x) min else max, min }},  //Bottom right
        //         .{ .pos = .{ pos[0] + width, pos[1]}, .uv = [2]f32{ if (options.flip_x) min else max, max }},           //Top right
        //         .{ .pos = .{ pos[0], pos[1]}, .uv = [2]f32{ if (options.flip_x) max else min, max }},                   //Top left
        //     },
        // };

        return self.append(quad);
    }

    pub const SpriteOptions = struct {
        color: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
        flip_x: bool = false,
        flip_y: bool = false,
        scale: [2]f32 = .{ 1.0, 1.0 },
        vert_mode: VertRenderMode = .standard,
        frag_mode: FragRenderMode = .standard,
        time: f32 = 0.0,
        rotation: f32 = 0.0,

        pub const VertRenderMode = enum {
            standard,
            top_sway,
        };

        pub const FragRenderMode = enum {
            standard,
            palette,
        };
    };

    pub fn spriteNew(self: *Batcher, position: zmath.F32x4, t: *gfx.Texture, s: gfx.Sprite, options: SpriteOptions) !void {
        const x = @as(f32, @floatFromInt(s.source[0]));
        const y = @as(f32, @floatFromInt(s.source[1]));
        const width = @as(f32, @floatFromInt(s.source[2]));
        const height = @as(f32, @floatFromInt(s.source[3]));
        const width_transform = (width / @as(f32, @floatFromInt(game.settings.window_width))) * 2.0;
        const height_transform = (height / @as(f32, @floatFromInt(game.settings.window_height))) * 2.0;
        const tex_width = @as(f32, @floatFromInt(t.image.width));
        const tex_height = @as(f32, @floatFromInt(t.image.height));

        // std.debug.print("Sprite x : {}, y : {}, width : {}, height : {}\n", .{ x, y, width, height });
        // std.debug.print("Sprite width_transform : {}, height_transform : {}, tex_width : {}, tex_height : {}\n", .{ width_transform, height_transform, tex_width, tex_height});

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{  // top-left 
                    .position = .{ position[0], position[1] + height_transform}, 
                    .uv = .{ if (options.flip_x) max else min, min } 
                },
                .{  // top-right
                    .position = .{ position[0] + width_transform, position[1] + height_transform }, 
                    .uv = .{ if (options.flip_x) min else max, min } 
                },
                .{  // bottom-right 
                    .position = .{ position[0] + width_transform, position[1] }, 
                    .uv = .{ if (options.flip_x) min else max, max } 
                },
                .{  // bottom-left 
                    .position = .{ position[0], position[1] }, 
                    .uv = .{ if (options.flip_x) max else min, max } 
                },
            }
        };

        // Set viewport of quad to the sprite
        quad.setViewport(x, y, height, width, tex_width, tex_height);

        // Apply mirroring
        if (options.flip_x) quad.flipHorizontally();
        if (options.flip_y) quad.flipVertically();

        return self.append(quad);
    }

    /// Appends a quad to the batcher set to the size needed to render the target sprite from the target texture.
    pub fn sprite(self: *Batcher, position: zmath.F32x4, t: *gfx.Texture, s: gfx.Sprite, options: SpriteOptions) !void {
        const x = @as(f32, @floatFromInt(s.source[0]));
        const y = @as(f32, @floatFromInt(s.source[1]));
        const width = @as(f32, @floatFromInt(s.source[2]));
        const height = @as(f32, @floatFromInt(s.source[3]));
        const o_x = @as(f32, @floatFromInt(s.origin[0]));
        const o_y = @as(f32, @floatFromInt(s.origin[1]));
        const tex_width = @as(f32, @floatFromInt(t.image.width));
        const tex_height = @as(f32, @floatFromInt(t.image.height));

        const origin_x = if (options.flip_x) o_x - width else -o_x;
        const origin_y = if (options.flip_y) -o_y else o_y - height;
        const pos = @trunc(position);

        const vert_mode: f32 = switch (options.vert_mode) {
            .standard => 0.0,
            .top_sway => 1.0,
        };

        const frag_mode: f32 = switch (options.frag_mode) {
            .standard => 0.0,
            .palette => 1.0,
        };

        var quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{
                    .position = [3]f32{ (pos[0] + origin_x), (pos[1] + height) + origin_y, pos[2] },
                    .uv = [2]f32{ 0.0, 0.0 },
                    .color = options.color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Bl
                .{
                    .position = [3]f32{ (pos[0] + width + origin_x), (pos[1] + height) + origin_y, pos[2] },
                    .uv = [2]f32{ 1.0, 0.0 },
                    .color = options.color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Br
                .{
                    .position = [3]f32{ (pos[0] + width + origin_x), (pos[1]) + origin_y, pos[2] },
                    .uv = [2]f32{ 1.0, 1.0 },
                    .color = options.color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Tr
                .{
                    .position = [3]f32{ (pos[0] + origin_x), (pos[1]) + origin_y, pos[2] },
                    .uv = [2]f32{ 0.0, 1.0 },
                    .color = options.color,
                    .data = [3]f32{ vert_mode, frag_mode, options.time },
                }, //Tl
            },
        };

        // Set viewport of quad to the sprite
        quad.setViewport(x, y, width, height, tex_width, tex_height);

        // Apply mirroring
        if (options.flip_x) quad.flipHorizontally();
        if (options.flip_y) quad.flipVertically();

        // Apply rotation
        if (options.rotation > 0.0 or options.rotation < 0.0) quad.rotate(options.rotation, pos[0], pos[1], origin_x, origin_y);

        return self.append(quad);
    }

    pub fn end(self: *Batcher, uniforms: anytype, buffer: *gpu.Buffer) !void {
        const UniformsType = @TypeOf(uniforms);
        const uniforms_type_info = @typeInfo(UniformsType);
        if (uniforms_type_info != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(UniformsType));
        }
        const uniforms_fields_info = uniforms_type_info.Struct.fields;

        if (self.state == .idle) return error.EndCalledTwice;
        self.state = .idle;

        // Get the quad count for the current batch.
        const quad_count = self.quad_count - self.start_count;
        if (quad_count < 1) return;

        pass: {
            const encoder = self.encoder orelse break :pass;
            const back_buffer_view = core.swap_chain.getCurrentTextureView() orelse break :pass;
            defer back_buffer_view.release();

            const color_attachments = [_]core.gpu.RenderPassColorAttachment{.{
                .view = if (self.context.output_handle) |out_handle| out_handle else back_buffer_view,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = self.context.clear_color,
            }};

            const render_pass_info = core.gpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            encoder.writeBuffer(buffer, 0, &[_]UniformsType{uniforms});

            const batcherRenderPass = encoder.beginRenderPass(&render_pass_info);
            defer {
                batcherRenderPass.end();
                batcherRenderPass.release();
            }

            batcherRenderPass.setVertexBuffer(0, self.vertex_buffer_handle, 0, self.vertex_buffer_handle.getSize());
            batcherRenderPass.setIndexBuffer(self.index_buffer_handle, .uint32, 0, self.index_buffer_handle.getSize());

            batcherRenderPass.setPipeline(self.context.pipeline_handle);

            if (uniforms_fields_info.len > 0) {
                batcherRenderPass.setBindGroup(0, self.context.bind_group_handle, &.{});
            } else {
                batcherRenderPass.setBindGroup(0, self.context.bind_group_handle, null);
            }

            // Draw only the quads appended this cycle
            batcherRenderPass.drawIndexed(@as(u32, @intCast(quad_count * 6)), 1, @as(u32, @intCast(self.start_count * 6)), 0, 0);
        }
    }

    pub fn finish(self: *Batcher) !*core.gpu.CommandBuffer {
        if (self.encoder) |encoder| {
            // Write the current vertex and index buffers to the queue.
            core.queue.writeBuffer(self.vertex_buffer_handle, 0, self.vertices[0 .. self.quad_count * 4]);
            core.queue.writeBuffer(self.index_buffer_handle, 0, self.indices[0 .. self.quad_count * 6]);
            // Reset the Batcher for the next time begin is called.
            self.quad_count = 0;
            self.vert_index = 0;
            const commands = encoder.finish(null);
            encoder.release();
            self.encoder = null;
            return commands;
        } else return error.NullEncoder;
    }

    pub fn deinit(self: *Batcher) void {
        if (self.encoder) |encoder| {
            encoder.release();
        }
        self.encoder = null;
        self.index_buffer_handle.release();
        self.vertex_buffer_handle.release();
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};
