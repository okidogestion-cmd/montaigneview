shader_type spatial;
// Peinture de camouflage du sniper.
// Chaque coup de pinceau est une petite boule de couleur posée sur le corps,
// dans le repère de la pose « debout » (CUSTOM0) : la peinture suit le corps
// qu'il soit debout, accroupi ou couché.

const int MAX_STROKES = 600;

uniform vec4 base_color : source_color = vec4(0.57, 0.56, 0.53, 1.0);
uniform vec4 strokes[MAX_STROKES];        // xyz : position, w : rayon
uniform vec4 stroke_colors[MAX_STROKES];  // couleur sRGB
uniform int stroke_count = 0;
uniform vec4 cursor = vec4(0.0, 0.0, 0.0, -1.0);  // cercle du pinceau (atelier)
uniform float band = 0.5;

varying vec3 ref_pos;

void vertex() {
	ref_pos = CUSTOM0.xyz;
}

void fragment() {
	vec3 c = base_color.rgb;
	for (int i = 0; i < stroke_count; i++) {
		vec4 s = strokes[i];
		if (distance(ref_pos, s.xyz) < s.w) {
			c = pow(stroke_colors[i].rgb, vec3(2.2));
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
	float lit = smoothstep(band - 0.07, band + 0.07, ndl * 0.5 + 0.5);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * lit * 0.35;
	DIFFUSE_LIGHT += LIGHT_COLOR * (lit + rim);
}
