shader_type spatial;
// Sol de la vallée : ombrage cartoon de toon.gdshader + textures peintes par terrain
// (art/sol_*.jpg, créées avec Higgsfield). Les images sont préparées en « cartes de détail » :
// 0,5 = couleur de la zone inchangée, plus clair ou plus sombre autour (moyenne 0,5). La couleur
// moyenne reste donc celle de la zone (couleur de sommet) : le camouflage ne change pas.
render_mode cull_back;

uniform sampler2D tex_neige : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_roche : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_herbe : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_foret : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_sable : filter_linear_mipmap, repeat_enable;
uniform float tile = 7.0;          // mètres couverts par une texture
uniform float detail = 0.85;       // force du détail (0 : couleurs unies comme avant)
uniform float patches = 0.0;
uniform float band = 0.5;

varying vec3 world_pos;
varying vec3 world_n;
varying vec4 w4;   // poids neige, roche, herbe, forêt (le reste : sable)

#include "res://shaders/clouds.gdshaderinc"

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

// Texture vue d'en haut, mélangée à une deuxième plus grande pour casser la répétition.
vec3 planar(sampler2D t, vec2 p) {
	return mix(texture(t, p / tile).rgb, texture(t, p / (tile * 4.3) + vec2(0.37, 0.61)).rgb, 0.35);
}
// Roche : projetée aussi sur les côtés, pour que les falaises ne soient pas étirées.
vec3 triplanar(sampler2D t, vec3 p, vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= b.x + b.y + b.z;
	return texture(t, p.zy / tile).rgb * b.x + planar(t, p.xz) * b.y + texture(t, p.xy / tile).rgb * b.z;
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float ws = clamp(1.0 - (w4.x + w4.y + w4.z + w4.w), 0.0, 1.0);
	vec3 d = vec3(0.0);
	if (w4.x > 0.01) d += planar(tex_neige, world_pos.xz) * 2.0 * w4.x;
	if (w4.y > 0.01) d += triplanar(tex_roche, world_pos, world_n) * 2.0 * w4.y;
	if (w4.z > 0.01) d += planar(tex_herbe, world_pos.xz) * 2.0 * w4.z;
	if (w4.w > 0.01) d += planar(tex_foret, world_pos.xz) * 2.0 * w4.w;
	if (ws > 0.01) d += planar(tex_sable, world_pos.xz) * 2.0 * ws;
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
	float lit = smoothstep(band - 0.07, band + 0.07, ndl * 0.5 + 0.5);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * cloud_shadow(world_pos.xz, TIME);
}
