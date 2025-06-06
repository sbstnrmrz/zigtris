@header const m = @import("/math.zig")
@ctype mat4 m.Mat4

@vs vs

layout(binding=0) uniform vs_params {
    mat4 p;
};

in vec3 pos;
in vec4 in_color;

out vec4 color;

void main() {
    gl_Position = p * vec4(pos, 1.0);
    color = in_color;
}
@end

@fs fs
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end
@program quad vs fs
