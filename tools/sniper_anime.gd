extends SceneTree
## Outil (à lancer une fois, pas dans le jeu) : prépare le sniper animé, game/art/sniper_anime.scn.
##
##   godot --headless --path game -s ../tools/sniper_anime.gd -- ../sources
##
## Entrées (dossier sources/) :
## - sniper_higgsfield.glb : le sniper sans arme, en A-pose, avec son squelette (Higgsfield, 1,8 m, regard vers +z) ;
## - fusil_higgsfield.glb : le fusil seul (Higgsfield), qu'on accroche dans le dos ;
## - UAL1_Standard.glb : squelette et animations de la « Universal Animation Library » de Quaternius (CC0).
##
## Le squelette des animations est ajusté au sniper : chaque os prend la longueur et la direction de l'os
## correspondant du sniper (hanches, genoux, chevilles, épaules, coudes, poignets), puis le sniper garde ses
## propres poids de peau, rattachés aux os des animations. Les animations jouent donc avec les vraies
## articulations du modèle. Chaque sommet garde sa position au repos (CUSTOM0) : la peinture suit le corps.
## La bibliothèque n'a pas de position couchée : on la fabrique (Prone_Idle_Loop, Prone_Crawl_Loop).

const KEEP := [
	"Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Crouch_Idle_Loop", "Crouch_Fwd_Loop", "Death01",
	"Jump_Start", "Jump_Loop", "Jump_Land",
]
# Os du sniper → os des animations.
const MAP := {
	"Hips": "pelvis", "Spine02": "spine_01", "Spine01": "spine_02", "Spine": "spine_03", "neck": "neck_01",
	"Head": "Head", "head_end": "Head", "headfront": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r",
}
# Os dont on place l'origine (articulation) sur celle du sniper, au repos.
const PLACE := ["spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r",
	"upperarm_l", "upperarm_r", "thigh_l", "thigh_r"]
# Chaînes : os → [os enfant des animations, articulation du sniper où il doit arriver].
const CHAINS := [
	["upperarm_l", "lowerarm_l", "LeftForeArm"], ["lowerarm_l", "hand_l", "LeftHand"],
	["upperarm_r", "lowerarm_r", "RightForeArm"], ["lowerarm_r", "hand_r", "RightHand"],
	["thigh_l", "calf_l", "LeftLeg"], ["calf_l", "foot_l", "LeftFoot"], ["foot_l", "ball_l", "LeftToeBase"],
	["thigh_r", "calf_r", "RightLeg"], ["calf_r", "foot_r", "RightFoot"], ["foot_r", "ball_r", "RightToeBase"],
]
const RIFLE_LENGTH := 1.12   # m

var ual_sk: Skeleton3D
var joints := {}   # articulations du sniper (m), par nom d'os du sniper

func _initialize() -> void:
	_run()

func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		push_error("Impossible de lire " + path)
		quit(1)
	var scene: Node3D = doc.generate_scene(st)
	root.add_child(scene)
	return scene

func _bind_bone(skin: Skin, sk: Skeleton3D, i: int) -> int:
	var b := skin.get_bind_bone(i)
	return b if b >= 0 else sk.find_bone(skin.get_bind_name(i))

func _run() -> void:
	await process_frame
	var src: String = OS.get_cmdline_user_args()[0]
	var ual := _load(src.path_join("UAL1_Standard.glb"))
	var hero := _load(src.path_join("sniper_higgsfield.glb"))
	var rifle := _load(src.path_join("fusil_higgsfield.glb"))
	await process_frame
	await process_frame
	ual_sk = ual.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = ual.find_children("*", "AnimationPlayer", true, false)[0]

	# --- Le sniper au repos, en mètres (calculé comme la carte graphique, avec son propre squelette).
	var h_mi: MeshInstance3D = hero.find_children("*", "MeshInstance3D", true, false)[0]
	var h_sk: Skeleton3D = hero.find_children("*", "Skeleton3D", true, false)[0]
	var h_skin := h_mi.skin
	var a := h_mi.mesh.surface_get_arrays(0)
	var hv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var hn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var hb: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var hw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var per := hb.size() / hv.size()
	var mats := []
	var bind_names := []
	for i in h_skin.get_bind_count():
		var b := _bind_bone(h_skin, h_sk, i)
		mats.append(h_sk.global_transform * h_sk.get_bone_global_rest(b) * h_skin.get_bind_pose(i))
		bind_names.append(h_sk.get_bone_name(b))
	for b in h_sk.get_bone_count():
		joints[h_sk.get_bone_name(b)] = h_sk.global_transform * h_sk.get_bone_global_rest(b).origin
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(hv.size())
	normals.resize(hv.size())
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in hv.size():
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		for j in per:
			var w := hw[i * per + j]
			if w > 0.0:
				var m: Transform3D = mats[hb[i * per + j]]
				p += (m * hv[i]) * w
				n += (m.basis * hn[i]) * w
		verts[i] = p
		normals[i] = n.normalized()
		lo = lo.min(p)
		hi = hi.max(p)
	print("sniper au repos : ", hv.size(), " sommets, de ", lo, " à ", hi)

	# --- Squelette des animations ajusté au sniper.
	var sk := ual_sk
	var mannequin_hip := sk.get_bone_global_rest(sk.find_bone("pelvis")).origin
	var mannequin_local := sk.get_bone_rest(sk.find_bone("pelvis")).origin   # valeurs des pistes : dans le repère de l'os parent
	var pelvis_target := Vector3(joints["Hips"].x, (joints["LeftUpLeg"].y + joints["RightUpLeg"].y) / 2 - 0.015, joints["Hips"].z)
	_place(sk, "pelvis", pelvis_target)
	for bn in PLACE:
		var src_name: String = MAP.find_key(bn)
		_place(sk, bn, joints[src_name])
	for c in CHAINS:
		var parent_src: String = MAP.find_key(c[0])
		var length: float = (joints[c[2]] - joints[parent_src]).length()
		var child := sk.find_bone(c[1])
		var rest := sk.get_bone_rest(child)
		rest.origin = rest.origin.normalized() * length
		sk.set_bone_rest(child, rest)
	sk.reset_bone_poses()
	# Pose du sniper : chaque os de bras et de jambe pointe vers l'articulation suivante du sniper.
	for c in CHAINS:
		var parent_src: String = MAP.find_key(c[0])
		_aim(sk, sk.find_bone(c[0]), sk.find_bone(c[1]), joints[c[2]] - joints[parent_src])
	for side in ["l", "r"]:
		var arm := "LeftForeArm" if side == "l" else "RightForeArm"
		var hand := "LeftHand" if side == "l" else "RightHand"
		_aim(sk, sk.find_bone("hand_" + side), sk.find_bone("middle_01_" + side), joints[hand] - joints[arm])
	sk.force_update_all_bone_transforms()
	var worst := 0.0
	for c in CHAINS:
		worst = maxf(worst, (sk.get_bone_global_pose(sk.find_bone(c[1])).origin - joints[c[2]]).length())
	print("écart max des articulations après ajustement : ", worst, " m")
	# Liaison : la pose ajustée devient la pose de repos de la peau.
	var to_sk := sk.global_transform.affine_inverse()
	var skin := Skin.new()
	for b in sk.get_bone_count():
		skin.add_bind(b, sk.get_bone_global_pose(b).affine_inverse())
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	for i in verts.size():
		out_v.append(to_sk * verts[i])
		out_n.append((to_sk.basis * normals[i]).normalized())
		var acc := {}
		for j in per:
			var w := hw[i * per + j]
			if w > 0.0:
				var bone := sk.find_bone(MAP[bind_names[hb[i * per + j]]])
				acc[bone] = acc.get(bone, 0.0) + w
		var keys := acc.keys()
		keys.sort_custom(func(x, y): return acc[x] > acc[y])
		var total := 0.0
		for j in mini(4, keys.size()):
			total += acc[keys[j]]
		for j in 4:
			out_b.append(keys[j] if j < keys.size() else 0)
			out_w.append(acc[keys[j]] / total if j < keys.size() else 0.0)
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]

	# --- Le fusil, dans le dos (rigide, suit le haut du buste).
	var r := _rifle(rifle, out_v, sk.find_bone("spine_03"), _dark_uv(h_mi))
	var first := out_v.size()
	out_v.append_array(r.v)
	out_n.append_array(r.n)
	out_b.append_array(r.b)
	out_w.append_array(r.w)
	uv.append_array(r.uv)
	for i in r.idx:
		idx.append(first + i)

	var custom := PackedFloat32Array()
	custom.resize(out_v.size() * 4)
	for i in out_v.size():
		custom[i * 4] = out_v[i].x
		custom[i * 4 + 1] = out_v[i].y
		custom[i * 4 + 2] = out_v[i].z
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_BONES] = out_b
	arrays[Mesh.ARRAY_WEIGHTS] = out_w
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	for old in ual.find_children("*", "MeshInstance3D", true, false):
		old.get_parent().remove_child(old)
		old.free()
	var mi := MeshInstance3D.new()
	mi.name = "Sniper"
	mi.mesh = mesh
	mi.skin = skin
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	hero.queue_free()
	rifle.queue_free()

	# --- Animations : seulement celles du jeu ; le bassin garde la même hauteur relative.
	var lib: AnimationLibrary = ap.get_animation_library("")
	for n in lib.get_animation_list():
		if not n in KEEP:
			lib.remove_animation(n)
	var pelvis_rest := sk.get_bone_rest(sk.find_bone("pelvis")).origin
	var ratio := pelvis_target.y / mannequin_hip.y
	for n in lib.get_animation_list():
		var anim := lib.get_animation(n)
		anim.loop_mode = Animation.LOOP_LINEAR if String(n).ends_with("_Loop") else Animation.LOOP_NONE
		for t in anim.get_track_count():
			if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(t).get_subname(0)) == "pelvis":
				for k in anim.track_get_key_count(t):
					var v: Vector3 = anim.track_get_key_value(t, k)
					anim.track_set_key_value(t, k, (v - mannequin_local) * ratio + pelvis_rest)
	await process_frame
	lib.add_animation("Prone_Idle_Loop", _prone_anim(ap, sk, mi, 2.5, [[0.0, 0.3, -1.0], [0.5, 0.34, -1.0], [1.0, 0.3, -1.0]]))
	var crawl := []
	for i in 9:
		crawl.append([i / 8.0, 0.3, i / 8.0])
	lib.add_animation("Prone_Crawl_Loop", _prone_anim(ap, sk, mi, 1.6, crawl))
	ap.stop()
	sk.reset_bone_poses()
	_own(ual, ual)
	var packed := PackedScene.new()
	packed.pack(ual)
	var err := ResourceSaver.save(packed, "res://art/sniper_anime.scn")
	print("sniper_anime.scn : ", err, " — ", out_v.size(), " sommets, ", idx.size() / 3, " triangles, ", lib.get_animation_list())
	quit()

## Place l'articulation d'un os (au repos) sur un point donné, sans changer son orientation.
func _place(sk: Skeleton3D, name: String, target: Vector3) -> void:
	var b := sk.find_bone(name)
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_rest(par) if par >= 0 else Transform3D.IDENTITY
	var rest := sk.get_bone_rest(b)
	rest.origin = pg.affine_inverse() * (sk.global_transform.affine_inverse() * target)
	sk.set_bone_rest(b, rest)

## Un coin sombre de la texture du sniper (pour le fusil, qui n'a pas de place dans cette texture).
func _dark_uv(mi: MeshInstance3D) -> Vector2:
	var mat := mi.mesh.surface_get_material(0)
	var img: Image = (mat as BaseMaterial3D).albedo_texture.get_image()
	img.decompress()
	var best := Vector2(0.5, 0.5)
	var best_l := INF
	for y in range(8, img.get_height() - 8, 16):
		for x in range(8, img.get_width() - 8, 16):
			var s := 0.0
			for dy in [-6, 0, 6]:
				for dx in [-6, 0, 6]:
					s += img.get_pixel(x + dx, y + dy).get_luminance()
			# assez sombre, mais pas le noir pur des bords de la texture
			if s / 9.0 > 0.05 and s < best_l:
				best_l = s
				best = Vector2((x + 0.5) / img.get_width(), (y + 0.5) / img.get_height())
	return best

## Le fusil, à ajouter au maillage : en travers du dos, canon vers le haut derrière l'épaule gauche.
func _rifle(rifle: Node3D, body: PackedVector3Array, bone: int, dark: Vector2) -> Dictionary:
	var rmi: MeshInstance3D = rifle.find_children("*", "MeshInstance3D", true, false)[0]
	var ra := rmi.mesh.surface_get_arrays(0)
	var rv: PackedVector3Array = ra[Mesh.ARRAY_VERTEX]
	var rn: PackedVector3Array = ra[Mesh.ARRAY_NORMAL]
	var ri: PackedInt32Array = ra[Mesh.ARRAY_INDEX]
	var g := rmi.global_transform
	var pts := []
	var center := Vector3.ZERO
	for p in rv:
		var q := g * p
		pts.append(q)
		center += q
	center /= pts.size()
	# Axe du canon : la plus grande longueur (analyse en composantes principales, par itérations).
	var c := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for q in pts:
		var d: Vector3 = q - center
		for r in 3:
			for s in 3:
				c[r][s] += d[r] * d[s]
	var along := Vector3(1, 1, 1).normalized()
	for it in 50:
		var nv := Vector3(c[0][0] * along.x + c[0][1] * along.y + c[0][2] * along.z,
			c[1][0] * along.x + c[1][1] * along.y + c[1][2] * along.z,
			c[2][0] * along.x + c[2][1] * along.y + c[2][2] * along.z)
		along = nv.normalized()
	# Le bout le plus fin est la bouche du canon.
	var tmin := INF
	var tmax := -INF
	for q in pts:
		var t: float = (q - center).dot(along)
		tmin = minf(tmin, t)
		tmax = maxf(tmax, t)
	var thick := [0.0, 0.0]
	var cnt := [0, 0]
	for q in pts:
		var t: float = (q - center).dot(along)
		var radial: float = ((q - center) - along * t).length()
		if t > tmax - (tmax - tmin) * 0.12:
			thick[1] += radial
			cnt[1] += 1
		elif t < tmin + (tmax - tmin) * 0.12:
			thick[0] += radial
			cnt[0] += 1
	if thick[1] / maxi(cnt[1], 1) > thick[0] / maxi(cnt[0], 1):
		along = -along
		var tt := tmin
		tmin = -tmax
		tmax = -tt
	# Côté lunette : direction perpendiculaire où le fusil s'étend le plus loin de l'axe (vers le haut au départ).
	var up_guess := Vector3.UP - along * along.dot(Vector3.UP)
	if up_guess.length() < 0.1:
		up_guess = Vector3.FORWARD - along * along.dot(Vector3.FORWARD)
	up_guess = up_guess.normalized()
	var src_basis := Basis(along.cross(up_guess).normalized(), along, up_guess)   # x, y = canon, z = dessus
	# Dans le dos : canon vers le haut et vers la gauche (+x), dessus du fusil tourné vers l'arrière (-z).
	var back_z := INF
	for p in body:
		if p.y > 1.05 and p.y < 1.4 and absf(p.x) < 0.18:
			back_z = minf(back_z, p.z)
	var dst_along := Vector3(0.62, 0.78, 0.0).normalized()
	var dst_up := Vector3(0, 0, -1)
	var dst_basis := Basis(dst_along.cross(dst_up).normalized(), dst_along, dst_up)
	var k := RIFLE_LENGTH / (tmax - tmin)
	var mid := center + along * (tmin + tmax) * 0.5
	var place := Transform3D(dst_basis.scaled(Vector3.ONE * k) * src_basis.inverse(), Vector3(0.0, 1.27, back_z - 0.06))
	var xf := place * Transform3D(Basis.IDENTITY, -mid)
	var r := {"v": PackedVector3Array(), "n": PackedVector3Array(), "b": PackedInt32Array(), "w": PackedFloat32Array(), "uv": PackedVector2Array(), "idx": ri}
	for i in pts.size():
		r.v.append(xf * (pts[i] as Vector3))
		r.n.append((xf.basis * (g.basis * rn[i])).normalized())
		r.b.append_array([bone, 0, 0, 0])
		r.w.append_array([1.0, 0.0, 0.0, 0.0])
		r.uv.append(dark)
	print("fusil : ", pts.size(), " sommets, longueur d'origine ", tmax - tmin, " m → ", RIFLE_LENGTH, " m, dos à z = ", back_z)
	return r

func _own(n: Node, owner_node: Node) -> void:
	for ch in n.get_children():
		ch.owner = owner_node
		_own(ch, owner_node)


# ---------- Rotations d'os ----------
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

## Point le plus bas du corps dans la pose actuelle.
func _min_y(mi: MeshInstance3D, sk: Skeleton3D) -> float:
	sk.force_update_all_bone_transforms()
	var a := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var mats := []
	for b in mi.skin.get_bind_count():
		mats.append(sk.get_bone_global_pose(mi.skin.get_bind_bone(b)) * mi.skin.get_bind_pose(b))
	var lo := 9.0
	for i in range(0, verts.size(), 2):
		var p := Vector3.ZERO
		for j in 4:
			var w := weights[i * 4 + j]
			if w > 0.0:
				p += (mats[bones[i * 4 + j]] * verts[i]) * w
		lo = minf(lo, p.y)
	return lo


# ---------- Position couchée ----------
## À plat ventre : le corps (pris debout) bascule autour du bassin, le buste se relève un peu (chest),
## la tête regarde devant, coudes posés devant les épaules, mains sous le menton, jambes allongées.
## crawl (0 à 1, ou -1 à l'arrêt) : un genou puis l'autre remonte sur le côté, le coude opposé avance.
func _prone_pose(sk: Skeleton3D, mi: MeshInstance3D, chest: float, crawl: float) -> void:
	var pelvis := sk.find_bone("pelvis")
	_rot(sk, pelvis, Basis(Vector3.RIGHT, PI / 2))
	for b in ["spine_02", "spine_03"]:
		_rot(sk, sk.find_bone(b), Basis(Vector3.RIGHT, -chest / 2))
	_rot(sk, sk.find_bone("Head"), Basis(Vector3.RIGHT, -0.55))
	var c := sin(crawl * TAU) if crawl >= 0.0 else 0.0
	for side in [["l", 1.0], ["r", -1.0]]:
		var s: float = side[1]
		var up := maxf(0.0, c * s)
		var a := 0.1 + up * 1.1
		var b := a - up * 1.9
		_aim(sk, sk.find_bone("thigh_" + side[0]), sk.find_bone("calf_" + side[0]), Vector3(s * sin(a), 0.0, -cos(a)))
		_aim(sk, sk.find_bone("calf_" + side[0]), sk.find_bone("foot_" + side[0]), Vector3(s * sin(b), 0.0, -cos(b)))
		_aim(sk, sk.find_bone("foot_" + side[0]), sk.find_bone("ball_" + side[0]), Vector3(0.0, -0.55, -0.85))
		# Bras : le coude du côté opposé au genou qui remonte avance.
		var reach := maxf(0.0, -c * s) * 0.35
		_aim(sk, sk.find_bone("upperarm_" + side[0]), sk.find_bone("lowerarm_" + side[0]), Vector3(s * 0.38, -0.62, 0.55 + reach))
		_aim(sk, sk.find_bone("lowerarm_" + side[0]), sk.find_bone("hand_" + side[0]), Vector3(-s * 0.55, -0.05, 0.85))
		_aim(sk, sk.find_bone("hand_" + side[0]), sk.find_bone("middle_01_" + side[0]), Vector3(-s * 0.4, -0.1, 0.9))
	var lo := _min_y(mi, sk)
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
