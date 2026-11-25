shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Broadcast-style line of scrimmage / first-down line: crisp core + soft glow.
uniform vec4 color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
void fragment() {
	float v = abs(UV.y - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.18, 0.26, v);
	float glow = exp(-v * v * 5.0) * 0.45;
	float shimmer = 0.9 + 0.1 * sin(UV.x * 80.0 - TIME * 4.0);
	ALBEDO = color.rgb;
	ALPHA = clamp((core * 0.9 + glow) * shimmer, 0.0, 1.0) * color.a;
}
