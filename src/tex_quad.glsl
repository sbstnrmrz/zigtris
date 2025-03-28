@header const m = @import("math.zig")
@ctype mat4 m.Mat4

@vs vs

layout(binding=0) uniform vs_params {
    mat4 p;
};

in vec3 pos;
in vec2 in_uv;
in vec4 in_color;

out vec2 uv;
out vec4 color;

void main() {
    gl_Position = p * vec4(pos, 1.0);
    uv = in_uv;
    color = in_color;
}
@end

@fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler default_sampler;

in vec2 uv;
in vec4 color;

out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, default_sampler), uv) * color;
}

@end
@program tex_quad vs fs

