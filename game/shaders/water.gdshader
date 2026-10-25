shader_type spatial;
// Lac cartoon : bleu franc, écume blanche le long des rives, vaguelettes dessinées.
// La profondeur vient de la carte des hauteurs du terrain.
render_mode unshaded, cull_disabled;

uniform vec3 deep : source_color = vec3(0.10, 0.40, 0.74);
uniform vec3 shallow : source_color = vec3(0.27, 0.70, 0.85);
uniform vec3 foam : source_color = vec3(0.95, 0.98, 1.0);
uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform float cell = 7.0;
uniform float grid = 201.0;
uniform float half_size = 700.0;
uniform float water_y = 6.0;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = ((world_pos.xz + half_size) / cell + 0.5) / grid;
	float depth = water_y - texture(heightmap, uv).r;
	vec3 c = mix(shallow, deep, smoothstep(0.5, 8.0, depth));
	// Écume de rive qui respire
	float shore = 1.0 - smoothstep(0.3, 0.9 + 0.35 * sin(TIME * 1.4 + world_pos.x * 0.15 + world_pos.z * 0.1), depth);
	// Vaguelettes : fines lignes blanches qui ondulent
	vec2 p = world_pos.xz * 0.06 + vec2(TIME * 0.04, TIME * 0.025);
	float n = vnoise(p) + 0.5 * vnoise(p * 2.7 - TIME * 0.03);
	float lines = 1.0 - smoothstep(0.0, 0.035, abs(fract(n * 2.5) - 0.5));
	c = mix(c, foam, max(shore, lines * 0.5 * smoothstep(0.5, 2.0, depth)));
	ALBEDO = c;
}
