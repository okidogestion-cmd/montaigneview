extends SceneTree
## Outil (à lancer une fois, pas dans le jeu) : met le squelette et les animations du
## « Universal Animation Library » de Quaternius (CC0, sources/UAL1_Standard.glb) sur le modèle
## du sniper (game/art/sniper.glb), et enregistre le résultat dans game/art/sniper_anime.scn.
##
##   godot --headless --path game -s ../tools/sniper_anime.gd -- ../sources/UAL1_Standard.glb
##
## Le sniper n'a pas de squelette : chaque sommet reçoit les poids des sommets les plus proches du
## mannequin (même taille, même orientation). Le sniper tient son fusil à deux mains alors que le
## mannequin est bras écartés : bras, mains et fusil prennent donc les os du buste (ils suivent la
## poitrine, le fusil reste dans les mains), et seules les jambes prennent les os des jambes.
## Chaque sommet garde aussi sa position debout (CUSTOM0) : la peinture de camouflage suit le corps.
##
## La bibliothèque n'a pas de position couchée : on la fabrique à partir de la pose debout
## (Prone_Idle_Loop, et Prone_Crawl_Loop pour ramper).

const MODEL := "res://art/sniper.glb"
const KEEP := [
	"Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Crouch_Idle_Loop", "Crouch_Fwd_Loop", "Death01",
]
const ARM := ["clavicle", "upperarm", "lowerarm", "hand", "index", "middle", "pinky", "ring", "thumb"]
const LEG := ["thigh", "calf", "foot", "ball"]
const K := 6          # sommets du mannequin pris en compte pour chaque sommet du sniper
const CELL := 0.06    # taille des cases de la grille de recherche (m)
const LEG_X := 0.12   # écart des jambes depuis le milieu (si le modèle ne permet pas de le mesurer)

var _leg_axis := [Vector2(-LEG_X, 0), Vector2(LEG_X, 0)]   # axe de chaque jambe (x, z), mesuré sur le modèle

func _initialize() -> void:
	_run()

func _cat(name: String) -> int:
	for a in ARM:
		if name.contains(a):
			return 1
	for l in LEG:
		if name.contains(l):
			return 2
	return 0

## Le maillage du sniper debout : pieds à y = 0, 1,8 m de haut, regard vers +z, positions copiées dans CUSTOM0.
func _model_arrays() -> Array:
	var scene: Node = (load(MODEL) as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		if n == scene:
			break
		n = n.get_parent()
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	scene.free()
	# Le modèle regarde vers +x : on le tourne vers +z.
	xf = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3.ZERO) * xf
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in verts.size():
		verts[i] = xf * verts[i]
		lo = lo.min(verts[i])
		hi = hi.max(verts[i])
	var k := 1.8 / (hi.y - lo.y)
	var shift := Vector3(-(lo.x + hi.x) / 2, -lo.y, -(lo.z + hi.z) / 2)
	for i in verts.size():
		verts[i] = (verts[i] + shift) * k
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in normals.size():
		normals[i] = (xf.basis * normals[i]).normalized()
	# Axe de chaque jambe (moyenne des sommets bas), pour ne pas prendre le fusil pour une jambe.
	var axis := [Vector2.ZERO, Vector2.ZERO]
	var cnt := [0, 0]
	for v in verts:
		if v.y > 0.15 and v.y < 0.6:
			var side := 0 if v.x < 0 else 1
			axis[side] += Vector2(v.x, v.z)
			cnt[side] += 1
	for side in 2:
		if cnt[side] > 0:
			_leg_axis[side] = axis[side] / cnt[side]
	var custom := PackedFloat32Array()
	custom.resize(verts.size() * 4)
	for i in verts.size():
		custom[i * 4] = verts[i].x
		custom[i * 4 + 1] = verts[i].y
		custom[i * 4 + 2] = verts[i].z
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_TANGENT] = null
	return arrays

func _run() -> void:
	await process_frame
	var src: String = OS.get_cmdline_user_args()[0]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(src, st) != OK:
		push_error("Impossible de lire " + src)
		quit(1)
		return
	var scene: Node3D = doc.generate_scene(st)
	root.add_child(scene)
	await process_frame
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var sk: Skeleton3D = mi.get_node(mi.skeleton)
	var skin: Skin = mi.skin
	# Sommets du mannequin, rangés dans deux grilles : sans les bras, et sans les bras ni les jambes.
	var pos := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var height := 0.0
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		pos.append_array(a[Mesh.ARRAY_VERTEX])
		bones.append_array(a[Mesh.ARRAY_BONES])
		weights.append_array(a[Mesh.ARRAY_WEIGHTS])
	var per := bones.size() / pos.size()
	var grid_body := {}
	var grid_legs := {}
	for i in pos.size():
		height = maxf(height, pos[i].y)
		var best := 0
		for j in per:
			if weights[i * per + j] > weights[i * per + best]:
				best = j
		var cat := _cat(sk.get_bone_name(skin.get_bind_bone(bones[i * per + best])))
		if cat == 1:
			continue
		var key := Vector3i((pos[i] / CELL).floor())
		if cat == 0:
			if not grid_body.has(key):
				grid_body[key] = []
			grid_body[key].append(i)
		if not grid_legs.has(key):
			grid_legs[key] = []
		grid_legs[key].append(i)
	# Sniper mis à la taille du mannequin.
	var arrays: Array = _model_arrays()
	var k := height / 1.8
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var out_v := PackedVector3Array()
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	for i in verts.size():
		var v := verts[i]
		var side := 0 if v.x < 0 else 1
		var near_leg := Vector2(v.x, v.z).distance_to(_leg_axis[side]) < 0.19 and v.y < 0.98
		var grid: Dictionary = grid_legs if (v.y < 0.45 or near_leg) else grid_body
		var p := v * k
		var found := _nearest(grid, pos, p)
		var acc := {}
		for f in found:
			var w := 1.0 / maxf(f[1], 0.005)
			for j in per:
				var b := bones[f[0] * per + j]
				acc[b] = acc.get(b, 0.0) + weights[f[0] * per + j] * w
		var keys := acc.keys()
		keys.sort_custom(func(x, y): return acc[x] > acc[y])
		var total := 0.0
		for j in mini(4, keys.size()):
			total += acc[keys[j]]
		for j in 4:
			out_b.append(keys[j] if j < keys.size() else 0)
			out_w.append(acc[keys[j]] / total if j < keys.size() else 0.0)
		out_v.append(p)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_BONES] = out_b
	arrays[Mesh.ARRAY_WEIGHTS] = out_w
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mi.mesh = mesh
	mi.name = "Sniper"
	# Seulement les animations utiles au jeu, plus la position couchée fabriquée ici.
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var lib: AnimationLibrary = ap.get_animation_library("")
	for n in lib.get_animation_list():
		if not n in KEEP:
			lib.remove_animation(n)
	for n in lib.get_animation_list():
		lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR if String(n).ends_with("_Loop") else Animation.LOOP_NONE
	await process_frame
	lib.add_animation("Prone_Idle_Loop", _prone_anim(ap, sk, mi, 2.5, [[0.0, 0.3, 0.0], [0.5, 0.34, 0.0], [1.0, 0.3, 0.0]]))
	var crawl := []
	for i in 9:
		crawl.append([i / 8.0, 0.3, i / 8.0])
	lib.add_animation("Prone_Crawl_Loop", _prone_anim(ap, sk, mi, 1.6, crawl))
	ap.stop()
	_own(scene, scene)
	var packed := PackedScene.new()
	packed.pack(scene)
	var err := ResourceSaver.save(packed, "res://art/sniper_anime.scn")
	print("sniper_anime.scn : ", err, " — ", verts.size(), " sommets, ", lib.get_animation_list(), ", échelle ", k)
	quit()

func _nearest(grid: Dictionary, pos: PackedVector3Array, p: Vector3) -> Array:
	# Les K sommets les plus proches, en élargissant la recherche case par case.
	var c := Vector3i((p / CELL).floor())
	var best: Array = []
	for r in 12:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					if maxi(absi(x), maxi(absi(y), absi(z))) != r:
						continue
					var key := c + Vector3i(x, y, z)
					if grid.has(key):
						for i in grid[key]:
							best.append([i, p.distance_to(pos[i])])
		if best.size() >= K and r >= 1:
			break
	best.sort_custom(func(a, b): return a[1] < b[1])
	return best.slice(0, K)

func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)


# ---------- Position couchée ----------
## Tourne un os dans le repère du squelette, autour de son origine.
func _rot(sk: Skeleton3D, bone: int, r: Basis) -> void:
	sk.force_update_all_bone_transforms()
	var g := sk.get_bone_global_pose(bone)
	var par := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	sk.set_bone_pose_rotation(bone, (pg.affine_inverse() * Transform3D(r * g.basis, g.origin)).basis.get_rotation_quaternion())

## Oriente un os pour que son enfant soit dans la direction donnée.
func _aim(sk: Skeleton3D, bone: int, child: int, dir: Vector3) -> void:
	sk.force_update_all_bone_transforms()
	var v := sk.get_bone_global_pose(child).origin - sk.get_bone_global_pose(bone).origin
	_rot(sk, bone, Basis(Quaternion(v.normalized(), dir.normalized())))

## Point le plus bas du corps (sans les bras ni le fusil, qui passent sous la poitrine).
func _body_min_y(mi: MeshInstance3D, sk: Skeleton3D) -> float:
	sk.force_update_all_bone_transforms()
	var a := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var cust: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var mats := []
	for b in mi.skin.get_bind_count():
		mats.append(sk.get_bone_global_pose(mi.skin.get_bind_bone(b)) * mi.skin.get_bind_pose(b))
	var lo := 9.0
	for i in verts.size():
		if absf(cust[i * 4]) > 0.2 or cust[i * 4 + 2] > 0.1:
			continue
		var p := Vector3.ZERO
		for j in 4:
			var w := weights[i * 4 + j]
			if w > 0.0:
				p += (mats[bones[i * 4 + j]] * verts[i]) * w
		lo = minf(lo, p.y)
	return lo

## À plat ventre : le corps (pris debout) bascule autour du bassin, le buste se relève un peu (chest),
## la tête regarde devant, les jambes s'allongent vers l'arrière, pointes des pieds au sol.
## crawl (0 à 1) : un genou puis l'autre remonte sur le côté, le pied revient derrière lui.
func _prone_pose(sk: Skeleton3D, mi: MeshInstance3D, chest: float, crawl: float) -> void:
	var pelvis := sk.find_bone("pelvis")
	_rot(sk, pelvis, Basis(Vector3.RIGHT, PI / 2))
	for b in ["spine_02", "spine_03"]:
		_rot(sk, sk.find_bone(b), Basis(Vector3.RIGHT, -chest / 2))
	_rot(sk, sk.find_bone("Head"), Basis(Vector3.RIGHT, -0.5))
	var c := sin(crawl * TAU)
	for side in [["l", 1.0], ["r", -1.0]]:
		var s: float = side[1]
		var up := maxf(0.0, c * s)
		var a := 0.1 + up * 1.1
		var b := a - up * 1.9
		_aim(sk, sk.find_bone("thigh_" + side[0]), sk.find_bone("calf_" + side[0]), Vector3(s * sin(a), 0.0, -cos(a)))
		_aim(sk, sk.find_bone("calf_" + side[0]), sk.find_bone("foot_" + side[0]), Vector3(s * sin(b), 0.0, -cos(b)))
		_aim(sk, sk.find_bone("foot_" + side[0]), sk.find_bone("ball_" + side[0]), Vector3(0.0, -0.55, -0.85))
	var lo := _body_min_y(mi, sk)
	sk.force_update_all_bone_transforms()
	var par := sk.get_bone_parent(pelvis)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	sk.set_bone_pose_position(pelvis, pg.affine_inverse() * (sk.get_bone_global_pose(pelvis).origin - Vector3(0, lo - 0.01, 0)))

## Animation couchée : mêmes pistes que Idle_Loop, une clé par ligne de keys = [moment (0 à 1), buste, reptation].
func _prone_anim(ap: AnimationPlayer, sk: Skeleton3D, mi: MeshInstance3D, length: float, keys: Array) -> Animation:
	var base := ap.get_animation("Idle_Loop")
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	for t in base.get_track_count():
		var tr := anim.add_track(base.track_get_type(t))
		anim.track_set_path(tr, base.track_get_path(t))
	for key in keys:
		ap.play("Idle_Loop")
		ap.seek(0.0, true)
		ap.pause()
		_prone_pose(sk, mi, key[1], key[2])
		for t in anim.get_track_count():
			var bone := sk.find_bone(String(anim.track_get_path(t).get_subname(0)))
			if bone < 0:
				continue
			var time: float = key[0] * length
			match anim.track_get_type(t):
				Animation.TYPE_POSITION_3D:
					anim.position_track_insert_key(t, time, sk.get_bone_pose_position(bone))
				Animation.TYPE_ROTATION_3D:
					anim.rotation_track_insert_key(t, time, sk.get_bone_pose_rotation(bone))
				Animation.TYPE_SCALE_3D:
					anim.scale_track_insert_key(t, time, sk.get_bone_pose_scale(bone))
	return anim
