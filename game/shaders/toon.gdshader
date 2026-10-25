shader_type spatial;
// Ombrage cartoon façon Wind Waker : deux tons francs, ombres bleutées.
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float wind = 0.0;          // balancement (herbe, arbres)
uniform float wind_height = 7.0;   // hauteur où le balancement est maximal
uniform float patches = 0.0;       // taches de couleur peintes sur le sol
uniform float band = 0.5;          // seuil ombre / lumière
uniform float rim_strength = 0.35; // liseré de lumière (0 pour le sol)

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wind > 0.0) {
		float k = clamp(VERTEX.y / wind_height, 0.0, 1.0);
		k *= k;
		float t = TIME * 1.6 + world_pos.x * 0.13 + world_pos.z * 0.09;
		VERTEX.x += (sin(t) + 0.4 * sin(t * 2.3)) * wind * k;
		VERTEX.z += cos(t * 0.8) * wind * 0.6 * k;
	}
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_vertex_color) {
		c *= pow(COLOR.rgb, vec3(2.2));
	}
	if (patches > 0.0) {
		float n = vnoise(world_pos.xz * 0.045) * 0.6 + vnoise(world_pos.xz * 0.21) * 0.3 + vnoise(world_pos.xz * 0.9) * 0.1;
		c *= 1.0 + (smoothstep(0.52, 0.58, n) - 0.5) * patches;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(band - 0.07, band + 0.07, ndl * 0.5 + 0.5);
	// Liseré de lumière sur les bords tournés vers le soleil : les volumes se détachent.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * lit * rim_strength;
	DIFFUSE_LIGHT += LIGHT_COLOR * (lit + rim);
}
