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
@group(0) @binding(2) var window: texture_2d<f32>;
@group(0) @binding(3) var diffuse_sampler: sampler;
@fragment fn frag_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    var frag_mode = i32(data.y);
    var base_color = textureSample(diffuse, diffuse_sampler, uv);
    var sample = textureSample(window, diffuse_sampler, uv) * base_color.a;

    if (frag_mode == 1) {
        return sample;
    }

    return base_color * color;
}