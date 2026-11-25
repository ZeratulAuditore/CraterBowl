shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Midfield crater emblem: ring, crater bowl, crescent and orbit arc. Original art.
uniform vec3 ink : source_color = vec3(0.96, 0.96, 0.94);
uniform vec3 accent : source_color = vec3(0.36, 0.88, 1.0);
float ring(float d, float r, float w) {
	float fw = fwidth(d) + 0.0005;
	return 1.0 - smoothstep(w - fw, w + fw, abs(d - r));
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float a = 0.0;
	vec3 col = ink;
	a = max(a, ring(d, 0.92, 0.04));
	a = max(a, ring(d, 0.80, 0.015));
	// Crater: filled disc with an inner shadow rim.
	float crater = 1.0 - smoothstep(0.48, 0.5, length(p * vec2(1.0, 1.6) - vec2(0.0, 0.22)));
	float inner = 1.0 - smoothstep(0.36, 0.38, length(p * vec2(1.0, 1.6) - vec2(0.0, 0.17)));
	a = max(a, (crater - inner) * 0.9);
	// Crescent moon above.
	float moon = (1.0 - smoothstep(0.24, 0.255, length(p - vec2(0.0, -0.35))))
		* smoothstep(0.2, 0.215, length(p - vec2(0.1, -0.43)));
	a = max(a, moon);
	// Orbit arc in accent color.
	float orbit = ring(length(p * vec2(1.0, 2.8) - vec2(0.0, -0.3)), 0.62, 0.025) * step(0.0, p.y + 0.2);
	col = mix(col, accent, orbit);
	a = max(a, orbit);
	ALBEDO = col;
	ALPHA = a * 0.82;
}
