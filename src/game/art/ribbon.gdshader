shader_type spatial;
render_mode unshaded, cull_disabled;
// LED ribbon board: scrolling chevrons in team colors, flashes when excited.
uniform float height = 1.3;
uniform float excite = 0.0;
uniform vec3 a : source_color = vec3(0.95, 0.75, 0.15);
uniform vec3 b : source_color = vec3(0.3, 0.8, 0.95);
void fragment() {
	float u = UV.x / height;
	float v = UV.y;
	float scroll = u * 0.5 - TIME * (0.6 + excite * 2.0);
	float chev = fract(scroll + abs(v - 0.5) * 0.6);
	vec3 col = mix(a, b, step(0.5, fract(u * 0.02 - TIME * 0.05)));
	float band = smoothstep(0.45, 0.5, chev) * (1.0 - smoothstep(0.8, 0.85, chev));
	// LED pixel grid.
	vec2 g = fract(vec2(u * 10.0, v * 10.0));
	float px = smoothstep(0.0, 0.2, g.x) * smoothstep(1.0, 0.8, g.x) * smoothstep(0.0, 0.2, g.y) * smoothstep(1.0, 0.8, g.y);
	float flash = excite * (0.5 + 0.5 * sin(TIME * 18.0));
	vec3 base = vec3(0.02, 0.03, 0.06);
	ALBEDO = (base + col * (band * 1.6 + 0.15 + flash)) * (0.55 + 0.45 * px);
}
