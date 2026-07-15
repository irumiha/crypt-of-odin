#version 100

// GLSL 100 twin of outline-330.fs, for the web (WebGL 1) build.
// Same logic; only the dialect differs.

precision mediump float;

varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform vec2 texelSize;
uniform vec4 region;
uniform vec4 outlineColor;

float alphaAt(vec2 uv) {
    return texture2D(texture0, clamp(uv, region.xy, region.zw)).a;
}

void main() {
    vec4 center = texture2D(texture0, fragTexCoord);
    float neighbors = alphaAt(fragTexCoord + vec2(texelSize.x, 0.0))
                    + alphaAt(fragTexCoord - vec2(texelSize.x, 0.0))
                    + alphaAt(fragTexCoord + vec2(0.0, texelSize.y))
                    + alphaAt(fragTexCoord - vec2(0.0, texelSize.y));
    if (center.a < 0.1 && neighbors > 0.0) {
        gl_FragColor = outlineColor;
    } else {
        gl_FragColor = center*colDiffuse*fragColor;
    }
}
