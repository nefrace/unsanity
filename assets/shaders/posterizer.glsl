#version 330

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

// Input uniform values
uniform sampler2D texture0;
uniform sampler2D texture1;
uniform vec4 colDiffuse;

uniform float posterize;

out vec4 finalColor;

const int bayer16[16] = int[16](0,  8,  2,  10, 
                                12, 4,  14, 6, 
                                3,  11, 1,  9, 
                                15, 7,  13, 5);


void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    int col = int(mod(gl_FragCoord.x, 4));
    int row = int(mod(gl_FragCoord.y, 4));
    float threshold = float(bayer16[col + 4 * row]) / 16.0 - 0.5;
    texelColor.rgb = clamp(texelColor.rgb + vec3(threshold * 0.1), 0.01, 0.99);

    finalColor.a = 1.0;
    finalColor.rgb = floor(texelColor.rgb * posterize) / posterize;
}
