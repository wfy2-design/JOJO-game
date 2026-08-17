shader_type canvas_item;

uniform vec4 theme_color : source_color = vec4(0.48, 0.36, 0.88, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float direction = 1.0;
uniform float remove_white = 0.0;
uniform float edge_softness = 0.012;
uniform float tear_amount = 0.075;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float white = smoothstep(0.90, 0.995, min(tex.r, min(tex.g, tex.b)));
	float source_mask = tex.a * (1.0 - white * remove_white);

	float axis = (UV.x + (1.0 - UV.y) * 0.24) / 1.24;
	if (direction < 0.0) {
		axis = 1.0 - axis;
	}
	vec2 tear_cell = floor(UV * vec2(26.0, 15.0));
	float tear = (hash21(tear_cell) - 0.5) * tear_amount;
	float threshold = mix(-0.10, 1.10, progress);
	float wipe_mask = 1.0 - smoothstep(
		threshold - edge_softness,
		threshold + edge_softness,
		axis + tear
	);

	COLOR = vec4(theme_color.rgb, source_mask * wipe_mask * 0.96);
}
