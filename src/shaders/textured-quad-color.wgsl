struct Uniforms {
    mvp: mat4x4<f32>,
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct VertexOutput {
  @builtin(position) Position : vec4<f32>,
  @location(0) fragUV : vec2<f32>,
  @location(1) color: vec4<f32>
};

@vertex
fn vertex_main(
    @location(0) position : vec2<f32>,
    @location(1) uv : vec2<f32>,
    @location(2) color: vec4<f32>
) -> VertexOutput {
  var output : VertexOutput;
  output.Position = vec4(position, 0, 1);
  output.fragUV = uv;
  output.color = color;
  return output;
}

group(0) @binding(1) var diffuse: texture_2d<f32>;
@group(0) @binding(2) var diffuse_sampler: sampler;

@fragment fn frag_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
) -> @location(0) vec4<f32> {
    var sample = textureSample(diffuse, diffuse_sampler, uv);
    return sample * color;
}