const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.batcher);
const assert = std.debug.assert;
const core = @import("mach").core;
const gpu = core.gpu;

pub const Batcher = struct {
    allocator: Allocator,
    encoder: ?*gpu.CommandEncoder = null,
    max_quads: usize,
    context: Context = undefined,
    state: State = .idle,
    start_count: usize = 0,

    /// Contains instructions on pipeline and binding for the current batch
    pub const Context = struct {
        pipeline_handle: *gpu.RenderPipeline,
        bind_group_handle: *gpu.BindGroup,
        // If output handle is null, render to the back buffer
        // otherwise, render to offscreen texture view handle
        output_handle: ?*gpu.TextureView = null,
        clear_color: gpu.Color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
    };

    /// Describes the current state of the Batcher
    pub const State = enum {
        progress,
        idle,
    };

    pub fn init(allocator: Allocator, max_quads: usize) !Batcher {
        return .{
            .allocator = allocator,
            .max_quads = max_quads,
        };
    }

    pub fn begin(self: *Batcher, context: Context) !void {
        if (self.state == .progress) return error.BeginCalledTwice;
        self.context = context;
        self.state = .progress;
        self.start_count = self.quad_count;
        if (self.encoder == null) {
            self.encoder = core.device.createCommandEncoder(null);
        }
    }
};