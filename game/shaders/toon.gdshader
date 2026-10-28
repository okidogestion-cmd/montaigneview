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
// Détail peint (art/sol_*.jpg, carte de détail centrée sur 0,5) projeté en coordonnées du monde : rochers.
uniform bool use_detail = false;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float detail_tile = 2.5;
uniform bool use_relief = false;
uniform sampler2D detail_nrm : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying vec3 world_n;

#include "res://shaders/clouds.gdshaderinc"
#include "res://shaders/grade.gdshaderinc"

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	if (use_detail) {
		vec3 b = pow(abs(world_n), vec3(4.0));
		b /= b.x + b.y + b.z;
		vec3 p = world_pos / detail_tile;
		vec3 d = texture(detail_tex, p.zy).rgb * b.x + texture(detail_tex, p.xz).rgb * b.y + texture(detail_tex, p.xy).rgb * b.z;
		c *= mix(vec3(1.0), d * 2.0, 0.9);
		if (use_relief) {
			vec2 tx = texture(detail_nrm, p.zy).xy * 2.0 - 1.0;
			vec2 ty = texture(detail_nrm, p.xz).xy * 2.0 - 1.0;
			vec2 tz = texture(detail_nrm, p.xy).xy * 2.0 - 1.0;
			vec3 off = vec3(0.0, tx.y, tx.x) * b.x + vec3(ty.x, 0.0, ty.y) * b.y + vec3(tz.x, tz.y, 0.0) * b.z;
			NORMAL = normalize((VIEW_MATRIX * vec4(normalize(world_n + off * 0.9), 0.0)).xyz);
		}
	}
	if (patches > 0.0) {
		float n = vnoise(world_pos.xz * 0.045) * 0.6 + vnoise(world_pos.xz * 0.21) * 0.3 + vnoise(world_pos.xz * 0.9) * 0.1;
		c *= 1.0 + (smoothstep(0.52, 0.58, n) - 0.5) * patches;
	}
	ALBEDO = grade(c);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	// Éclairage doux (Lambert légèrement enveloppant), plus un liseré discret sur les bords au soleil.
	float lit = clamp((ndl + 0.1) / 1.1, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * lit * rim_strength * 0.4;
	DIFFUSE_LIGHT += LIGHT_COLOR * (lit + rim) * cloud_shadow(world_pos.xz, TIME);
}
