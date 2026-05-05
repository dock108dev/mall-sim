shader_type spatial;

// Subtle saturation shimmer applied to a flagged hidden-thread interactable's
// own surface color. Activation is gated externally — the controlling node
// drives `activation` from 0.0 (off) to 1.0 (on) only when the player is
// within 2 m AND within 30 deg of the object's center axis. There is no
// emissive overlay and no additive glow: the entire effect is a saturation
// modulation around the surface's own albedo.

uniform vec4 surface_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Frequency held at 0.5 Hz (one full cycle every 2 seconds); must not exceed 1 Hz.
uniform float shimmer_frequency : hint_range(0.0, 1.0) = 0.5;
// Amplitude capped at 0.08 — saturation modulates by no more than +/-8%.
uniform float shimmer_amplitude : hint_range(0.0, 0.08) = 0.08;
uniform float activation : hint_range(0.0, 1.0) = 0.0;

const float TWO_PI = 6.28318530718;

vec3 _rgb_to_hsv(vec3 c) {
	float max_c = max(c.r, max(c.g, c.b));
	float min_c = min(c.r, min(c.g, c.b));
	float delta = max_c - min_c;
	float h = 0.0;
	if (delta > 0.0) {
		if (max_c == c.r) {
			h = mod((c.g - c.b) / delta, 6.0);
		} else if (max_c == c.g) {
			h = ((c.b - c.r) / delta) + 2.0;
		} else {
			h = ((c.r - c.g) / delta) + 4.0;
		}
		h /= 6.0;
		if (h < 0.0) {
			h += 1.0;
		}
	}
	float s = (max_c <= 0.0) ? 0.0 : delta / max_c;
	float v = max_c;
	return vec3(h, s, v);
}

vec3 _hsv_to_rgb(vec3 hsv) {
	float h = hsv.x * 6.0;
	float s = hsv.y;
	float v = hsv.z;
	float c = v * s;
	float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));
	float m = v - c;
	vec3 rgb;
	if (h < 1.0) {
		rgb = vec3(c, x, 0.0);
	} else if (h < 2.0) {
		rgb = vec3(x, c, 0.0);
	} else if (h < 3.0) {
		rgb = vec3(0.0, c, x);
	} else if (h < 4.0) {
		rgb = vec3(0.0, x, c);
	} else if (h < 5.0) {
		rgb = vec3(x, 0.0, c);
	} else {
		rgb = vec3(c, 0.0, x);
	}
	return rgb + vec3(m, m, m);
}

void fragment() {
	vec3 hsv = _rgb_to_hsv(surface_color.rgb);
	float wave = sin(TIME * TWO_PI * shimmer_frequency);
	float modulator = wave * shimmer_amplitude * activation;
	hsv.y = clamp(hsv.y * (1.0 + modulator), 0.0, 1.0);
	ALBEDO = _hsv_to_rgb(hsv);
	ALPHA = surface_color.a;
}
