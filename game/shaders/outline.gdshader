shader_type spatial;
// Contour noir (coque inversée), d'épaisseur constante à l'écran,
// qui s'efface au loin pour ne pas trahir les snipers.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.11, 0.13, 0.16, 1.0);
uniform float width_px = 2.0;
uniform float fade_distance = 90.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(dir);
	if (len > 0.0001) {
		dir /= len;
		// Avec le zoom, la distance « vue » diminue : le contour revient.
		float zoom = PROJECTION_MATRIX[1][1] / 1.92;
		float w = width_px * clamp(fade_distance * zoom / max(clip.w, 0.001), 0.0, 1.0);
		clip.xy += dir * w * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
