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
        flip_y: bool = false,
        flip_x: bool = false,
    };

    pub fn texture(self: *Batcher, position: zmath.F32x4, t: *gfx.Texture, options: TextureOptions) !void {{
        const width = @as(f32, @floatFromInt(t.image.width));
        const height = @as(f32, @floatFromInt(t.image.height));
        const pos = zmath.trunc(position);
        // std.debug.print("Old texture pos : {any}\n", .{position});
        // std.debug.print("Old texture pos truncated: {any}\n", .{pos});

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        const quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{ .pos = .{ pos[0], pos[1] + height}, .uv = .{ if (options.flip_x) max else min, min } },
                .{ .pos = .{ pos[0] + width, pos[1] + height}, .uv = .{ if (options.flip_x) min else max, min } },
                .{ .pos = .{ pos[0] + width, pos[1]}, .uv = .{ if (options.flip_x) min else max, max } },
                .{ .pos = .{ pos[0], pos[1]}, .uv = .{ if (options.flip_x) max else min, max } },
            }
        };
        // std.debug.print("Vertices with new texture : {any}\n", .{quad.vertices});

        return self.append(quad);
    }}

    pub fn textureSquare(self: *Batcher, position: zmath.F32x4, size: [2]f32, options: TextureOptions) !void {
        // const width = size[0];
        // const height = size[1];

        const max: f32 = if (!options.flip_y) 1.0 else 0.0;
        const min: f32 = if (!options.flip_y) 0.0 else 1.0;

        const quad = gfx.Quad{
            .vertices = [_]gfx.Vertex{
                .{ .pos = .{ position[0], position[1] + size[1]}, .uv = .{ if (options.flip_x) max else min, min } },         // bottom-left
                .{ .pos = .{ position[0] + size[0], position[1] + size[1] }, .uv = .{ if (options.flip_x) min else max, min } },                  // bottom-right
                .{ .pos = .{ position[0] + size[0], position[1] }, .uv = .{ if (options.flip_x) min else max, max } },         // top-right
                .{ .pos = .{ position[0], position[1] }, .uv = .{ if (options.flip_x) max else min, max } },                  // top-left
            }
        };

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
                .{ .pos = .{ position[0], position[1] + height}, .uv = .{ if (options.flip_x) min else max, min } },          // bottom-left
                .{ .pos = .{ position[2], position[3] }, .uv = .{ if (options.flip_x) max else min, min } },                  // bottom-right
                .{ .pos = .{ position[2], position[3] - height }, .uv = .{ if (options.flip_x) max else min, max } },         // top-right
                .{ .pos = .{ position[0], position[1] }, .uv = .{ if (options.flip_x) min else max, max } },                  // top-left
            }
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

    pub fn end(self: *Batcher, uniforms: anytype, buffer: *gpu.Buffer) !void {
        const UniformsType = @TypeOf(uniforms);
        const uniforms_type_info = @typeInfo(UniformsType);
        if (uniforms_type_info != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(UniformsType));
        }
        // const uniforms_fields_info = uniforms_type_info.Struct.fields;

        if (self.state == .idle) return error.EndCalledTwice;
        self.state = .idle;

        // Get the quad count for the current batch.
        const quad_count = self.quad_count - self.start_count;
        if (quad_count < 1) return;

        pass: {
            // std.debug.print("Start of pass block in batcher.end()\n", .{});
            const encoder = self.encoder orelse break :pass;
            const back_buffer_view = core.swap_chain.getCurrentTextureView() orelse break :pass;
            defer back_buffer_view.release();

            const color_attachments = [_]core.gpu.RenderPassColorAttachment{.{
                .view = back_buffer_view,
                .load_op = .clear,
                .clear_value = self.context.clear_color,
                .store_op = .store,
            }};

            const render_pass_info = core.gpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            encoder.writeBuffer(buffer, 0, &[_]UniformsType{uniforms});

            const batcherRenderPass = encoder.beginRenderPass(&render_pass_info);
            // defer {
            //     batcherRenderPass.end();
            //     batcherRenderPass.release();
            // }

            // const pass = encoder.beginRenderPass(&render_pass_info);
            // pass.setPipeline(self.pipeline_default);
            // pass.setVertexBuffer(0, self.vertex_buffer_default, 0, @sizeOf(Vertex) * vertices.len);
            // pass.setIndexBuffer(self.index_buffer_default, .uint32, 0, @sizeOf(u32) * index_data.len);
            // pass.setBindGroup(0, self.bind_group_default, &.{});
            // pass.drawIndexed(index_data.len, 1, 0, 0, 0);
            // pass.end();
            // pass.release();

            batcherRenderPass.setPipeline(self.context.pipeline_handle);
            batcherRenderPass.setVertexBuffer(0, self.vertex_buffer_handle, 0, self.vertex_buffer_handle.getSize());
            batcherRenderPass.setIndexBuffer(self.index_buffer_handle, .uint32, 0, self.index_buffer_handle.getSize());
            batcherRenderPass.setBindGroup(0, self.context.bind_group_handle, &.{});
            // Draw only the quads appended this cycle
            batcherRenderPass.drawIndexed(@as(u32, @intCast(quad_count * 6)), 1, 0, 0, 0);
            batcherRenderPass.end();
            batcherRenderPass.release();
            // std.debug.print("Got to end of batcher pass inside of end()\n", .{});
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