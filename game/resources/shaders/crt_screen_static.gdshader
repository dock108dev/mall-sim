shader_type spatial;
render_mode cull_back;

// CRT Amber #E8A547 and CRT Cyan #3AA8D8 — visual-grammar palette (ISSUE-004)
const vec3 CRT_AMBER = vec3(0.910, 0.647, 0.278);
const vec3 CRT_CYAN  = vec3(0.227, 0.659, 0.847);

uniform float screen_brightness : hint_range(0.5, 4.0) = 2.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// 5 discrete frames at 2.5 fps — full cycle ~2 s
	float frame = floor(TIME * 2.5);

	// Chunky static blocks (low-res grid)
	vec2 block_uv = floor(UV * vec2(10.0, 7.0));
	float n_block = hash(block_uv + vec2(frame * 127.1, frame * 311.7));

	// Fine-grain overlay blended in at 25 %
	vec2 fine_uv = floor(UV * vec2(28.0, 20.0));
	float n_fine = hash(fine_uv + vec2(frame * 41.3, frame * 93.7));

	float v = mix(n_block, n_fine, 0.25);

	// Hard cut between palette colors with per-pixel brightness variation
	vec3 color = mix(CRT_AMBER, CRT_CYAN, step(0.5, v));
	color *= 0.6 + 0.4 * v;

	ALBEDO = vec3(0.02);
	EMISSION = color * screen_brightness;
}
