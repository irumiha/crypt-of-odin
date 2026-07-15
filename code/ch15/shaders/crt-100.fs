#version 100

// GLSL 100 twin of crt-330.fs, for the web (WebGL 1) build.
// Same logic; only the dialect differs.

precision mediump float;

varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform vec2 resolution;

vec2 curve(vec2 uv) {
    uv = uv*2.0 - 1.0;
    vec2 offset = abs(uv.yx)/vec2(6.0, 4.0);
    uv = uv + uv*offset*offset;
    return uv*0.5 + 0.5;
}

void main() {
    vec2 uv = curve(fragTexCoord);
    vec3 color = texture2D(texture0, uv).rgb;
    color *= 0.92 + 0.08*sin(uv.y*resolution.y*3.14159);
    vec2 v = uv*(1.0 - uv);
    color *= pow(v.x*v.y*16.0, 0.15);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        color = vec3(0.0);
    }
    gl_FragColor = vec4(color, 1.0)*colDiffuse*fragColor;
}
