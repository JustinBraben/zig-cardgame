const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.game_state);
const core = @import("mach").core;
const gpu = core.gpu;
const ecs = @import("zig-ecs");
const zmath = @import("zmath");
const zigimg = @import("zigimg");
const input = @import("input/input.zig");
const Registry = ecs.Registry;
const AssetManager = @import("gfx/asset_manager.zig").AssetManager;
const Atlas = @import("gfx/atlas.zig").Atlas;
const Components = @import("ecs/components/components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;
const Prefabs = @import("ecs/prefabs.zig").Prefabs;
pub const utils = @import("utils.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const shaders = @import("shaders.zig");
pub const settings = @import("settings.zig");

const assets_directory = "../../assets";

pub var animations = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

pub const Vertex = struct {
    position: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
    uv: [2]f32 = [_]f32{ 0.0, 0.0 },
    color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 },
    data: [3]f32 = [_]f32{ 0.0, 0.0, 0.0 },
};

pub const UniformBufferObject = struct {
    mvp: zmath.Mat,
};

pub const FinalUniformObject = @import("ecs/systems/render_final_pass.zig").FinalUniforms;

const vertices = [_]Vertex{
    .{ .position = .{ 0.5, 0.5, 0.0 }, .uv = .{ 1, 0 } }, // bottom-left
    .{ .position = .{ -0.5, 0.5, 0.0 }, .uv = .{ 0, 0 } }, // bottom-right
    .{ .position = .{ -0.5, -0.5, 0.0 }, .uv = .{ 0, 1 } }, // top-right
    .{ .position = .{ 0.5, -0.5, 0.0 }, .uv = .{ 1, 1 } }, // top-left
};

const index_data = [_]u32{ 0, 1, 2, 2, 3, 0 };

// TODO: create textures to render to!
pub const GameState = struct {
    allocator: Allocator = undefined,
    delta_time: f32 = 0.0,
    game_time: f32 = 0.0,
    world: *Registry = undefined,
    camera: gfx.Camera = undefined,
    pipeline_default: *gpu.RenderPipeline = undefined,
    pipeline_game_window: *gpu.RenderPipeline = undefined,
    vertex_buffer_default: *gpu.Buffer = undefined,
    index_buffer_default: *gpu.Buffer = undefined,
    bind_group_default: *gpu.BindGroup = undefined,
    bind_group_game_window: *gpu.BindGroup = undefined,
    uniform_buffer_default: *gpu.Buffer = undefined,
    uniform_buffer_final: *gpu.Buffer = undefined,
    batcher: gfx.Batcher = undefined,
    default_texture: gfx.Texture = undefined,
    game_window_texture: gfx.Texture = undefined,
    default_output: gfx.Texture = undefined,
    game_window_output: gfx.Texture = undefined,
    final_output: gfx.Texture = undefined,
    atlas: gfx.Atlas = undefined,
    mouse: input.Mouse = undefined,
    hotkeys: input.Hotkeys = undefined,

    // asset_manager: *AssetManager = undefined,

    pub fn init(allocator: Allocator) !*GameState {
        var self = try allocator.create(GameState);
        self.allocator = allocator;
        self.world = try allocator.create(Registry);

        self.mouse = try input.Mouse.initDefault(allocator);
        self.hotkeys = try input.Hotkeys.initDefault(allocator);

        self.camera = gfx.Camera.init(zmath.f32x4s(0));
        self.camera.zoom = 1.0;

        self.world.* = Registry.init(allocator);

        var index_x: i32 = -10;
        while (index_x < 10) : (index_x += 1) {
            var index_y: i32 = -10;
            while (index_y < 10) : (index_y += 1) {
                const entity = self.world.create();
                const tile = Components.Tile{ .x = index_x, .y = index_y };
                self.world.add(entity, tile);
                self.world.add(entity, Components.CardValue.Seven);
                self.world.add(entity, Components.CardSuit.Diamonds);
                self.world.add(entity, Components.SpriteRenderer{
                    .index = 0,
                });
                self.world.add(entity, Components.SpriteAnimator{
                    .animation = &animations,
                    .state = .play,
                    .fps = if (index_x + index_y < 1) 1 else @as(usize, @intCast(index_x + index_y)),
                });
            }
            // const entity = self.world.create();
            // const tile = Components.Tile{ .x = index_x, .y = 0 };
            // self.world.add(entity, tile);
            // self.world.add(entity, Components.CardValue.Seven);
            // self.world.add(entity, Components.CardSuit.Diamonds);
            // self.world.add(entity, Components.SpriteRenderer{
            //     .index = 0,
            // });
            // self.world.add(entity, Components.SpriteAnimator{
            //     .animation = &animations,
            //     .state = .play,
            //     .fps = 3,
            // });
        }

        const shader_module = core.device.createShaderModuleWGSL("default.wgsl", shaders.default);
        const shader_module_game_window = core.device.createShaderModuleWGSL("game-window.wgsl", shaders.game_window);
        defer shader_module_game_window.release();
        defer shader_module.release();

        const vertex_attributes = [_]gpu.VertexAttribute{
            .{ .format = .float32x3, .offset = @offsetOf(Vertex, "position"), .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
            .{ .format = .float32x4, .offset = @offsetOf(Vertex, "color"), .shader_location = 2 },
            .{ .format = .float32x3, .offset = @offsetOf(Vertex, "data"), .shader_location = 3 },
        };
        const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
            .array_stride = @sizeOf(Vertex),
            .step_mode = .vertex,
            .attributes = &vertex_attributes,
        });

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
            .module = shader_module,
            .entry_point = "frag_main",
            .targets = &.{color_target},
        });

        const game_window_fragment = gpu.FragmentState.init(.{
            .module = shader_module_game_window,
            .entry_point = "frag_main",
            .targets = &.{color_target},
        });

        const default_vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vert_main",
            .buffers = &.{vertex_buffer_layout},
        });

        const game_window_vertex = gpu.VertexState.init(.{
            .module = shader_module_game_window,
            .entry_point = "vert_main",
            .buffers = &.{vertex_buffer_layout},
        });
        
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
            .fragment = &default_fragment,
            .vertex = default_vertex,
            // .primitive = .{ .cull_mode = .back },
        };

        const pipeline_descriptor_game_window = gpu.RenderPipeline.Descriptor{
            .fragment = &game_window_fragment,
            .vertex = game_window_vertex,
            // .primitive = .{ .cull_mode = .back },
        };

        const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);
        const pipeline_game_window = core.device.createRenderPipeline(&pipeline_descriptor_game_window);

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
        const format = if (builtin.os.tag == .windows) "{s}\\{s}" else "{s}/{s}";

        const cards_png_relative_path = "assets/Cards_v2.png";
        const cards_png_full_path = try std.fmt.allocPrint(self.allocator, format, .{ base_folder, cards_png_relative_path });
        defer self.allocator.free(cards_png_full_path);

        const solitaire_window_png_relative_path = "assets/Solitaire_window-1.png";
        const solitaire_window_png_full_path = try std.fmt.allocPrint(self.allocator, format, .{ base_folder, solitaire_window_png_relative_path });
        defer self.allocator.free(solitaire_window_png_full_path);

        const sprites_animations_json = "assets/card_sprite.json";
        const sprites_animations_full_path = try std.fmt.allocPrint(self.allocator, format, .{ base_folder, sprites_animations_json });
        defer self.allocator.free(sprites_animations_full_path);
        self.atlas = try gfx.Atlas.initFromFilePath(allocator, sprites_animations_full_path);

        // Load game textures
        self.default_texture = try gfx.Texture.loadFromFilePath(self.allocator, cards_png_full_path, .{ .format = core.descriptor.format });
        self.game_window_texture = try gfx.Texture.loadFromFilePath(self.allocator, solitaire_window_png_full_path,  .{ .format = core.descriptor.format});

        self.default_output = try gfx.Texture.createEmpty(self.allocator, settings.design_width, settings.design_height, . { .format = core.descriptor.format});
        self.game_window_output = try gfx.Texture.createEmpty(self.allocator, settings.design_width, settings.design_height, . { .format = core.descriptor.format});
        self.final_output = try gfx.Texture.createEmpty(self.allocator, settings.design_width, settings.design_height, . { .format = core.descriptor.format});

        self.uniform_buffer_default = core.device.createBuffer(&.{
            .usage = .{ .copy_dst = true, .uniform = true },
            .size = @sizeOf(UniformBufferObject),
            .mapped_at_creation = .false,
        });

        self.uniform_buffer_final = core.device.createBuffer(&.{
            .usage = .{ .copy_dst = true, .uniform = true },
            .size = @sizeOf(FinalUniformObject),
            .mapped_at_creation = .false,
        });

        const pipeline_layout_default = pipeline.getBindGroupLayout(0);
        const pipeline_layout_game_window = pipeline_game_window.getBindGroupLayout(0);

        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = pipeline_layout_default,
                .entries = &.{
                    gpu.BindGroup.Entry.buffer(0, self.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                    gpu.BindGroup.Entry.textureView(1, self.default_texture.view_handle),
                    gpu.BindGroup.Entry.sampler(2, self.default_texture.sampler_handle),
                },
            }),
        );

        const bind_group_game_window = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = pipeline_layout_game_window,
                .entries = &.{
                    gpu.BindGroup.Entry.buffer(0, self.uniform_buffer_default, 0, @sizeOf(UniformBufferObject)),
                    gpu.BindGroup.Entry.textureView(1, self.game_window_texture.view_handle),
                    gpu.BindGroup.Entry.sampler(2, self.game_window_texture.sampler_handle),
                },
            }),
        );

        self.batcher = try gfx.Batcher.init(allocator, 1);
        pipeline_layout_default.release();
        pipeline_layout_game_window.release();

        self.pipeline_default = pipeline;
        self.pipeline_game_window = pipeline_game_window;
        self.vertex_buffer_default = vertex_buffer;
        self.index_buffer_default = index_buffer;
        self.bind_group_default = bind_group;
        self.bind_group_game_window = bind_group_game_window;
        return self;
    }

    /// Create solitaire game
    pub fn createSolitaire(self: *GameState) !void {

        // Generate deck of cards
        try generateDeck(self);

        // Shuffle deck of cards
        try shuffleDeck(self);



        // Deal cards to table
        
        // Create foundation piles
    }

    pub fn generateDeck(self: *GameState) !void {
        
        const suits = [_]Components.CardSuit{ 
            Components.CardSuit.Diamonds,
            Components.CardSuit.Hearts,
            Components.CardSuit.Clubs,
            Components.CardSuit.Spades
        };

        const values = [_]Components.CardValue{ 
            Components.CardValue.Ace,
            Components.CardValue.Two,
            Components.CardValue.Three,
            Components.CardValue.Four,
            Components.CardValue.Five,
            Components.CardValue.Six,
            Components.CardValue.Seven,
            Components.CardValue.Eight,
            Components.CardValue.Nine,
            Components.CardValue.Ten,
            Components.CardValue.Jack,
            Components.CardValue.Queen,
            Components.CardValue.King
        };

        var index: usize = 0;
        for (suits) |suit| {
            for (values) |value| {
                if (index >= self.atlas.sprites.len) {
                    return error.OutOfRange;
                }
                const entity = self.world.create();
                self.world.add(entity, suit);
                self.world.add(entity, value);
                self.world.add(entity, Components.SpriteRenderer{
                    .index = index,
                });
                self.world.add(entity, Components.DeckOrder{
                    .index = index,
                });
                index += 1;
            }
        }

    }

    pub fn shuffleDeck(self: *GameState) !void {
        // Make a set with 0 - 51
        // Pick 2 random numbers from the set (which are indexes)
        // swap the cards at those indexes
        // Then remove those two values (indexes) from the set
        // keep going until the set is empty
        var deck_index_set = std.AutoHashMap(usize, void).init(self.allocator);
        defer deck_index_set.deinit();

        var deck_index_list = std.ArrayList(usize).init(self.allocator);
        defer deck_index_list.deinit();

        var deck_index_count: usize = 0;
        while (deck_index_count < 52) : (deck_index_count += 1) {
            try deck_index_list.append(deck_index_count);
        }

        while (deck_index_set.count() < deck_index_list.items.len) {
            var rnd = std.rand.DefaultPrng.init(
                blk: {
                    var seed: u64 = undefined;
                    try std.os.getrandom(std.mem.asBytes(&seed));
                    break :blk seed;
                }
            );
            var index_1 = rnd.random().intRangeAtMost(usize, 0, 51);
            var index_2 = rnd.random().intRangeAtMost(usize, 0, 51);

            while (deck_index_set.contains(index_1) or index_1 == index_2) {
                index_1 = rnd.random().intRangeAtMost(usize, 0, 51);
            }

            while (deck_index_set.contains(index_2) or index_1 == index_2) {
                index_2 = rnd.random().intRangeAtMost(usize, 0, 51);
            }

            var view_deck_order = self.world.view(.{ Components.DeckOrder }, .{ Components.IsShuffled });
            var view_deck_entity_iter = view_deck_order.entityIterator();
            while (view_deck_entity_iter.next()) |entity| {
                var entity_deck_order = view_deck_order.get(Components.DeckOrder, entity);
                if (entity_deck_order.index == index_1) {
                    entity_deck_order.index = index_2;
                } else if (entity_deck_order.index == index_2) {
                    entity_deck_order.index = index_1;
                }
                self.world.add(entity, Components.IsShuffled{}); // mark as shuffled
            }

            try deck_index_set.put(index_1, {});
            try deck_index_set.put(index_2, {});

            log.info("index1: {d}, index2: {d}", .{index_1, index_2});
        }
    }

    pub fn positionDeck(self: *GameState) !void {
        _ = self;
    }

    pub fn deinit(self: *GameState) void {
        self.pipeline_default.release();
        self.vertex_buffer_default.release();
        self.index_buffer_default.release();

        self.bind_group_default.release();
        self.bind_group_game_window.release();

        self.uniform_buffer_default.release();
        self.uniform_buffer_final.release();

        self.default_texture.deinit();

        self.default_output.deinit();
        self.game_window_output.deinit();
        self.final_output.deinit();

        self.allocator.free(self.atlas.sprites);
        self.allocator.free(self.atlas.animations);
        
        self.allocator.free(self.mouse.buttons);
        self.allocator.free(self.hotkeys.hotkeys);

        self.batcher.deinit();
        self.world.deinit();
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
