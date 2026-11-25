shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Pre-snap line-of-scrimmage barrier: a faint hex force field that scrolls upward,
// brightens near athletes (reveal), ripples where someone runs into it, and
// dissolves cell by cell at the snap (drop 0 -> 1).
uniform vec4 color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float width_m = 53.0;
uniform float height_m = 2.4;
uniform float hex_size = 0.36;
uniform float drop = 0.0;
uniform vec4 reveal[8];   // x = field x (m), y = strength 0..1
uniform vec4 ripple[4];   // x = field x (m), y = age 0..1 (negative = unused)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Returns (distance to cell edge, cell id).
vec3 hex_cell(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	bool first = dot(h.xy, h.xy) < dot(h.zw, h.zw);
	vec2 d = first ? h.xy : h.zw;
	vec2 id = first ? hc.xy : hc.zw + 0.5;
	vec2 a = abs(d);
	return vec3(0.5 - max(dot(a, s * 0.5), a.x), id);
}

void fragment() {
	vec2 m = vec2(UV.x * width_m, (1.0 - UV.y) * height_m);
	vec3 hc = hex_cell(m / hex_size + vec2(0.0, -TIME * 0.35));
	float n = hash(hc.yz);
	float edge = 1.0 - smoothstep(0.0, 0.07, hc.x);
	float pulse = 0.5 + 0.5 * sin(TIME * 1.7 + n * 6.2831);
	float rev = 0.0;
	for (int i = 0; i < 8; i++) {
		rev = max(rev, reveal[i].y * (1.0 - smoothstep(0.0, 3.2, abs(m.x - reveal[i].x))));
	}
	float rip = 0.0;
	for (int i = 0; i < 4; i++) {
		float age = ripple[i].y;
		if (age >= 0.0 && age < 1.0) {
			float r = length(vec2(m.x - ripple[i].x, m.y - 1.0));
			rip = max(rip, (1.0 - smoothstep(0.0, 0.45, abs(r - age * 5.0))) * (1.0 - age));
		}
	}
	float top = 1.0 - smoothstep(0.55, 1.0, m.y / height_m);
	float fill = 0.025 + 0.02 * pulse + rev * 0.12 + rip * 0.35;
	float lines = edge * (0.10 + 0.05 * pulse + rev * 0.55 + rip * 0.9);
	float keep = step(drop, n * 0.98 + 0.01);
	float foot = exp(-m.y * 7.0) * (0.35 + rev * 0.4);
	ALBEDO = color.rgb;
	ALPHA = clamp(((fill + lines) * top + foot) * keep * (1.0 - drop * 0.6), 0.0, 1.0) * color.a;
}
