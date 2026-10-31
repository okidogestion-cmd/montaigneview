shader_type spatial;
// Végétation réaliste : cartes texturées (aiguilles, feuilles, écorce) découpées par la transparence,
// éclairage doux avec un peu de lumière qui traverse les feuilles, balancement au vent.
// Près de la caméra, le feuillage s'efface (tramage) : un arbre ne bouche jamais la vue du joueur.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.5;      // 0 : pas de découpe (écorce)
uniform float translucency = 0.35;  // lumière qui traverse les feuilles à contre-jour
uniform float wind = 0.1;
uniform float wind_height = 7.0;
uniform float near_fade = 3.0;      // mètres : plus près de la caméra, le feuillage disparaît
uniform float band = 0.5;

varying vec3 world_pos;

#include "res://shaders/clouds.gdshaderinc"

void vertex() {
	vec3 inst = MODEL_MATRIX[3].xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wind > 0.0) {
		float k = clamp(VERTEX.y / wind_height, 0.0, 1.0);
		k *= k;
		float t = TIME * 1.3 + inst.x * 0.13 + inst.z * 0.09;
		// Balancement d'ensemble, plus un frémissement des branches.
		VERTEX.x += (sin(t) + 0.4 * sin(t * 2.3)) * wind * k;
		VERTEX.z += cos(t * 0.8) * wind * 0.6 * k;
		VERTEX.y += sin(t * 3.1 + VERTEX.x * 2.0) * wind * 0.15 * k;
	}
}

// Seuils de tramage 4 × 4 : la disparition se fait par petits points, sans tri de transparence.
float bayer(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (alpha_cut > 0.0 && t.a < alpha_cut) {
		discard;
	}
	float d = distance(CAMERA_POSITION_WORLD, world_pos);
	float vis = smoothstep(near_fade * 0.55, near_fade, d);
	if (vis < 0.999 && vis < bayer(FRAGCOORD.xy)) {
		discard;
	}
	// Normales « en boule » données par le maillage : on garde la même des deux côtés des cartes.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = t.rgb * tint.rgb * COLOR.rgb * 0.85;   // feuillage un peu plus sombre : il ressortait trop sur le relief
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float diff = clamp((ndl + 0.35) / 1.35, 0.0, 1.0) * ATTENUATION;
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0) * translucency * 0.45 * ATTENUATION;   // contre-jour adouci
	DIFFUSE_LIGHT += LIGHT_COLOR * (diff + back) * cloud_shadow(world_pos.xz, TIME);
}
