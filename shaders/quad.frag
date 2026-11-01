#version 460

layout(set = 2, binding = 0) uniform sampler2D u_texture;

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in vec4 frag_color;

layout(location = 0) out vec4 color;

void main() {
    color = texture(u_texture, frag_uv) * frag_color;
}
