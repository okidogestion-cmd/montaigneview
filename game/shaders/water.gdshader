shader_type spatial;
// Mer cartoon : bleu profond, turquoise près des côtes, écume sur les plages
// et réseau de lignes blanches qui bougent (cellules de Voronoï).
// La profondeur vient de la carte des hauteurs du terrain.
render_mode unshaded, cull_disabled;

uniform vec3 deep : source_color = vec3(0.07, 0.30, 0.66);
uniform vec3 mid : source_color = vec3(0.12, 0.45, 0.80);
uniform vec3 shallow : source_color = vec3(0.30, 0.78, 0.82);
uniform vec3 foam : source_color = vec3(0.96, 0.99, 1.0);
uniform vec3 horizon : source_color = vec3(0.70, 0.86, 0.96);
uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform float cell = 7.0;
uniform float grid = 201.0;
uniform float half_size = 700.0;
uniform float water_y = 26.0;

varying vec3 world_pos;

vec2 rand2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distance au bord de la cellule la plus proche (0 sur les lignes).
float cell_edge(vec2 p, float t) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = rand2(i + g);
			o = 0.5 + 0.42 * sin(t + 6.2831 * o);
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
	vec2 uv = ((world_pos.xz + half_size) / cell + 0.5) / grid;
	float depth = water_y - texture(heightmap, uv).r;
	vec3 c = mix(shallow, mid, smoothstep(0.5, 6.0, depth));
	c = mix(c, deep, smoothstep(8.0, 40.0, depth));
	float dist = length(VERTEX);
	// Lignes blanches qui bougent, de plus en plus fines au loin.
	vec2 p = world_pos.xz * 0.085 + vec2(TIME * 0.03, TIME * 0.018);
	p += 0.22 * vec2(sin(p.y * 1.7 + TIME * 0.8), cos(p.x * 1.5 + TIME * 0.7));  // lignes ondulées
	float e = cell_edge(p, TIME * 0.5);
	float w = mix(0.045, 0.015, smoothstep(30.0, 400.0, dist));
	float lines = 1.0 - smoothstep(w * 0.6, w, e);
	// Lignes interrompues par endroits, comme des reflets.
	lines *= smoothstep(0.25, 0.55, fract(sin(dot(floor(p * 0.5), vec2(41.3, 17.9))) * 9131.7) * 0.6 + 0.2 + 0.4 * sin(p.x * 0.9 + p.y * 0.7 + TIME * 0.4));
	lines *= 0.8 * (1.0 - smoothstep(250.0, 900.0, dist));
	// Écume des plages, qui respire
	float shore = 1.0 - smoothstep(0.3, 1.0 + 0.4 * sin(TIME * 1.3 + world_pos.x * 0.12 + world_pos.z * 0.08), depth);
	c = mix(c, foam, max(shore, lines));
	// Brume de l'horizon
	c = mix(c, horizon, smoothstep(600.0, 2600.0, dist) * 0.85);
	ALBEDO = c;
}
