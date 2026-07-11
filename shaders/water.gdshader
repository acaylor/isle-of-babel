shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color: source_color = vec3(0.03, 0.14, 0.18);
uniform vec3 shallow_color: source_color = vec3(0.13, 0.40, 0.44);
uniform vec3 foam_color: source_color = vec3(0.82, 0.90, 0.88);
// World-space depth over which shallow color fades to deep.
uniform float depth_fade: hint_range(0.5, 30.0) = 7.0;
uniform float foam_width: hint_range(0.05, 3.0) = 0.45;
uniform sampler2D depth_texture: hint_depth_texture, filter_linear, repeat_disable;

varying vec3 world_pos;

// Broad swell displacing the mesh; its analytic gradient feeds the normal
// so lighting follows the waves (vertex displacement alone leaves normals
// pointing straight up).
float swell(vec2 p) {
	return sin(p.x * 0.12 + TIME * 0.8) * 0.16
			+ cos(p.y * 0.10 + TIME * 0.6) * 0.16
			+ sin((p.x + p.y) * 0.05 + TIME * 0.4) * 0.22;
}

vec2 swell_grad(vec2 p) {
	vec2 g = vec2(0.0);
	g.x += 0.12 * cos(p.x * 0.12 + TIME * 0.8) * 0.16;
	g.y += -0.10 * sin(p.y * 0.10 + TIME * 0.6) * 0.16;
	g += vec2(0.05) * cos((p.x + p.y) * 0.05 + TIME * 0.4) * 0.22;
	return g;
}

// Fine ripples evaluated per-fragment: gradient of three directional sine
// waves. Amplitudes are height * frequency (gradient of a*sin(f*dot(p,d)))
// kept small so glints shimmer without turning the lake choppy.
vec2 ripple_grad(vec2 p) {
	const vec2 d1 = vec2(0.94374, 0.33062);
	const vec2 d2 = vec2(-0.51450, 0.85749);
	const vec2 d3 = vec2(0.19612, -0.98058);
	vec2 g = vec2(0.0);
	g += d1 * cos(dot(p, d1) * 0.9 + TIME * 1.5) * 0.050;
	g += d2 * cos(dot(p, d2) * 1.7 + TIME * 2.1) * 0.055;
	g += d3 * cos(dot(p, d3) * 3.1 + TIME * 2.6) * 0.045;
	return g;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), u.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += swell(world_pos.xz);
}

void fragment() {
	// Reconstruct the opaque scene's depth under this fragment (Forward+
	// NDC), then how much water lies between the surface and it.
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	float water_depth = max(-scene_view.z - -VERTEX.z, 0.0);
	// View-space depth stretches at grazing angles; scale by the view ray's
	// verticality so the fade reads as true water-column depth.
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	water_depth *= max(abs(view_world.y), 0.08);

	vec2 grad = swell_grad(world_pos.xz) + ripple_grad(world_pos.xz);
	vec3 n_world = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float df = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, df);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, shallow_color, fresnel * 0.35);

	// Foam: a noise-broken band where the water meets terrain, with a slow
	// lapping pulse traveling toward the shore.
	float edge_noise = vnoise(world_pos.xz * 1.4 + vec2(TIME * 0.15, -TIME * 0.11));
	float band = foam_width * (0.5 + 0.8 * edge_noise);
	float shore = 1.0 - smoothstep(0.0, band, water_depth);
	float lap = 0.6 + 0.4 * sin(water_depth * 5.0 - TIME * 1.7 + edge_noise * 4.0);
	float foam = shore * lap;
	col = mix(col, foam_color, foam * 0.75);

	ALBEDO = col;
	ROUGHNESS = 0.14 + foam * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.45;
	ALPHA = mix(0.72, 0.95, df);
	ALPHA = max(ALPHA, foam * 0.95);
}
