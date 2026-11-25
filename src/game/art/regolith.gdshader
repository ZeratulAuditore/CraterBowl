shader_type spatial;
// Lunar regolith: CC0 Poly Haven moon_01 texture at two scales (breaks tiling) + large crater shading.
uniform sampler2D diff : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec3 a = texture(diff, p / 6.0).rgb;
	vec3 b = texture(diff, p / 47.0).rgb;
	float n = noise(p * 0.02);
	ALBEDO = mix(a, b, 0.5) * (0.7 + n * 0.5) * vec3(0.95, 0.95, 1.0);
	NORMAL_MAP = texture(nrm, p / 6.0).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
