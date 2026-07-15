#version 330

// The item outline: paint any transparent pixel that touches an
// opaque one. Runs once per destination pixel; raylib supplies the
// inputs and the default vertex shader.

in vec2 fragTexCoord;
in vec4 fragColor;
out vec4 finalColor;

uniform sampler2D texture0;  // the atlas (raylib binds it)
uniform vec4 colDiffuse;     // raylib's draw tint

uniform vec2 texelSize;      // one atlas texel, in UV units
uniform vec4 region;         // this sprite's atlas cell: min.xy, max.zw
uniform vec4 outlineColor;

float alphaAt(vec2 uv) {
    // Clamp sampling to the sprite's own cell, so the outline never
    // tastes whatever sprite lives next door in the atlas.
    return texture(texture0, clamp(uv, region.xy, region.zw)).a;
}

void main() {
    vec4 center = texture(texture0, fragTexCoord);
    float neighbors = alphaAt(fragTexCoord + vec2(texelSize.x, 0.0))
                    + alphaAt(fragTexCoord - vec2(texelSize.x, 0.0))
                    + alphaAt(fragTexCoord + vec2(0.0, texelSize.y))
                    + alphaAt(fragTexCoord - vec2(0.0, texelSize.y));
    if (center.a < 0.1 && neighbors > 0.0) {
        finalColor = outlineColor;
    } else {
        finalColor = center*colDiffuse*fragColor;
    }
}
