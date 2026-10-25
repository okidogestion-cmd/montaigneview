shader_type sky;
// Ciel peint : dégradé bleu franc, soleil net, gros nuages cartoon qui dérivent.

uniform vec3 top_color : source_color = vec3(0.16, 0.48, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.86, 0.96);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.80, 0.92);
uniform float cloud_cover = 0.52;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return s;
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.55));
	if (d.y < 0.0) col = horizon_color;
	// Soleil
	float s = dot(d, normalize(LIGHT0_DIRECTION));
	col = mix(col, vec3(1.0, 0.97, 0.85), smoothstep(0.9985, 0.9992, s));
	col += vec3(1.0, 0.9, 0.7) * pow(max(s, 0.0), 60.0) * 0.25;
	// Nuages projetés sur un plan haut
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.18) * 1.4 + vec2(37.3 + TIME * 0.006, 11.7 + TIME * 0.002);
		float n = fbm(uv);
		float edge = smoothstep(cloud_cover, cloud_cover + 0.02, n);
		float inner = smoothstep(cloud_cover + 0.06, cloud_cover + 0.08, fbm(uv + vec2(0.05, 0.09)));
		vec3 cc = mix(cloud_shade, cloud_color, inner);
		col = mix(col, cc, edge * smoothstep(0.04, 0.22, d.y));
	}
	COLOR = col;
}
