shader_type spatial;
render_mode cull_back;
// Instanced crowd: idle sway, plus jumping/arm-waving when excited.
uniform float excite = 0.0;
varying vec3 tint;
void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float rate = 1.5 + INSTANCE_CUSTOM.y * 1.5;
	float idle = sin(TIME * rate + ph) * 0.03;
	float jump = max(0.0, sin(TIME * (7.0 + INSTANCE_CUSTOM.y * 3.0) + ph)) * 0.45 * excite;
	VERTEX.y += (idle + jump) * smoothstep(0.0, 0.3, VERTEX.y + 0.3);
	VERTEX.x += sin(TIME * rate * 0.7 + ph) * 0.04 * VERTEX.y;
	tint = COLOR.rgb;
}
void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
