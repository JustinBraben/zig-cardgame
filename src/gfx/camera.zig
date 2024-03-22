const std = @import("std");
const zmath = @import("zmath");
const game = @import("../main.zig");

const core = @import("mach").core;

pub const Camera = struct {
    zoom: f32 = 1.0,
    position: zmath.F32x4 = zmath.f32x4s(0),

    pub fn init(position: zmath.F32x4) Camera {
        return .{
            .zoom = 1.0,
            .position = position,
        };
    }

    /// Use this matrix when drawing to the framebuffer.
    pub fn frameBufferMatrix(camera: Camera) zmath.Mat {
        const fb_ortho = zmath.orthographicRh(
            game.window_size[0],
            game.window_size[1],
            0.1,
            1000,
        );
        const view = zmath.lookAtRh(
            zmath.Vec{ 0, 1000, 0, 1 },
            zmath.Vec{ 0, 0, 0, 1 },
            zmath.Vec{ 0, 0, 1, 0 },
        );
        const fb_scaling = zmath.scaling(camera.zoom, camera.zoom, 1);
        _ = fb_scaling;
        return zmath.mul(view, fb_ortho);
    }

    /// Use this matrix when drawing to an off-screen render texture.
    pub fn renderTextureMatrix(camera: Camera) zmath.Mat {
        const rt_ortho = zmath.orthographicRh(
            @as(f32, @floatFromInt(core.size().width)),
            @as(f32, @floatFromInt(core.size().height)),
            0.1,
            1000,
        );
        const rt_translation = zmath.translation(-camera.position[0], -camera.position[1], 0);

        return zmath.mul(rt_translation, rt_ortho);
    }

    /// Transforms a position from screen-space to world-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn screenToWorld(camera: Camera, position: zmath.F32x4) zmath.F32x4 {
        const fb_mat = camera.frameBufferMatrix();
        const ndc = zmath.mul(fb_mat, zmath.f32x4(position[0], -position[1], 1, 1)) / zmath.f32x4(camera.zoom * 2, camera.zoom * 2, 1, 1) + zmath.f32x4(-0.5, 0.5, 1, 1);
        const world = ndc * zmath.f32x4(game.window_size[0] / camera.zoom, game.window_size[1] / camera.zoom, 1, 1) - zmath.f32x4(-camera.position[0], -camera.position[1], 1, 1);

        return zmath.f32x4(world[0], world[1], 0, 0);
    }

    /// Transforms a position from world-space to screen-space.
    /// Remember that in screen-space positive Y is down, and positive Y is up in world-space.
    pub fn worldToScreen(camera: Camera, position: zmath.F32x4) zmath.F32x4 {
        const screen = (camera.position - position) * zmath.f32x4(camera.zoom, camera.zoom, 0, 0) - zmath.f32x4((game.window_size[0] / 2), (-game.window_size[1] / 2), 0, 0);

        return zmath.f32x4(-screen[0], screen[1], 0, 0);
    }
};