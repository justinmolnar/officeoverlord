// A more robust holographic shader using a better blending method.
extern number time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Reverted to the original, slower speed for a gentler effect.
    float rainbow_value = fract(screen_coords.x * 0.001 - screen_coords.y * 0.0005 + time * 0.1);

    // Generate the rainbow color.
    vec3 rainbow_color = vec3(
        sin(rainbow_value * 6.28318 + 0.0) * 0.5 + 0.5,
        sin(rainbow_value * 6.28318 + 2.09439) * 0.5 + 0.5,
        sin(rainbow_value * 6.28318 + 4.18879) * 0.5 + 0.5
    );

    // Use mix() to blend the original color with the rainbow color.
    // This tints the card with the rainbow instead of washing it out.
    // The '0.35' controls the maximum strength of the rainbow tint.
    vec3 final_rgb = mix(color.rgb, rainbow_color, 0.1);

    return vec4(final_rgb, color.a);
}