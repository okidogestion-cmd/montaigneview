shader_type spatial;
// Herbe et fleurs façon Wind Waker : un champ qui suit la caméra.
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
uniform float band = 0.5;

varying float shade;

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
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 uv = ((origin.xz + half_size) / cell + 0.5) / grid;
	float h = ground(origin.xz);
	vec4 mk = texture(mask, uv);
	float m = mk[channel];
	float rnd = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float d = length(origin.xz - cam_pos.xz);
	float fade = (1.0 - smoothstep(radius * 0.7, radius, d)) * smoothstep(1.2, 1.8, d);  // rien dans les yeux
	float show = step(rnd, m * density) * step(water_y + 0.8, h) * fade;
	vec3 local = VERTEX - origin;
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
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * tint.rgb * shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * smoothstep(band - 0.04, band + 0.04, ndl * 0.5 + 0.5);
}
