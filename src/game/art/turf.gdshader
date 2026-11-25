shader_type spatial;
render_mode cull_back;
// Field surface in world space. Sim (x, y) yards == world (x, -z).
uniform float field_w = 53.33;
uniform float field_len = 100.0;
uniform float ez = 10.0;
uniform float hash_inset = 23.36;   // distance of the inbound hashes from each sideline
uniform vec3 home_color : source_color = vec3(0.95, 0.75, 0.15);
uniform vec3 away_color : source_color = vec3(0.3, 0.8, 0.95);
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// Antialiased band of width w centred on d == 0.
float band(float d, float w) {
	float fw = fwidth(d) * 0.75 + 0.0001;
	return 1.0 - smoothstep(w * 0.5 - fw, w * 0.5 + fw, abs(d));
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = vec2(wpos.x, -wpos.z);
	bool in_x = p.x >= 0.0 && p.x <= field_w;
	bool in_y = p.y >= -ez && p.y <= field_len + ez;
	bool inside = in_x && in_y;
	// Grass: 5-yard mowing stripes + clumpy noise + fine blade grain.
	float stripe = mod(floor((p.y + 1000.0) / 5.0), 2.0);
	float n = noise(p * 0.35) * 0.6 + noise(p * 2.7) * 0.3 + hash(floor(p * 18.0)) * 0.1;
	vec3 grass_a = vec3(0.085, 0.22, 0.11);
	vec3 grass_b = vec3(0.11, 0.27, 0.135);
	vec3 gt = texture(grass_tex, p / 3.0).rgb;
	float gl = dot(gt, vec3(0.333));
	vec3 col = mix(grass_a, grass_b, stripe) * (0.8 + n * 0.2) * (0.55 + gl * 1.1);
	// End zones: team-tinted turf with diagonal stripes.
	if (inside && (p.y < 0.0 || p.y > field_len)) {
		vec3 tc = p.y < 0.0 ? home_color : away_color;
		float diag = step(0.5, fract((p.x + p.y) / 4.0));
		col = mix(col, tc * (0.55 + 0.12 * diag) * (0.9 + n * 0.2), 0.78);
	}
	// Outside the field: a white border band, then darker worn apron.
	float dx = max(max(-p.x, p.x - field_w), 0.0);
	float dy = max(max(-ez - p.y, p.y - field_len - ez), 0.0);
	float out_d = max(dx, dy);
	if (!inside) {
		col *= 0.62;
		col = mix(col, vec3(0.75), step(out_d, 1.6) * 0.92);
	}
	// Lines.
	float lines = 0.0;
	if (in_y) {
		lines = max(lines, band(p.x, 0.36));
		lines = max(lines, band(p.x - field_w, 0.36));
	}
	if (in_x) {
		lines = max(lines, band(p.y + ez, 0.36));
		lines = max(lines, band(p.y - field_len - ez, 0.36));
		lines = max(lines, band(p.y, 0.4));
		lines = max(lines, band(p.y - field_len, 0.4));
		if (p.y > 0.0 && p.y < field_len) {
			lines = max(lines, band(mod(p.y + 2.5, 5.0) - 2.5, 0.13) * step(0.6, min(p.x, field_w - p.x)));
			// One-yard ticks: sideline ticks + inbound hashes.
			float tick = band(mod(p.y + 0.5, 1.0) - 0.5, 0.1);
			float xs = min(p.x, field_w - p.x);
			float near_side = step(0.4, xs) * step(xs, 1.1);
			float hash_m = step(abs(xs - hash_inset), 0.35);
			lines = max(lines, tick * max(near_side, hash_m));
		}
		// 2-point try marks.
		lines = max(lines, band(p.y - 3.0, 0.1) * step(abs(p.x - field_w * 0.5), 0.5));
		lines = max(lines, band(p.y - field_len + 3.0, 0.1) * step(abs(p.x - field_w * 0.5), 0.5));
	}
	col = mix(col, vec3(0.8, 0.81, 0.8), lines * 0.94);
	ALBEDO = col;
	NORMAL_MAP = mix(texture(grass_nrm, p / 3.0).rgb, vec3(0.5, 0.5, 1.0), 0.5 + lines * 0.5);
	ROUGHNESS = 0.92 - lines * 0.2;
	SPECULAR = 0.25;
}
