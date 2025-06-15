#version 330
#define MAX_LIGHTS 32

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;
// in vec4 vertColor;

struct Light {
    int enabled;
    float distanceNear;
    float distanceFar;
    float power;
    vec3 position;
    vec4 color;
};

// Input uniform values
uniform sampler2D texture0;
uniform sampler2D bloodmask;
uniform vec4 colDiffuse;
uniform float insanity;
uniform Light lights[MAX_LIGHTS];
uniform vec4 ambient;
uniform vec3 viewPos;
uniform float flash;

// Output fragment color
out vec4 finalColor;





void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord) * fragColor;
    vec4 bloodColor = texture(bloodmask, fragTexCoord * 20.0);
    // finalColor = fragColor;
    // return;
    if (texelColor.a == 0.0) discard;
    if (fragColor.r == 0.0) {
    	finalColor = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        vec3 lightDot = vec3(0.0);
        vec4 tint = colDiffuse * fragColor;
        vec3 normal = normalize(fragNormal);
        
        for (int i = 0; i < MAX_LIGHTS; i++) {
            if (lights[i].enabled == 1) {
                vec3 light = vec3(0.0);

                light = normalize(lights[i].position - fragPosition);

                float dist = distance(lights[i].position, fragPosition);
                
                float power = smoothstep(lights[i].distanceFar, lights[i].distanceNear, dist);
                float NdotL = max(dot(normal, light), 0.0);
                // lightDot += lights[i].color.rgb * power * lights[i].power * NdotL;
                lightDot += lights[i].color.rgb * power * lights[i].power;
         
            }
        }  
        
        lightDot = max(lightDot, 0.1);
        // finalColor.rgb *= lightDot;
        // finalColor.rgb = (bloodedColor.rgb * lightDot);
        finalColor.a = 1.0;
        // finalColor = pow(finalColor, vec4(1.0/2.2));
        finalColor.rgb += vec3(0.5) * flash;
        const vec4 fogColor = vec4(0.15, 0.15, 0.2, 1.0);
        const vec4 bloodFogColor = vec4(0.2, 0.15, 0.15, 1.0);
        vec4 finalFog = mix(fogColor, bloodFogColor, insanity);
        float dist = length(viewPos - fragPosition);
        const float fogDensity = 0.08;


        // Exponential fog
        // float fogFactor = 1.0/exp((dist*fogDensity)*(dist*fogDensity));

        // Linear fog (less nice)
        const float fogStart = 7.0;
        const float fogEnd = 20.0;
        float fogFactor = (fogEnd - dist)/(fogEnd - fogStart);

        fogFactor = clamp(fogFactor, 0.0, 1.0);

        finalColor.rgb = mix(finalFog.rgb, finalColor.rgb, fogFactor);
        
    }
}
