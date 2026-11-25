shader_type spatial;
render_mode cull_back;
// Football uniform on the rigged character. COLOR.r encodes a body region
// (baked from bone weights): 0 jersey, 1 pants, 2 sock, 3 cleat, 4 skin, 5 glove.
uniform vec4 jersey : source_color = vec4(0.95, 0.75, 0.15, 1.0);
uniform vec4 pants : source_color = vec4(0.16, 0.17, 0.22, 1.0);
uniform vec4 sock : source_color = vec4(0.7, 0.55, 0.1, 1.0);
uniform vec4 skin : source_color = vec4(0.8, 0.6, 0.45, 1.0);
uniform vec4 trim : source_color = vec4(1.0, 1.0, 1.0, 1.0);
varying float region;
void vertex() {
	region = COLOR.r * 8.0;
}
void fragment() {
	float r = floor(region + 0.5);
	vec3 c = jersey.rgb;
	float rough = 0.75;
	if (r == 1.0) { c = pants.rgb; rough = 0.65; }
	else if (r == 2.0) { c = sock.rgb; }
	else if (r == 3.0) { c = vec3(0.06, 0.06, 0.07); rough = 0.4; }
	else if (r == 4.0) { c = skin.rgb; rough = 0.55; }
	else if (r == 5.0) { c = trim.rgb * 0.9; rough = 0.5; }
	ALBEDO = c;
	ROUGHNESS = rough;
	RIM = 0.2;
	RIM_TINT = 0.6;
}
