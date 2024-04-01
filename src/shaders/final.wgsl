struct FinalUniforms {
    mvp: mat4x4<f32>,
    inverse_mvp: mat4x4<f32>,
    output_channel: i32,
    mouse: vec2<f32>,
}
@group(0) @binding(0) var<uniform> uniforms: FinalUniforms;

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>
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

@group(0) @binding(1) var default: texture_2d<f32>;
@group(0) @binding(2) var default_sampler: sampler;
@group(0) @binding(3) var window: texture_2d<f32>;
@group(0) @binding(4) var window_sampler: sampler;
@fragment fn frag_main(
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    if (uniforms.output_channel == 1) {
        return textureSample(default, default_sampler, uv);
    } else if ( uniforms.output_channel == 2) {
        return textureSample(window, window_sampler, uv);
    }

    var default = textureSample(diffuse, diffuse_sampler, uv);
    var window = textureSample(window, window_sampler, uv);

    var render = default + window;
    return render;
}