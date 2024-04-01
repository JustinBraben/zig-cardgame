struct Uniforms {
    mvp: mat4x4<f32>,
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
}
@vertex fn vert_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
) -> VertexOut {
    var output: VertexOut;
    output.position_clip = vec4(position.xy, 0.0, 1.0) * uniforms.mvp;
    output.uv = uv;
    output.color = color;
    output.data = data;
    return output;
}

@group(0) @binding(1) var diffuse: texture_2d<f32>;
@group(0) @binding(2) var diffuse_sampler: sampler;
@group(0) @binding(3) var window: texture_2d<f32>;
@group(0) @binding(4) var window_sampler: sampler;

const multiplier = 65025.0;

fn max3(channels: vec3<f32>) -> i32 {
    return i32(max(channels.z, max(channels.y , channels.x)));
}

fn paletteCoord(base: vec3<f32>, vert: vec3<f32>) -> vec2<f32> {
    var channels = vec3(
        clamp(base.x + vert.x * multiplier, 0.0, 1.0),
        clamp(base.y + vert.y * multiplier, 0.0, 1.0) * 2.0,
        clamp(base.z + vert.z * multiplier, 0.0, 1.0) * 3.0,
    );

    var index = max3(channels);

    let b = base.brgb;
    let v = vert.brgb;

    return vec2(b[index], v[index]);
}

@fragment fn frag_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    var diffuse = textureSample(diffuse, diffuse_sampler, uv);
    var window = textureSample(window, window_sampler, uv);

    var render = diffuse + window;
    return render;
}