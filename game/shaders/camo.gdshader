shader_type spatial;
render_mode cull_disabled;   // le capuchon et quelques vêtements sont en une seule épaisseur
// Peinture de camouflage du sniper.
// Chaque coup de pinceau est une petite boule de couleur posée sur le corps,
// dans le repère de la pose « debout » (CUSTOM0) : la peinture suit le corps
// qu'il soit debout, accroupi ou couché.

// Les coups de pinceau sont rangés dans une petite image (une colonne par coup) :
// ligne 0 = position + rayon, ligne 1 = couleur. Une image passe partout, y compris dans
// Safari sur iPhone, où la taille des listes envoyées aux shaders est très limitée.

// Couleur de fond convertie ici (pow 2,2), comme les coups de pinceau : même rendu sur ordinateur et dans le navigateur.
uniform vec4 base_color = vec4(0.57, 0.56, 0.53, 1.0);
// Texture du modèle 3D : tex_mix = 1 montre la tenue d'origine ; sinon la peinture garde ses plis (luminance).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float tex_mix = 0.0;
uniform float avg_lum = 0.043;
uniform sampler2D stroke_tex : filter_nearest, repeat_disable;
uniform int stroke_count = 0;
uniform vec4 cursor = vec4(0.0, 0.0, 0.0, -1.0);  // cercle du pinceau (atelier)
uniform float band = 0.5;

varying vec3 ref_pos;
varying vec3 world_pos;

#include "res://shaders/clouds.gdshaderinc"
#include "res://shaders/grade.gdshaderinc"

void vertex() {
	ref_pos = CUSTOM0.xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 t = texture(albedo_tex, UV).rgb;
	float fold = mix(1.0, clamp(dot(t, vec3(0.2126, 0.7152, 0.0722)) / avg_lum, 0.45, 1.6), 0.65);
	vec3 c = mix(grade(pow(base_color.rgb, vec3(2.2))) * fold, t, tex_mix);
	for (int i = 0; i < stroke_count; i++) {
		vec4 s = texelFetch(stroke_tex, ivec2(i, 0), 0);
		if (distance(ref_pos, s.xyz) < s.w) {
			c = grade(pow(texelFetch(stroke_tex, ivec2(i, 1), 0).rgb, vec3(2.2))) * fold;
		}
	}
	if (cursor.w > 0.0) {
		float d = abs(distance(ref_pos, cursor.xyz) - cursor.w);
		c = mix(c, vec3(1.0), 1.0 - smoothstep(0.004, 0.009, d));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = clamp((ndl + 0.1) / 1.1, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * lit * 0.15;
	DIFFUSE_LIGHT += LIGHT_COLOR * (lit + rim) * cloud_shadow(world_pos.xz, TIME);
}
