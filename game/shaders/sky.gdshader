shader_type sky;
// Ciel peint : panorama du lever de soleil (art/ciel.jpg, créé avec Higgsfield) autour de l'horizon,
// dégradé bleu au-dessus, soleil net, et de vrais nuages qui dérivent lentement (art/ciel_nuages.jpg :
// clarté des nuages du ciel de jour « PSX Daysky » de StarkCrafts, moitié haute du panorama 360°).

uniform sampler2D panorama : source_color, filter_linear, repeat_disable;
uniform float pano_strength = 1.0;
uniform vec3 top_color : source_color = vec3(0.41, 0.64, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.86, 0.96);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.80, 0.92);
uniform sampler2D clouds : filter_linear, repeat_enable;
uniform float cloud_lo = 0.08;     // en dessous : ciel dégagé ; plus haut, moins de nuages

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.55));
	if (d.y < 0.0) col = horizon_color;
	// Panorama répété 4 fois en miroir autour de l'horizon (pas de raccord visible).
	float az = atan(d.x, d.z) / 6.2831853 + 0.5;
	float pu = abs(fract(az * 2.0) * 2.0 - 1.0);
	float pv = 1.0 - clamp((d.y + 0.03) / 0.55, 0.0, 1.0);
	vec3 pano = texture(panorama, vec2(pu, pv)).rgb;
	col = mix(col, pano, (1.0 - smoothstep(0.35, 0.52, d.y)) * pano_strength);
	// Soleil
	float s = dot(d, normalize(LIGHT0_DIRECTION));
	col = mix(col, vec3(1.0, 0.97, 0.85), smoothstep(0.9985, 0.9992, s));
	col += vec3(1.0, 0.9, 0.7) * pow(max(s, 0.0), 60.0) * 0.25;
	col += vec3(1.0, 0.68, 0.38) * pow(max(s, 0.0), 6.0) * 0.3;   // grand halo doré autour du soleil bas
	// Nuages : la texture couvre la moitié haute du ciel (zénith en haut, horizon en bas) et tourne lentement.
	if (d.y > 0.0) {
		float v = acos(clamp(d.y, 0.0, 1.0)) / 1.5707963;
		float c = textureLod(clouds, vec2(az + TIME * 0.0004, v), 0.0).r;
		float a = smoothstep(cloud_lo, cloud_lo + 0.4, c) * smoothstep(0.03, 0.2, d.y);
		vec3 cc = mix(cloud_shade, cloud_color, smoothstep(0.15, 0.85, c));
		col = mix(col, cc, a * 0.92);
	}
	COLOR = col;
}
