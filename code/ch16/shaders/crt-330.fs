#version 330

// The CRT filter, applied to the finished frame during the blit:
// barrel curvature, scanlines, vignette. The input texture is the
// Chapter 12 canvas; the shader never sees the game, only its pixels.

in vec2 fragTexCoord;
in vec4 fragColor;
out vec4 finalColor;

uniform sampler2D texture0;   // the finished logical frame
uniform vec4 colDiffuse;

uniform vec2 resolution;      // canvas size in pixels (for scanlines)

vec2 curve(vec2 uv) {
    // Barrel distortion: push UVs outward more the farther they are
    // from the center, so the flat picture bulges like glass.
    uv = uv*2.0 - 1.0;
    vec2 offset = abs(uv.yx)/vec2(6.0, 4.0);
    uv = uv + uv*offset*offset;
    return uv*0.5 + 0.5;
}

void main() {
    vec2 uv = curve(fragTexCoord);
    vec3 color = texture(texture0, uv).rgb;
    // Scanlines: a gentle brightness ripple, one cycle per two rows.
    color *= 0.92 + 0.08*sin(uv.y*resolution.y*3.14159);
    // Vignette: the corners dim like a tired tube.
    vec2 v = uv*(1.0 - uv);
    color *= pow(v.x*v.y*16.0, 0.15);
    // Anything the curvature pushed off the glass is cabinet.
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        color = vec3(0.0);
    }
    finalColor = vec4(color, 1.0)*colDiffuse*fragColor;
}
