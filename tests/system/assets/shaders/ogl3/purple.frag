#version 330 core

in vec4 Color;
in vec2 TexCoord;

out vec4 FragColor;

uniform sampler2D defaultTexture;

void main()
{
    FragColor = vec4(1, 0, 0.75, 1);
}
