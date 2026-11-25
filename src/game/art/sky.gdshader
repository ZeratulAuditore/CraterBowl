shader_type sky;
// Lunar night sky: dense starfield, faint galactic band, and Earth hanging low.
uniform vec3 earth_dir = vec3(0.55, 0.32, -0.77);
uniform float earth_size = 0.075;
uniform sampler2D panorama : source_color, filter_linear, hint_default_black;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float stars(vec3 d, float scale, float thresh) {
	vec3 c = floor(d * scale);
	float h = hash(c);
	vec3 f = fract(d * scale) - 0.5;
	float s = smoothstep(thresh, 1.0, h) * (1.0 - smoothstep(0.0, 0.32, length(f)));
	return s;
}
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void sky() {
	vec3 d = normalize(EYEDIR);
	// CC0 Kenney space panorama (equirectangular) + a few hot stars for bloom.
	vec2 uv = vec2(atan(d.x, -d.z) / 6.2831853 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	vec3 col = texture(panorama, uv).rgb * 0.9;
	col += vec3(0.8, 0.88, 1.0) * stars(d, 90.0, 0.994) * 2.5;
	// Earth: day side lit from the "sun", blue oceans, cloud swirls, atmosphere rim.
	vec3 e = normalize(earth_dir);
	float ang = acos(clamp(dot(d, e), -1.0, 1.0));
	if (ang < earth_size * 1.25) {
		float r = ang / earth_size;
		if (r < 1.0) {
			vec3 tang = normalize(cross(e, vec3(0, 1, 0)));
			vec3 bit = cross(tang, e);
			vec2 uv = vec2(dot(d - e, tang), dot(d - e, bit)) / sin(earth_size);
			float z = sqrt(max(0.0, 1.0 - dot(uv, uv)));
			vec3 nrm = normalize(uv.x * tang + uv.y * bit + z * e);
			float lit = clamp(dot(nrm, normalize(vec3(-0.6, 0.5, 0.2))) * 1.4 + 0.1, 0.0, 1.0);
			float land = smoothstep(0.52, 0.56, n3(nrm * 5.0 + vec3(3.0)));
			float clouds = smoothstep(0.55, 0.75, n3(nrm * 9.0));
			vec3 surf = mix(vec3(0.05, 0.18, 0.5), vec3(0.2, 0.38, 0.16), land);
			surf = mix(surf, vec3(0.95), clouds * 0.85);
			col = surf * lit * 1.3 + vec3(0.2, 0.45, 1.0) * pow(1.0 - z, 3.0) * lit;
		} else {
			col += vec3(0.25, 0.5, 1.0) * (1.0 - smoothstep(1.0, 1.25, r)) * 0.5;
		}
	}
	COLOR = col;
}
