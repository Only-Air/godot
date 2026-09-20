class_name BuildPiece
extends StaticBody3D

var piece_type: String = "wall"
var health: float = 300.0
var owner_id: int = 0
var edit_state: int = 0
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

func setup(type: String, material: Material, creator_id: int = 0) -> void:
	piece_type = type
	owner_id = creator_id
	collision_layer = 4
	collision_mask = 3
	mesh_instance = MeshInstance3D.new()
	collision_shape = CollisionShape3D.new()
	add_child(mesh_instance)
	add_child(collision_shape)
	_apply_geometry(material)

func _apply_geometry(material: Material) -> void:
	var box := BoxMesh.new()
	var shape := BoxShape3D.new()
	match piece_type:
		"wall":
			box.size = Vector3(4.0, 3.0, 0.22)
			shape.size = box.size
		"floor", "roof":
			box.size = Vector3(4.0, 0.22, 4.0)
			shape.size = box.size
		"ramp":
			box.size = Vector3(4.0, 0.22, 4.6)
			shape.size = box.size
			mesh_instance.rotation.x = deg_to_rad(-32.0)
			collision_shape.rotation.x = deg_to_rad(-32.0)
			mesh_instance.position.y = 1.15
			collision_shape.position.y = 1.15
	box.material = material
	mesh_instance.mesh = box
	collision_shape.shape = shape

func apply_damage(amount: float, _source = null) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()

func cycle_edit(simple_edit: bool = false) -> void:
	edit_state = (edit_state + 1) % (2 if simple_edit else 4)
	if piece_type == "wall":
		match edit_state:
			0:
				scale = Vector3.ONE
				position.y = snappedf(position.y, 0.5)
			1:
				scale = Vector3(0.48, 1.0, 1.0)
			2:
				scale = Vector3(1.0, 0.55, 1.0)
				position.y -= 0.65
			3:
				scale = Vector3(0.48, 0.55, 1.0)
	else:
		rotation.y += PI * 0.5
