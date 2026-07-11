shader_type sky;

uniform vec3 top_color: source_color = vec3(0.23, 0.41, 0.62);
uniform vec3 horizon_color: source_color = vec3(0.74, 0.76, 0.70);
uniform vec3 ground_bottom_color: source_color = vec3(0.12, 0.16, 0.18);
uniform vec3 ground_horizon_color: source_color = vec3(0.66, 0.69, 0.64);
uniform vec3 cloud_color: source_color = vec3(0.99, 0.98, 0.95);
uniform vec3 cloud_shadow_color: source_color = vec3(0.62, 0.67, 0.72);
uniform float cloud_coverage: hint_range(0.0, 1.0) = 0.45;
uniform float cloud_drift = 0.006;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.13 + vec2(31.7, -17.3);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 col;
	if (dir.y < 0.0) {
		col = mix(ground_horizon_color, ground_bottom_color, clamp(-dir.y * 2.5, 0.0, 1.0));
	} else {
		col = mix(horizon_color, top_color, pow(clamp(dir.y, 0.0, 1.0), 0.42));

		if (LIGHT0_ENABLED) {
			float sun_amount = clamp(dot(dir, LIGHT0_DIRECTION), 0.0, 1.0);
			// Disc, tight halo, and a broad warm haze around the sun.
			col = mix(col, LIGHT0_COLOR * LIGHT0_ENERGY * 40.0,
					smoothstep(0.99965, 0.99985, sun_amount));
			col += LIGHT0_COLOR * pow(sun_amount, 300.0) * 0.9;
			col += LIGHT0_COLOR * pow(sun_amount, 6.0) * 0.10;
		}

		// Clouds live on a flat plane overhead; dividing by dir.y projects
		// the view ray onto it (the +0.12 tames the stretch at the horizon).
		vec2 uv = dir.xz / (dir.y + 0.12) * 0.32 + TIME * cloud_drift * vec2(1.0, 0.35);
		// fbm of value noise centers near 0.48 with a narrow spread, so the
		// threshold band sits inside that range or clouds vanish entirely.
		float density = fbm(uv * 1.5);
		float base = 0.62 - cloud_coverage * 0.4;
		float cloud = smoothstep(base, base + 0.24, density);
		// Sample density displaced toward the sun: thinner ahead means a
		// lit edge, thicker means self-shadowed body.
		float toward_sun = fbm(uv * 1.5 + LIGHT0_DIRECTION.xz * 0.18);
		float lit = clamp(0.5 + (density - toward_sun) * 3.0, 0.0, 1.0);
		vec3 c_col = mix(cloud_shadow_color, cloud_color, lit);
		// Fade clouds into the haze at the horizon.
		cloud *= smoothstep(0.0, 0.12, dir.y);
		col = mix(col, c_col, cloud * 0.92);
	}
	COLOR = col;
}
