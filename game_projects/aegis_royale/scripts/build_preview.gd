class_name BuildPreview
extends Node3D

var piece_type := "wall"
var valid := false
var mesh_root: Node3D
var valid_material: StandardMaterial3D
var invalid_material: StandardMaterial3D

func _ready() -> void:
	mesh_root = Node3D.new()
	add_child(mesh_root)
	valid_material = _preview_material(Color(0.18, 0.72, 1.0, 0.38))
	invalid_material = _preview_material(Color(1.0, 0.16, 0.16, 0.42))
	rebuild("wall")

func _preview_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	return mat

func rebuild(type: String) -> void:
	piece_type = type
	for child in mesh_root.get_children(): child.queue_free()
	match piece_type:
		"wall": _add_box(Vector3(4.0, 3.0, 0.22), Vector3(0, 1.5, 0), Vector3.ZERO)
		"floor": _add_box(Vector3(4.0, 0.22, 4.0), Vector3.ZERO, Vector3.ZERO)
		"ramp": _add_box(Vector3(4.0, 0.22, 4.6), Vector3(0, 1.15, 0), Vector3(deg_to_rad(-32), 0, 0))
		"roof":
			_add_box(Vector3(4.0, 0.18, 2.08), Vector3(0, 0.72, -0.96), Vector3(deg_to_rad(-20), 0, 0))
			_add_box(Vector3(4.0, 0.18, 2.08), Vector3(0, 0.72, 0.96), Vector3(deg_to_rad(20), 0, 0))
	set_valid(valid)

func _add_box(size: Vector3, local_position: Vector3, local_rotation: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	mesh_root.add_child(mesh_instance)

func set_valid(value: bool) -> void:
	valid = value
	var material := valid_material if valid else invalid_material
	for child in mesh_root.get_children():
		if child is MeshInstance3D: child.material_override = material
