shader_type spatial;
// Animaux sans squelette (bouquetin) : le shader fait marcher les pattes, balancer le corps,
// baisser la tête pour brouter et la tourner pour regarder. Modèle préparé par tools/faune.gd :
// corps le long de +z, tête vers +z, sabots à y = 0.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float walk = 0.0;         // 0 : arrêté ; 1 : marche
uniform float phase = 0.0;        // cycle des pas (radians), avancé par le script selon la distance parcourue
uniform float graze = 0.0;        // 0 : tête haute ; 1 : tête au sol (broute)
uniform float look = 0.0;         // tête tournée (radians, + vers la gauche)
uniform float leg_top = 0.5;      // haut des pattes (m)
uniform vec2 neck = vec2(0.7, 0.36);   // base du cou (y, z)
uniform float heat = 0.0;         // viseur thermique

varying vec3 world_pos;

#include "res://shaders/clouds.gdshaderinc"
#include "res://shaders/grade.gdshaderinc"

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void vertex() {
	vec3 v = VERTEX;
	// Pattes : les diagonales avancent ensemble (avant gauche avec arrière droite), le sabot se lève en avançant.
	if (v.y < leg_top) {
		float k = (leg_top - v.y) / leg_top;
		float off = ((v.z > 0.02) == (v.x > 0.0)) ? 0.0 : 3.14159;
		float s = sin(phase + off);
		v.z += (leg_top - v.y) * s * 0.55 * walk;
		v.y += max(0.0, cos(phase + off)) * 0.06 * walk * k;
	}
	// Tête et cou : broute (vers le bas) et regarde autour (tourne), autour de la base du cou.
	float w = smoothstep(neck.y - 0.12, neck.y + 0.04, v.z + (v.y - neck.x) * 0.3) * smoothstep(leg_top, neck.x, v.y + 0.15);
	if (w > 0.0) {
		vec2 d = vec2(v.z - neck.y, v.y - neck.x);
		float a = (graze * 1.15 + sin(TIME * 7.0) * 0.04 * graze) * w;
		d = rot(d, -a);
		vec3 h = vec3(v.x, neck.x + d.y, neck.y + d.x);
		vec2 xz = rot(vec2(h.z - neck.y, h.x), look * w);
		v = vec3(xz.y, h.y, neck.y + xz.x);
	}
	// Le corps se balance un peu à chaque pas.
	v.y += abs(sin(phase)) * 0.025 * walk;
	VERTEX = v;
	world_pos = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
}

void fragment() {
	vec3 c = grade(texture(albedo_tex, UV).rgb) * 0.72;   // même étalonnage que le décor, pelage moins clair au soleil
	ALBEDO = mix(c, vec3(1.0), heat * 0.7);
	EMISSION = vec3(1.0, 0.95, 0.85) * heat * 3.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = clamp((ndl + 0.1) / 1.1, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * cloud_shadow(world_pos.xz, TIME);
}
