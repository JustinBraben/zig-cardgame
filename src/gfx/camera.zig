const std = @import("std");
const zmath = @import("zmath");

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
            @as(f32, @floatFromInt(core.size().width)),
            @as(f32, @floatFromInt(core.size().height)),
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
};