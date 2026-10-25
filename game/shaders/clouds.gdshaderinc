// Ombres des nuages qui passent sur les îles et la mer (partagé par plusieurs shaders).
// Renvoie 1 au soleil, environ 0,55 sous un nuage.

float cloud_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cloud_hash(i), cloud_hash(i + vec2(1, 0)), u.x),
		mix(cloud_hash(i + vec2(0, 1)), cloud_hash(i + vec2(1, 1)), u.x), u.y);
}

float cloud_shadow(vec2 xz, float t) {
	vec2 p = xz * 0.0045 + vec2(t * 0.012, t * 0.004);
	float n = cloud_noise(p) * 0.65 + cloud_noise(p * 2.3 + 7.1) * 0.35;
	return mix(0.55, 1.0, smoothstep(0.5, 0.62, n));
}
