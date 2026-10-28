// Étalonnage commun du sol et de la peinture du sniper : couleurs moins saturées, verts plus naturels.
// Appliqué aux deux de la même façon, il ne change rien au camouflage (une tenue « herbe » reste
// de la couleur exacte de l'herbe).
vec3 grade(vec3 c) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(l), c, 0.72) * 0.92;
}
