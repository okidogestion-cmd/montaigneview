extends Node3D
## Mannequin placeholder construit avec des formes simples (pas un asset final).
## Aventurier maritime générique : chapeau, foulard de la couleur de l'île, sac, fusil dans le dos.

const TOON := preload("res://shaders/toon.gdshader")

var accent_color := Color("#347BC1")
var _body: Node3D
var _crouch := false


func build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var cloth := Color("#d8c39a")      # toile beige
	var trousers := Color("#5f6b7a")
	var skin := Color("#e2b48a")
	var leather := Color("#6b4a32")
	for x in [-0.12, 0.12]:
		_capsule(0.11, 0.85, trousers, Vector3(x, 0.43, 0))
	_capsule(0.24, 0.75, cloth, Vector3(0, 1.17, 0))
	for x in [-0.32, 0.32]:
		_capsule(0.08, 0.62, cloth, Vector3(x, 1.12, 0.02))
	_sphere(0.2, skin, Vector3(0, 1.68, 0))                                   # tête un peu grosse, lisible de loin
	_cyl(0.33, 0.33, 0.04, leather, Vector3(0, 1.82, 0))                     # bord du chapeau
	_cyl(0.16, 0.19, 0.18, leather, Vector3(0, 1.91, 0))
	_cyl(0.2, 0.22, 0.1, accent_color, Vector3(0, 1.47, 0))                  # foulard (couleur de l'île)
	_box(Vector3(0.5, 0.08, 0.3), leather, Vector3(0, 0.86, 0))              # ceinture
	_box(Vector3(0.36, 0.42, 0.18), leather.lightened(0.15), Vector3(0, 1.2, -0.24))   # sac
	var rifle := Node3D.new()
	rifle.position = Vector3(0.05, 1.2, -0.36)
	rifle.rotation = Vector3(0, 0, 0.9)
	_body.add_child(rifle)
	_box(Vector3(0.05, 1.2, 0.06), Color("#3a3d40"), Vector3(0, 0.25, 0), rifle)       # canon
	_box(Vector3(0.08, 0.45, 0.1), Color("#A97047"), Vector3(0, -0.3, 0), rifle)       # crosse en bois

func set_crouch(on: bool) -> void:
	if on == _crouch:
		return
	_crouch = on
	# Placeholder : on tasse le mannequin au lieu d'une vraie animation.
	_body.scale = Vector3(1, 0.64 if on else 1.0, 1)

func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", c)
	return m

func _add(mesh: Mesh, c: Color, pos: Vector3, parent: Node3D = null) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	(parent if parent else _body).add_child(mi)

func _capsule(r: float, h: float, c: Color, pos: Vector3) -> void:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	_add(m, c, pos)

func _sphere(r: float, c: Color, pos: Vector3) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2
	_add(m, c, pos)

func _cyl(top: float, bottom: float, h: float, c: Color, pos: Vector3) -> void:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	_add(m, c, pos)

func _box(size: Vector3, c: Color, pos: Vector3, parent: Node3D = null) -> void:
	var m := BoxMesh.new()
	m.size = size
	_add(m, c, pos, parent)
