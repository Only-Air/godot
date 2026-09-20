class_name BuildPiece
extends StaticBody3D

const GRID_SIZE := 4.0
const WALL_HEIGHT := 3.0

var piece_type := "wall"
var material_type := "wood"
var health := 150.0
var max_health := 150.0
var owner_id := 0
var edit_mask := 0b111111111
var edit_cycle_index := 0
var mesh_root: Node3D
var collision_root: Node3D
var stored_material: Material
var building_time := 0.0
var building_duration := 0.65
var target_scale := Vector3.ONE

func setup(type: String, material: Material, creator_id: int = 0, resource_type: String = "wood") -> void:
	piece_type = type
	owner_id = creator_id
	material_type = resource_type
	stored_material = material
	max_health = {"wood":150.0, "stone":300.0, "metal":500.0}.get(material_type, 150.0)
	health = max_health * 0.25
	building_duration = {"wood":0.55, "stone":1.0, "metal":1.55}.get(material_type, 0.7)
	collision_layer = 4
	collision_mask = 3
	mesh_root = Node3D.new()
	collision_root = Node3D.new()
	add_child(mesh_root)
	add_child(collision_root)
	_rebuild_geometry(stored_material)
	target_scale = scale
	scale = Vector3(target_scale.x, maxf(0.08, target_scale.y * 0.08), target_scale.z)

func _process(delta: float) -> void:
	if building_time >= building_duration: return
	building_time += delta
	var progress := clampf(building_time / building_duration, 0.0, 1.0)
	scale = Vector3(target_scale.x, lerpf(maxf(0.08, target_scale.y * 0.08), target_scale.y, progress), target_scale.z)
	health = lerpf(max_health * 0.25, max_health, progress)

func _clear_geometry() -> void:
	for child in mesh_root.get_children(): child.queue_free()
	for child in collision_root.get_children(): child.queue_free()

func _rebuild_geometry(material: Material = null) -> void:
	if material != null: stored_material = material
	_clear_geometry()
	match piece_type:
		"wall": _build_wall_grid(stored_material)
		"floor": _add_box(Vector3(GRID_SIZE, 0.22, GRID_SIZE), Vector3.ZERO, Vector3.ZERO, stored_material)
		"roof": _build_roof(stored_material)
		"ramp": _add_box(Vector3(GRID_SIZE, 0.22, 4.6), Vector3(0, 1.15, 0), Vector3(deg_to_rad(-32.0), 0, 0), stored_material)

func _build_wall_grid(material: Material) -> void:
	var cell_w := GRID_SIZE / 3.0
	var cell_h := WALL_HEIGHT / 3.0
	for row in 3:
		for col in 3:
			var bit := row * 3 + col
			if (edit_mask & (1 << bit)) == 0: continue
			var x := (float(col) - 1.0) * cell_w
			var y := (float(2 - row) + 0.5) * cell_h
			_add_box(Vector3(cell_w - 0.035, cell_h - 0.035, 0.22), Vector3(x, y, 0), Vector3.ZERO, material)

func _build_roof(material: Material) -> void:
	_add_box(Vector3(GRID_SIZE, 0.18, GRID_SIZE * 0.52), Vector3(0, 0.72, -0.96), Vector3(deg_to_rad(-20), 0, 0), material)
	_add_box(Vector3(GRID_SIZE, 0.18, GRID_SIZE * 0.52), Vector3(0, 0.72, 0.96), Vector3(deg_to_rad(20), 0, 0), material)

func _add_box(size: Vector3, local_position: Vector3, local_rotation: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	mesh_root.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = local_position
	collision.rotation = local_rotation
	collision_root.add_child(collision)

func apply_damage(amount: float, _source = null) -> void:
	health -= amount
	if health <= 0.0: queue_free()

func apply_edit_mask(mask: int, material: Material = null) -> void:
	if piece_type != "wall": return
	edit_mask = mask & 0b111111111
	if edit_mask == 0: edit_mask = 0b111111111
	_rebuild_geometry(material)

func edit_preset(preset: String, material: Material = null) -> void:
	match preset:
		"reset": edit_mask = 0b111111111
		"window": edit_mask = 0b111101111
		"door_left": edit_mask = 0b110110110
		"door_right": edit_mask = 0b011011011
		"half": edit_mask = 0b000111111
		"arch": edit_mask = 0b101101111
		"left_half": edit_mask = 0b110110110
		"right_half": edit_mask = 0b011011011
	_rebuild_geometry(material)

func cycle_edit(simple_edit: bool = false) -> void:
	if piece_type != "wall":
		rotate_variant()
		return
	var presets := ["reset", "window", "half"] if simple_edit else ["reset", "window", "door_left", "door_right", "half", "arch"]
	edit_cycle_index = (edit_cycle_index + 1) % presets.size()
	edit_preset(presets[edit_cycle_index])

func simple_edit_from_local_hit(local_hit: Vector3, material: Material = null) -> void:
	if piece_type != "wall": return
	if local_hit.y > 2.0:
		edit_preset("window", material)
	elif local_hit.x < -0.65:
		edit_preset("door_left", material)
	elif local_hit.x > 0.65:
		edit_preset("door_right", material)
	else:
		edit_preset("half", material)

func rotate_variant() -> void:
	rotation.y += PI * 0.5
