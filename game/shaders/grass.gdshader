shader_type spatial;
// Herbe, fleurs et cailloux : un champ qui suit la caméra. Herbe et fleurs : cartes texturées découpées.
// Chaque touffe lit la hauteur du sol et la zone (herbe / forêt) dans deux petites textures.
render_mode cull_disabled, world_vertex_coords;

uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform sampler2D mask : filter_linear, repeat_disable;   // r : herbe, g : fleurs, b : cailloux, a : neige
uniform float cell = 7.0;
uniform float grid = 201.0;
uniform float half_size = 700.0;
uniform float water_y = 6.0;
uniform float radius = 55.0;
uniform vec3 cam_pos;
uniform float wind = 0.12;
uniform float density = 1.0;
uniform int channel = 0;          // 0 : herbe, 1 : fleurs, 2 : cailloux, 3 : neige
uniform bool keep_normals = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_tex = false;
uniform float band = 0.5;

varying float shade;
varying vec3 world_pos;

#include "res://shaders/clouds.gdshaderinc"

// Même découpage en triangles que le maillage du terrain : la touffe pose exactement sur le sol.
float ground(vec2 xz) {
	vec2 f = clamp((xz + half_size) / cell, vec2(0.0), vec2(grid - 1.001));
	ivec2 i = ivec2(floor(f));
	vec2 t = f - vec2(i);
	float a = texelFetch(heightmap, i, 0).r;
	float b = texelFetch(heightmap, i + ivec2(1, 0), 0).r;
	float d = texelFetch(heightmap, i + ivec2(0, 1), 0).r;
	float e = texelFetch(heightmap, i + ivec2(1, 1), 0).r;
	if (t.x + t.y <= 1.0) return a + (b - a) * t.x + (d - a) * t.y;
	return e + (d - e) * (1.0 - t.x) + (b - e) * (1.0 - t.y);
}

void vertex() {
	// Chaque touffe a une place fixe dans le monde : sa position de base, plus un nombre entier
	// de « tapis » (2 × rayon). Quand la caméra avance, seules les touffes sorties du champ,
	// déjà invisibles, sont recyclées de l'autre côté : rien ne bouge sous les yeux du joueur.
	// Le nombre de tapis est entier et le tirage au sort ne dépend que de lui et de la touffe :
	// il ne change pas d'une image à l'autre (sinon, sur téléphone, les arrondis font clignoter l'herbe).
	vec3 inst = MODEL_MATRIX[3].xyz;
	vec2 k = floor((cam_pos.xz - inst.xz + radius) / (2.0 * radius));
	vec3 origin = vec3(inst.x + k.x * 2.0 * radius, 0.0, inst.z + k.y * 2.0 * radius);
	vec2 uv = ((origin.xz + half_size) / cell + 0.5) / grid;
	float h = ground(origin.xz);
	vec4 mk = texture(mask, uv);
	float m = mk[channel];
	vec2 seed = fract(inst.xz * 0.0137 + k * vec2(0.3183, 0.6180));
	float rnd = fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
	float d = length(origin.xz - cam_pos.xz);
	float fade = (1.0 - smoothstep(radius * 0.7, radius, d)) * smoothstep(1.2, 1.8, d);  // rien dans les yeux
	float show = step(rnd, m * density) * step(water_y + 0.8, h) * fade;
	vec3 local = VERTEX - inst;
	float lh = max(local.y, 0.0);
	float t = TIME * 1.8 + origin.x * 0.21 + origin.z * 0.17;
	local.x += (sin(t) + 0.4 * sin(t * 2.7)) * wind * lh * lh;
	local.z += cos(t * 0.8) * wind * 0.6 * lh * lh;
	VERTEX = origin + local * show;
	VERTEX.y += h;
	if (!keep_normals) {
		NORMAL = vec3(0.0, 1.0, 0.0);
	}
	shade = 0.9 + rnd * 0.2;
	world_pos = VERTEX;
}

void fragment() {
	if (use_tex) {
		vec4 t = texture(albedo_tex, UV);
		// Au loin, les petites versions de l'image (mipmaps) diluent la transparence : on la renforce
		// selon le niveau utilisé, sinon les brins maigrissent et scintillent en s'éloignant.
		vec2 px = UV * vec2(textureSize(albedo_tex, 0));
		float mip = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
		if (t.a * (1.0 + mip * 0.3) < 0.45) {
			discard;
		}
		ALBEDO = t.rgb * tint.rgb * shade * COLOR.rgb;
	} else {
		ALBEDO = pow(COLOR.rgb, vec3(2.2)) * tint.rgb * shade;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * clamp((ndl + 0.3) / 1.3, 0.0, 1.0) * ATTENUATION * cloud_shadow(world_pos.xz, TIME);
}
