// embossed.fs: A crisp, "stamped" effect with highlights and shadows.

uniform vec2 cardSize;

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // We only want to apply the effect to the non-white parts of the card.
    if (luminance(color.rgb) > 0.95 || color.a < 0.1) {
        return color;
    }

    // --- Effect Properties ---
    float strength = 1.5;     // Increased strength for visibility
    float sharpness = 4.0;
    vec3 highlight_color = vec3(1.7, 1.65, 1.55); // Brighter highlight
    float shadow_darkness = 0.6; // Darker shadow

    // 1. Calculate pixel offset.
    vec2 offset = vec2(strength / cardSize.x, strength / cardSize.y);

    // 2. Sample neighbors for highlight (top-left) and shadow (bottom-right).
    vec4 highlight_sample = Texel(texture, texture_coords - offset);
    vec4 shadow_sample = Texel(texture, texture_coords + offset);

    // 3. Check for top-left edges to apply highlight.
    if (luminance(highlight_sample.rgb) > 0.95) {
        float edge_factor = pow(luminance(color.rgb) - luminance(highlight_sample.rgb), sharpness);
        vec3 final_color = color.rgb + highlight_color * edge_factor;
        return vec4(final_color, color.a);
    }
    
    // 4. Check for bottom-right edges to apply shadow.
    if (luminance(shadow_sample.rgb) > 0.95) {
        float edge_factor = pow(luminance(color.rgb) - luminance(shadow_sample.rgb), sharpness);
        vec3 final_color = color.rgb * (1.0 - (shadow_darkness * edge_factor));
        return vec4(final_color, color.a);
    }
    
    // 5. Return original color for middle of elements.
    return color;
}