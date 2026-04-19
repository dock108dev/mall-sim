shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_count : hint_range(100.0, 800.0) = 400.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec3 phosphor_tint : source_color = vec3(1.05, 1.0, 0.85);

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;

	// Scanlines
	float sl = sin(SCREEN_UV.y * scanline_count * 3.14159265);
	col *= 1.0 - scanline_intensity * sl * sl;

	// Vignette
	vec2 v = SCREEN_UV * 2.0 - 1.0;
	col *= 1.0 - vignette_strength * dot(v * vec2(0.8, 1.0), v * vec2(0.8, 1.0));

	// Phosphor warmth (amber-green mall aesthetic)
	col *= phosphor_tint;

	COLOR = vec4(col, 1.0);
}
