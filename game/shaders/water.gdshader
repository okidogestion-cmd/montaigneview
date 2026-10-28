shader_type spatial;
// Mer réaliste : vagues calculées (normales), reflet du ciel selon l'angle (Fresnel), reflet du soleil,
// eau sombre au large et plus claire près des côtes, écume légère sur les plages.
// La profondeur vient de la carte des hauteurs du terrain. Couleurs données en linéaire.
render_mode unshaded, cull_disabled;

uniform vec3 deep = vec3(0.008, 0.04, 0.055);
uniform vec3 shallow = vec3(0.05, 0.15, 0.13);
uniform vec3 sky_top = vec3(0.28, 0.44, 0.72);
uniform vec3 sky_low = vec3(0.78, 0.69, 0.62);   // horizon du lever de soleil
uniform vec3 foam = vec3(0.75, 0.78, 0.78);
uniform vec3 horizon = vec3(0.86, 0.74, 0.65);   // brume du loin (comme le brouillard)
uniform vec3 sun_dir = vec3(-0.78, 0.6, 0.15);   // vers le soleil
uniform vec3 sun_color = vec3(1.6, 1.35, 1.05);
uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform float cell = 7.0;
uniform float grid = 201.0;
uniform float half_size = 700.0;
uniform float water_y = 26.0;

varying vec3 world_pos;

#include "res://shaders/clouds.gdshaderinc"

// Hauteur des vagues : quelques ondes qui se croisent, plus fines vers le large, et leur pente.
vec2 wave_slope(vec2 p, float t, float dist) {
	vec2 s = vec2(0.0);
	vec2 dirs[5] = vec2[](vec2(0.8, 0.6), vec2(-0.5, 0.86), vec2(0.97, -0.24), vec2(-0.3, -0.95), vec2(0.6, -0.8));
	float freq[5] = float[](0.06, 0.11, 0.23, 0.41, 0.73);
	float amp[5] = float[](0.9, 0.55, 0.32, 0.18, 0.1);
	float speed[5] = float[](0.9, 1.2, 1.6, 2.1, 2.7);
	for (int i = 0; i < 5; i++) {
		// Les petites vagues s'effacent au loin (sinon elles scintillent).
		float far = 1.0 - smoothstep(60.0 / freq[i] * 0.2, 400.0 / freq[i] * 0.2, dist);
		float ph = dot(dirs[i], p) * freq[i] + t * speed[i];
		s += dirs[i] * cos(ph) * freq[i] * amp[i] * far;
	}
	return s;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = ((world_pos.xz + half_size) / cell + 0.5) / grid;
	float depth = water_y - texture(heightmap, uv).r;
	vec3 to_cam = CAMERA_POSITION_WORLD - world_pos;
	float dist = length(to_cam);
	vec3 V = to_cam / dist;
	vec2 sl = wave_slope(world_pos.xz, TIME, dist);
	vec3 N = normalize(vec3(-sl.x, 1.0, -sl.y) * vec3(0.35, 1.0, 0.35));
	// Eau : claire et verte près du bord, sombre au large.
	vec3 body = mix(shallow, deep, smoothstep(0.5, 18.0, depth));
	// Reflet du ciel selon l'angle de vue.
	vec3 R = reflect(-V, N);
	vec3 sky = mix(sky_low, sky_top, smoothstep(0.0, 0.45, R.y));
	float fres = 0.03 + 0.97 * pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 5.0);
	vec3 c = mix(body, sky, clamp(fres, 0.0, 0.85));
	// Reflet du soleil sur les vagues.
	c += sun_color * pow(max(dot(R, normalize(sun_dir)), 0.0), 220.0) * 1.5;
	c *= mix(0.8, 1.0, (cloud_shadow(world_pos.xz, TIME) - 0.55) / 0.45);
	// Écume légère sur les plages, qui va et vient.
	float shore = 1.0 - smoothstep(0.15, 0.7 + 0.3 * sin(TIME * 1.1 + world_pos.x * 0.1 + world_pos.z * 0.07), depth);
	float n = fract(sin(dot(floor(world_pos.xz * 1.7), vec2(12.9898, 78.233))) * 43758.5453);
	c = mix(c, foam, shore * (0.45 + 0.35 * n));
	// Brume du loin
	c = mix(c, horizon, smoothstep(500.0, 2600.0, dist) * 0.9);
	ALBEDO = c;
}
