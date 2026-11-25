shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Ground ring: rotating dashes (controlled player), solid glow, or pulsing (targets).
uniform vec4 color : source_color = vec4(0.36, 0.88, 1.0, 0.9);
uniform float dashes = 10.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float r = 0.78 + pulse * 0.12 * sin(TIME * 6.0);
	float fw = fwidth(d) + 0.002;
	float ring = 1.0 - smoothstep(0.08 - fw, 0.08 + fw, abs(d - r));
	if (dashes > 0.0) {
		float a = atan(p.y, p.x) / 6.2831 + TIME * 0.15;
		ring *= step(0.35, fract(a * dashes));
	}
	float glow = exp(-pow((d - r) * 6.0, 2.0)) * 0.35;
	float inner = (1.0 - smoothstep(0.0, r, d)) * 0.12;
	ALBEDO = color.rgb;
	ALPHA = clamp((ring + glow + inner) * color.a, 0.0, 1.0);
}
