shader_type spatial;
// Arbre « imposteur » de l'arrière des îles : une seule image de l'arbre (la même photo que ses cartes),
// toujours tournée vers la caméra autour de l'axe vertical. Pas d'ombre portée, pas de vent : très léger.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_cut = 0.5;
uniform float translucency = 0.3;

varying vec3 world_pos;

#include "res://shaders/clouds.gdshaderinc"

void vertex() {
	vec3 inst = MODEL_MATRIX[3].xyz;
	vec3 scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 to_cam = CAMERA_POSITION_WORLD - inst;
	to_cam.y = 0.0;
	vec3 f = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 r = vec3(f.z, 0.0, -f.x);
	vec3 w = inst + r * VERTEX.x * scl.x + vec3(0.0, VERTEX.y * scl.y, 0.0);
	world_pos = w;
	mat4 inv = inverse(MODEL_MATRIX);
	VERTEX = (inv * vec4(w, 1.0)).xyz;
	NORMAL = normalize((inv * vec4(normalize(f + vec3(0.0, 0.6, 0.0)), 0.0)).xyz);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb * 0.8;   // un peu plus sombre que les cartes : une seule image, tournée vers la lumière
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float diff = clamp((ndl + 0.35) / 1.35, 0.0, 1.0) * ATTENUATION;
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0) * translucency * 0.7 * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * (diff + back) * cloud_shadow(world_pos.xz, TIME);
}
