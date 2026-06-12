shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color: source_color = vec3(0.03, 0.14, 0.18);
uniform vec3 shallow_color: source_color = vec3(0.12, 0.38, 0.42);

void vertex() {
	float w = sin(VERTEX.x * 0.12 + TIME * 0.8) * 0.16
			+ cos(VERTEX.z * 0.10 + TIME * 0.6) * 0.16
			+ sin((VERTEX.x + VERTEX.z) * 0.05 + TIME * 0.4) * 0.22;
	VERTEX.y += w;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color, shallow_color, fresnel * 0.9);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	ALPHA = 0.93;
}
