extends Node3D
## La vie de l'archipel : mouettes, voiliers au large, feuilles et pollen dans le vent,
## ambiance de forêt et cris de mouettes. Purement décoratif : rien ici n'arrête les balles
## ni n'aide à repérer l'adversaire.

const TOON := preload("res://shaders/toon.gdshader")
const WIND := Vector3(1.0, 0.0, 0.35)
const SON_FORET := preload("res://art/son_foret.ogg")

var world
var _birds: Array = []
var _boats: Array = []
var _particles: GPUParticles3D
var _waves: AudioStreamPlayer
var _cry: AudioStreamWAV
var _cry_t := 4.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func setup(w) -> void:
	world = w
	_rng.seed = 99
	for i in 14:
		_birds.append(_make_bird())
	for i in 3:
		_boats.append(_make_boat(i))
	_make_particles()
	_make_sounds()


# ---------- Mouettes ----------
func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", c)
	return m

func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _make_bird() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var body := SphereMesh.new()
	body.radius = 0.25
	body.height = 0.5
	body.radial_segments = 8
	body.rings = 4
	_part(root, body, Color("#f6f4ee"), Vector3.ZERO, Vector3(0.8, 0.7, 2.0))
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.28
	_part(root, head, Color("#ffffff"), Vector3(0, 0.08, 0.45))
	var beak := BoxMesh.new()
	beak.size = Vector3(0.05, 0.05, 0.14)
	_part(root, beak, Color("#f2b13a"), Vector3(0, 0.06, 0.62))
	var wings: Array = []
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.12 * side, 0.05, 0.05)
		root.add_child(pivot)
		var w := BoxMesh.new()
		w.size = Vector3(1.1, 0.03, 0.38)
		_part(pivot, w, Color("#e9ecef"), Vector3(0.55 * side, 0, 0))
		var tip := BoxMesh.new()
		tip.size = Vector3(0.35, 0.035, 0.3)
		_part(pivot, tip, Color("#3a3f45"), Vector3(1.15 * side, 0, -0.02))
		wings.append(pivot)
	# Cercle de vol au-dessus des îles et du chenal.
	var center := Vector3(_rng.randf_range(-260, 260), _rng.randf_range(55, 150), _rng.randf_range(-320, 320))
	return {
		"node": root, "wings": wings, "center": center,
		"radius": _rng.randf_range(35, 120), "speed": _rng.randf_range(0.08, 0.16) * (1 if _rng.randf() < 0.5 else -1),
		"angle": _rng.randf() * TAU, "flap": _rng.randf() * TAU, "scale": _rng.randf_range(0.9, 1.3),
	}

func _update_birds(dt: float) -> void:
	for b in _birds:
		b.angle += b.speed * dt
		var a: float = b.angle
		var r: float = b.radius
		var c: Vector3 = b.center
		var pos := c + Vector3(cos(a) * r, sin(a * 2.3 + b.flap) * 4.0, sin(a) * r)
		var tangent := Vector3(-sin(a), 0, cos(a)) * signf(b.speed)
		var node: Node3D = b.node
		node.position = pos
		node.basis = Basis.looking_at(-tangent, Vector3.UP).rotated(tangent.normalized(), -0.35 * signf(b.speed)).scaled(Vector3.ONE * b.scale)
		# Battements par moments, vol plané le reste du temps.
		var flapping := sin(_t * 0.35 + b.flap) > -0.2
		var wing_a := sin(_t * 9.0 + b.flap) * 0.55 if flapping else 0.12
		b.wings[0].rotation.z = -wing_a
		b.wings[1].rotation.z = wing_a


# ---------- Voiliers au large ----------
func _make_boat(i: int) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var hull := BoxMesh.new()
	hull.size = Vector3(2.2, 0.9, 6.5)
	_part(root, hull, [Color("#b5532f"), Color("#2f5d8a"), Color("#e8e0cf")][i], Vector3(0, 0.3, 0))
	var deck := BoxMesh.new()
	deck.size = Vector3(1.6, 0.6, 2.2)
	_part(root, deck, Color("#f0e6d2"), Vector3(0, 1.0, -0.8))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.07
	mast.bottom_radius = 0.09
	mast.height = 7.0
	_part(root, mast, Color("#6b4a32"), Vector3(0, 4.2, 0.6))
	var sail := BoxMesh.new()
	sail.size = Vector3(0.05, 5.6, 3.2)
	_part(root, sail, Color("#fff8ea"), Vector3(0.05, 4.4, -0.9))
	return {"node": root, "radius": 640.0 + i * 70.0, "angle": i * 2.1, "speed": 0.004 + i * 0.0015}

func _update_boats(dt: float) -> void:
	for b in _boats:
		b.angle += b.speed * dt
		var a: float = b.angle
		var node: Node3D = b.node
		node.position = Vector3(cos(a) * b.radius, world.WATER_Y + sin(_t * 0.8 + a * 10.0) * 0.25, sin(a) * b.radius)
		var heading := atan2(-sin(a), cos(a))
		node.rotation = Vector3(sin(_t * 0.9 + a) * 0.05, heading, sin(_t * 0.7) * 0.07)


# ---------- Feuilles et pollen dans le vent ----------
func _make_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 160
	_particles.lifetime = 9.0
	_particles.preprocess = 9.0
	_particles.visibility_aabb = AABB(Vector3(-40, -15, -40), Vector3(80, 30, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 8, 28)
	pm.direction = WIND.normalized()
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -0.12, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 6.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color("#9ccc5a"))
	ramp.set_color(1, Color("#fff6d8"))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_initial_ramp = tex
	_particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	_particles.draw_pass_1 = quad
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


# ---------- Sons (générés au lancement, pas de fichiers) ----------
func _noise_loop(seconds: float, cutoff: float, swell_period: float, swell_depth: float, seed: int) -> AudioStreamWAV:
	var rate := 16000
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var a := 1.0 - exp(-TAU * cutoff / rate)
	var y1 := 0.0
	var y2 := 0.0
	var cycles := maxf(1.0, roundf(seconds / swell_period))   # nombre entier de houles : boucle sans raccord
	for i in n:
		var t := float(i) / n
		var swell := 1.0 - swell_depth + swell_depth * pow(0.5 + 0.5 * sin(TAU * cycles * t), 2.0)
		y1 += a * (r.randf_range(-1, 1) - y1)
		y2 += a * (y1 - y2)
		data.encode_s16(i * 2, int(clampf(y2 * 3.2 * swell, -1, 1) * 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n
	return s

func _gull_cry() -> AudioStreamWAV:
	var rate := 16000
	var n := int(rate * 0.9)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var note := fmod(t, 0.3) / 0.3                     # trois cris courts
		var f := lerpf(1900.0, 1250.0, note) + sin(t * 70.0) * 40.0
		ph += TAU * f / rate
		var env := sin(PI * note) * (1.0 - t / 0.9)
		var v := (sin(ph) * 0.6 + sin(ph * 2.0) * 0.25 + sin(ph * 3.0) * 0.15) * env
		data.encode_s16(i * 2, int(clampf(v * 0.6, -1, 1) * 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s

func _make_sounds() -> void:
	# Bande son : ambiance de forêt enregistrée (art/son_foret.ogg, La Sonothèque, « AMBForst Forêt ID 0100 »),
	# en boucle (fin fondue dans le début sur 3 s). Remplace les vagues et le vent synthétisés.
	var amb: AudioStreamOggVorbis = SON_FORET
	amb.loop = true
	_waves = AudioStreamPlayer.new()
	_waves.stream = amb
	_waves.volume_db = -6
	add_child(_waves)
	_waves.play()
	_cry = _gull_cry()


# ---------- Chaque image ----------
func update(dt: float, cam: Vector3) -> void:
	_t += dt
	_update_birds(dt)
	_update_boats(dt)
	_particles.global_position = cam
	_cry_t -= dt
	if _cry_t <= 0.0:
		_cry_t = _rng.randf_range(7.0, 16.0)
		var p := AudioStreamPlayer.new()
		p.stream = _cry
		p.volume_db = _rng.randf_range(-24.0, -17.0)
		p.pitch_scale = _rng.randf_range(0.9, 1.15)
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
