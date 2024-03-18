const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../main.zig");
const gfx = game.gfx;
const components = game.components;

pub fn run() void {
    const uniforms = gfx.UniformBufferObject{ .mvp = zmath.transpose(game.state.camera.frameBufferMatrix()) };
    _ = uniforms;
}