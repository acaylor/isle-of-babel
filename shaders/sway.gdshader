shader_type spatial;
render_mode cull_disabled;

// Wind sway for triangle-soup flora. Displacement is weighted by the
// vertex's height in unscaled mesh space (VERTEX is pre-instance-transform
// even under MultiMesh), so trunk bases stay planted while tops move, and
// the same mesh works at any instance scale. World position drives the
// phase so neighboring instances never sway in lockstep.
uniform float sway_amp = 0.05;
uniform float sway_freq = 0.9;
uniform float weight_start = 1.2;
uniform float weight_full = 4.5;

// Vertex colors are authored sRGB (see Forge.vc_mat); convert exactly as
// StandardMaterial3D's vertex_color_is_srgb does or the palette shifts.
vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = smoothstep(weight_start, weight_full, VERTEX.y);
	float ph = wpos.x * 0.35 + wpos.z * 0.28;
	VERTEX.x += sin(TIME * sway_freq + ph) * sway_amp * w;
	VERTEX.z += cos(TIME * sway_freq * 0.8 + ph * 1.3) * sway_amp * 0.7 * w;
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
