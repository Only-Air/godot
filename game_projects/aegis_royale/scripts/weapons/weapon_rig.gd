class_name WeaponRig
extends Node3D

## Third-person weapon model built from primitives, plus a muzzle marker.
## Blends between a lowered hip carry and a raised aim stance.

var muzzle: Node3D
var flash_light: OmniLight3D
var flash_mesh: MeshInstance3D
var hip_offset: Vector3 = Vector3(0.30, 0.28, -0.28)
var aim_offset: Vector3 = Vector3(0.10, 0.44, -0.34)
var hip_rot: Vector3 = Vector3(0.0, 0.10, -0.16)
var aim_rot: Vector3 = Vector3(0.0, 0.0, 0.0)
var blend: float = 0.0
var current_id: String = ""
var model_root: Node3D

func build(weapon: Dictionary) -> void:
	current_id = String(weapon.get("id", ""))
	for c in get_children():
		c.queue_free()
	model_root = Node3D.new()
	add_child(model_root)
	var kind: String = String(weapon.get("kind", "rifle"))
	var body: Color = Color("2f3742")
	var accent: Color = weapon.get("rarity_color", Color("b6bfc9"))
	if accent is Color:
		pass
	else:
		accent = Color("b6bfc9")
	var dark: StandardMaterial3D = MatLib.flat(body, 0.0, 0.45)
	var light: StandardMaterial3D = MatLib.flat(body.lightened(0.22), 0.0, 0.4)
	var acc: StandardMaterial3D = MatLib.flat(accent, 0.10, 0.4)
	var metal: StandardMaterial3D = MatLib.metal(Color("4b5563"))

	var barrel_len: float = 0.52
	match kind:
		"pistol":
			_box(model_root, Vector3(0.07, 0.10, 0.26), Vector3(0.0, 0.0, -0.10), dark)
			_box(model_root, Vector3(0.06, 0.16, 0.08), Vector3(0.0, -0.12, 0.02), light)
			barrel_len = 0.20
		"smg":
			_box(model_root, Vector3(0.09, 0.13, 0.40), Vector3(0.0, 0.0, -0.14), dark)
			_box(model_root, Vector3(0.07, 0.22, 0.09), Vector3(0.0, -0.16, -0.04), light)
			_box(model_root, Vector3(0.08, 0.14, 0.10), Vector3(0.0, -0.10, 0.10), light)
			barrel_len = 0.30
		"shotgun":
			_box(model_root, Vector3(0.11, 0.15, 0.72), Vector3(0.0, 0.0, -0.26), dark)
			_box(model_root, Vector3(0.10, 0.10, 0.26), Vector3(0.0, -0.09, -0.30), light)
			_box(model_root, Vector3(0.08, 0.18, 0.10), Vector3(0.0, -0.14, 0.04), light)
			barrel_len = 0.62
		"lmg":
			_box(model_root, Vector3(0.12, 0.17, 0.78), Vector3(0.0, 0.0, -0.26), dark)
			_box(model_root, Vector3(0.13, 0.20, 0.20), Vector3(0.0, -0.17, -0.06), light)
			_box(model_root, Vector3(0.09, 0.13, 0.12), Vector3(0.0, -0.10, 0.14), light)
			barrel_len = 0.66
		"sniper":
			_box(model_root, Vector3(0.09, 0.13, 0.92), Vector3(0.0, 0.0, -0.34), dark)
			_box(model_root, Vector3(0.07, 0.07, 0.28), Vector3(0.0, 0.13, -0.20), metal)
			_box(model_root, Vector3(0.08, 0.16, 0.10), Vector3(0.0, -0.12, 0.02), light)
			barrel_len = 0.84
		"explosive":
			_box(model_root, Vector3(0.17, 0.17, 0.86), Vector3(0.0, 0.0, -0.24), dark)
			_box(model_root, Vector3(0.14, 0.14, 0.22), Vector3(0.0, 0.0, 0.30), light)
			_box(model_root, Vector3(0.08, 0.16, 0.10), Vector3(0.0, -0.14, -0.06), light)
			barrel_len = 0.70
		_:
			_box(model_root, Vector3(0.10, 0.14, 0.66), Vector3(0.0, 0.0, -0.22), dark)
			_box(model_root, Vector3(0.08, 0.22, 0.10), Vector3(0.0, -0.17, -0.06), light)
			_box(model_root, Vector3(0.09, 0.13, 0.12), Vector3(0.0, -0.10, 0.14), light)
			barrel_len = 0.58
	_box(model_root, Vector3(0.05, 0.05, 0.14), Vector3(0.0, 0.02, -0.52), acc)

	muzzle = Node3D.new()
	muzzle.position = Vector3(0.0, 0.03, -barrel_len - 0.14)
	model_root.add_child(muzzle)

	flash_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.10
	sphere.height = 0.20
	flash_mesh.mesh = sphere
	flash_mesh.material_override = MatLib.glow(Color("ffd27a"), 3.0)
	flash_mesh.visible = false
	muzzle.add_child(flash_mesh)

	flash_light = OmniLight3D.new()
	flash_light.light_color = Color("ffca7a")
	flash_light.light_energy = 0.0
	flash_light.omni_range = 9.0
	muzzle.add_child(flash_light)

func set_stance(t: float, aim_pitch: float) -> void:
	blend = t
	position = hip_offset.lerp(aim_offset, t)
	rotation = hip_rot.lerp(aim_rot, t)
	rotation.x += aim_pitch

func flash() -> void:
	if flash_mesh == null:
		return
	flash_mesh.visible = true
	flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.35)
	flash_light.light_energy = 3.2
	var tw: Tween = create_tween()
	tw.tween_property(flash_light, "light_energy", 0.0, 0.06)
	tw.parallel().tween_callback(func() -> void:
		if is_instance_valid(flash_mesh):
			flash_mesh.visible = false
	).set_delay(0.045)

func muzzle_position() -> Vector3:
	if muzzle == null:
		return global_position
	return muzzle.global_position

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
