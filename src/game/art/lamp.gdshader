shader_type spatial;
render_mode unshaded;
// Light-tower lamp bank: grid of hot lamps (bloom picks them up).
void fragment() {
	vec2 g = fract(UV * vec2(6.0, 4.0)) - 0.5;
	float lamp = 1.0 - smoothstep(0.25, 0.32, length(g));
	ALBEDO = mix(vec3(0.05, 0.05, 0.07), vec3(1.0, 0.97, 0.9) * 5.0, lamp);
}
