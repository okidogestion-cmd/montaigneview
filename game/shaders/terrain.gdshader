shader_type spatial;
// Sol de la vallée : éclairage doux + textures par terrain (art/sol_*.jpg : Higgsfield, et photos de roche
// et de terre du pack « Hills ») et relief (art/relief_*.jpg). Les images sont préparées en « cartes de détail » :
// 0,5 = couleur de la zone inchangée, plus clair ou plus sombre autour (moyenne 0,5). La couleur
// moyenne reste donc celle de la zone (couleur de sommet) : le camouflage ne change pas.
render_mode cull_back;

uniform sampler2D tex_neige : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_roche : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_herbe : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_foret : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_sable : filter_linear_mipmap, repeat_enable;
// Cartes de relief (normales) : la lumière accroche les fissures de la roche et les bosses du sol.
uniform sampler2D nrm_roche : filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_herbe : filter_linear_mipmap, repeat_enable;
uniform float relief = 0.9;
uniform float tile = 7.0;          // mètres couverts par une texture
uniform float detail = 0.85;       // force du détail (0 : couleurs unies comme avant)
uniform float patches = 0.0;
uniform float band = 0.5;

varying vec3 world_pos;
varying vec3 world_n;
varying vec4 w4;   // poids neige, roche, herbe, forêt (le reste : sable)

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
	w4 = vec4(UV, UV2);
}

// Texture vue d'en haut, mélangée à une deuxième plus grande pour casser la répétition ;
// au loin, la grande échelle l'emporte (sinon la répétition dessine des rayures sur la montagne).
vec3 planar(sampler2D t, vec2 p, float far_mix) {
	vec3 big = mix(texture(t, p / (tile * 4.3) + vec2(0.37, 0.61)).rgb, texture(t, p / (tile * 17.0) + vec2(0.71, 0.13)).rgb, far_mix * 0.6);
	return mix(texture(t, p / tile).rgb, big, far_mix);
}
// Roche : projetée aussi sur les côtés, pour que les falaises ne soient pas étirées.
vec3 triplanar(sampler2D t, vec3 p, vec3 n, float far_mix) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= b.x + b.y + b.z;
	vec3 sx = mix(texture(t, p.zy / tile).rgb, texture(t, p.zy / (tile * 4.3) + vec2(0.37, 0.61)).rgb, far_mix);
	vec3 sz = mix(texture(t, p.xy / tile).rgb, texture(t, p.xy / (tile * 4.3) + vec2(0.37, 0.61)).rgb, far_mix);
	return sx * b.x + planar(t, p.xz, far_mix) * b.y + sz * b.z;
}

vec2 nm(sampler2D t, vec2 uv) {
	return texture(t, uv).xy * 2.0 - 1.0;
}
// Inclinaison de la normale par la carte de relief, projetée comme la texture (trois plans pour la roche).
vec3 bump_tri(sampler2D t, vec3 p, vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= b.x + b.y + b.z;
	vec2 tx = nm(t, p.zy / tile);
	vec2 ty = nm(t, p.xz / tile);
	vec2 tz = nm(t, p.xy / tile);
	return vec3(0.0, tx.y, tx.x) * b.x + vec3(ty.x, 0.0, ty.y) * b.y + vec3(tz.x, tz.y, 0.0) * b.z;
}

void fragment() {
	vec3 c = grade(pow(COLOR.rgb, vec3(2.2)));
	vec3 off = vec3(0.0);
	if (w4.y > 0.01) off += bump_tri(nrm_roche, world_pos, world_n) * w4.y;
	if (w4.z + w4.w > 0.01) {
		vec2 g = nm(nrm_herbe, world_pos.xz / (tile * 0.5));
		off += vec3(g.x, 0.0, g.y) * (w4.z + w4.w) * 0.6;
	}
	float near_b = 1.0 - smoothstep(60.0, 180.0, distance(CAMERA_POSITION_WORLD, world_pos));
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(normalize(world_n) + off * relief * near_b), 0.0)).xyz);
	float far_mix = mix(0.35, 0.9, smoothstep(70.0, 320.0, distance(CAMERA_POSITION_WORLD, world_pos)));
	float ws = clamp(1.0 - (w4.x + w4.y + w4.z + w4.w), 0.0, 1.0);
	vec3 d = vec3(0.0);
	if (w4.x > 0.01) d += planar(tex_neige, world_pos.xz, far_mix) * 2.0 * w4.x;
	if (w4.y > 0.01) d += triplanar(tex_roche, world_pos, world_n, far_mix) * 2.0 * w4.y;
	if (w4.z > 0.01) d += planar(tex_herbe, world_pos.xz, far_mix) * 2.0 * w4.z;
	if (w4.w > 0.01) d += planar(tex_foret, world_pos.xz, far_mix) * 2.0 * w4.w;
	if (ws > 0.01) d += planar(tex_sable, world_pos.xz, far_mix) * 2.0 * ws;
	c *= mix(vec3(1.0), d, detail);
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
	float lit = clamp((ndl + 0.1) / 1.1, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * cloud_shadow(world_pos.xz, TIME);
}
