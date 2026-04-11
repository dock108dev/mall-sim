shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.0, 0.737, 0.725, 1.0);
uniform float outline_width : hint_range(0.001, 0.05, 0.001) = 0.012;
uniform float pulse_speed : hint_range(0.0, 4.0, 0.1) = 1.5;
uniform float pulse_intensity : hint_range(0.0, 0.5, 0.01) = 0.15;

void vertex() {
	float pulse = sin(TIME * pulse_speed) * pulse_intensity;
	float width = outline_width + outline_width * pulse;
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
