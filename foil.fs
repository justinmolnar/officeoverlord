// A completely new foil shader using a static noise texture revealed by a moving light wave.
extern number time;

// 2D pseudo-random number generator (noise)
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // 1. Create a STATIC, fine-grained noise pattern.
    // This is based only on the pixel's position, not time.
    // This gives the card a consistent, underlying texture.
    float static_noise = random(texture_coords * 35.0); // High frequency for fine grain

    // 2. Create a large, slow-moving diagonal wave of "light".
    // This will act as a mask to reveal the noise texture.
    float light_wave = cos((texture_coords.x + texture_coords.y) * 3.0 - time * 0.9) * 0.5 + 0.5;
    
    // 3. Sharpen the light wave into a defined band.
    light_wave = smoothstep(0.3, 0.7, light_wave); 

    // 4. The final intensity of the effect is the static noise multiplied by the moving light wave.
    // This makes the static noise pattern "shimmer" only where the light passes over it.
    float shimmer_intensity = static_noise * light_wave;

    // 5. Apply the effect.
    // We add a subtle brightness based on the shimmer intensity.
    // This will be visible on all card colors, including white.
    vec3 final_rgb = color.rgb + vec3(shimmer_intensity * 0.35);
    
    return vec4(final_rgb, color.a);
}