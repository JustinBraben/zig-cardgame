const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.batcher);
const assert = std.debug.assert;
const core = @import("mach").core;
const gpu = core.gpu;

pub const Batcher = struct {
    allocator: Allocator,
    encoder: ?*gpu.CommandEncoder,
    vertices
};