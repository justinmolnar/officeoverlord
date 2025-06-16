// laminated.fs: Animated noise-based glare

uniform float time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    if (color.a < 0.1) {
        return color;
    }

    // Create a simple animated pattern using screen coordinates
    float wave = sin((screen_coords.x + screen_coords.y) * 0.1 + time * 2.0);
    
    // Only apply highlight when wave is positive and strong
    if (wave > 0.7) {
        float intensity = (wave - 0.7) / 0.3; // 0 to 1
        vec3 highlight = vec3(0.5, 0.5, 0.5) * intensity;
        return vec4(color.rgb + highlight, color.a);
    }
    
    return color;
}