shader_type canvas_item;

uniform vec4 primary_color : source_color = vec4(0.48, 0.36, 0.88, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.88, 0.72, 0.30, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float direction = 1.0;

float hash21(vec2 point) {
	point = fract(point * vec2(127.13, 311.71));
	point += dot(point, point + 37.19);
	return fract(point.x * point.y);
}

void fragment() {
	float axis = (UV.x + (1.0 - UV.y) * 0.32) / 1.32;
	if (direction < 0.0) {
		axis = 1.0 - axis;
	}
	float tear = (hash21(floor(UV * vec2(34.0, 19.0))) - 0.5) * 0.105;
	float threshold = mix(-0.12, 1.12, progress);
	float signed_edge = threshold - (axis + tear);
	float fill_mask = smoothstep(-0.012, 0.012, signed_edge);
	float accent_band = smoothstep(0.012, 0.035, signed_edge)
		* (1.0 - smoothstep(0.075, 0.13, signed_edge));
	float ink_band = smoothstep(-0.006, 0.008, signed_edge)
		* (1.0 - smoothstep(0.008, 0.026, signed_edge));
	vec3 color = mix(primary_color.rgb, secondary_color.rgb, accent_band);
	color = mix(color, vec3(0.035, 0.03, 0.045), ink_band);
	COLOR = vec4(color, fill_mask);
}
