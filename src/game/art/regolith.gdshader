shader_type spatial;
// Lunar regolith: grey dust with scattered craters.
varying vec3 wpos;
vec2 h2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float craters(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float shade = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 c = o + h2(i + o) * 0.8 + 0.1;
		float r = 0.15 + hash(i + o) * 0.3;
		float d = length(f - c) / r;
		shade += (smoothstep(0.7, 1.0, d) * (1.0 - smoothstep(1.0, 1.25, d))) * 0.5 - (1.0 - smoothstep(0.0, 0.8, d)) * 0.25;
	}
	return shade;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float n = noise(p * 0.05) * 0.6 + noise(p * 0.5) * 0.4;
	float c = craters(p / 40.0);
	vec3 col = vec3(0.36, 0.36, 0.38) * (0.75 + n * 0.45 + c * 0.5);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
