shader_type spatial;
// Lagon de l'arène : bandes de couleur selon la distance aux îles (turquoise près des plages,
// bleu lagon au large), écume au rivage, lignes de vagues stylisées et discrètes.
render_mode unshaded, cull_disabled;

uniform vec3 deep : source_color = vec3(0.137, 0.557, 0.714);     // #238EB6 bleu lagon
uniform vec3 shallow : source_color = vec3(0.333, 0.827, 0.816);  // #55D3D0 turquoise
uniform vec3 foam : source_color = vec3(1.0, 0.953, 0.847);       // #FFF3D8 ivoire
uniform vec3 horizon : source_color = vec3(0.70, 0.86, 0.95);
uniform vec3 island_a = vec3(0.0, 0.0, -45.0);
uniform vec3 island_b = vec3(0.0, 0.0, 45.0);
uniform float shore_radius = 22.5;

varying vec3 world_pos;

vec2 rand2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float cell_edge(vec2 p, float t) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.5 + 0.42 * sin(t + 6.2831 * rand2(i + g));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float da = length(world_pos.xz - island_a.xz) - shore_radius;
	float db = length(world_pos.xz - island_b.xz) - shore_radius;
	float d = min(da, db);                                   // distance au rivage le plus proche
	// Bandes de couleur nettes (pas de dégradé photo) : turquoise, puis bleu lagon.
	vec3 c = mix(shallow, deep, smoothstep(5.0, 7.0, d));
	c = mix(c, deep * 0.85, smoothstep(30.0, 32.0, d));
	float dist = length(VERTEX);
	// Vagues : lignes fines qui ondulent, plus rares au loin.
	vec2 p = world_pos.xz * 0.11 + vec2(TIME * 0.03, TIME * 0.02);
	p += 0.2 * vec2(sin(p.y * 1.6 + TIME * 0.7), cos(p.x * 1.4 + TIME * 0.6));
	float e = cell_edge(p, TIME * 0.45);
	float lines = (1.0 - smoothstep(0.02, 0.04, e)) * 0.55 * (1.0 - smoothstep(60.0, 300.0, dist));
	// Écume au rivage, qui respire doucement.
	float shore = 1.0 - smoothstep(0.0, 1.2 + 0.5 * sin(TIME * 1.2 + world_pos.x * 0.3 + world_pos.z * 0.2), d);
	c = mix(c, foam, max(shore, lines));
	c = mix(c, horizon, smoothstep(250.0, 1400.0, dist) * 0.8);
	ALBEDO = c;
}
