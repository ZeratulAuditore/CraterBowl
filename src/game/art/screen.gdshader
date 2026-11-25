shader_type spatial;
render_mode unshaded;
// Jumbotron backdrop: dark navy with subtle scanlines and a cyan frame glow.
void fragment() {
	float scan = 0.9 + 0.1 * sin(UV.y * 400.0);
	vec2 e = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.03, min(e.x, e.y * 2.4));
	vec3 col = vec3(0.03, 0.05, 0.12) * scan + vec3(0.36, 0.88, 1.0) * edge * 1.6;
	ALBEDO = col;
}
