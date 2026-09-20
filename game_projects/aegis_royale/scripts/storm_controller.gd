class_name StormController
extends Node3D

var radius := 145.0
var target_radius := 145.0
var phase := 0
var phase_time := 55.0
var center := Vector3.ZERO
var target_center := Vector3.ZERO
var wall: MeshInstance3D
var phases := [145.0, 105.0, 72.0, 44.0, 24.0, 10.0]

func _ready() -> void:
	add_to_group("storm_controller")
	wall = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 24.0
	cylinder.radial_segments = 96
	wall.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.38, 0.16, 0.75, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material_override = mat
	wall.position.y = 12.0
	add_child(wall)

func _process(delta: float) -> void:
	phase_time -= delta
	if phase_time <= 0.0 and phase < phases.size() - 1:
		phase += 1
		target_radius = phases[phase]
		_choose_next_center()
		phase_time = maxf(22.0, 58.0 - phase * 6.0)
	radius = move_toward(radius, target_radius, delta * maxf(0.65, phase * 0.55))
	center = center.move_toward(target_center, delta * maxf(0.25, phase * 0.28))
	global_position.x = center.x
	global_position.z = center.z
	wall.scale = Vector3(radius, 1.0, radius)
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if is_instance_valid(combatant) and distance_from_center(combatant.global_position) > radius:
			if combatant.has_method("apply_damage"):
				combatant.apply_damage(delta * (2.0 + phase * 1.5), self)

func _choose_next_center() -> void:
	var max_offset := maxf(0.0, radius - target_radius - 5.0)
	var angle := randf() * TAU
	target_center = center + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.0, max_offset)

func distance_from_center(world_position: Vector3) -> float:
	return Vector2(world_position.x - center.x, world_position.z - center.z).length()

func is_safe(world_position: Vector3, margin: float = 0.0) -> bool:
	return distance_from_center(world_position) <= radius - margin

func safe_direction(world_position: Vector3) -> Vector3:
	return Vector3(center.x - world_position.x, 0, center.z - world_position.z).normalized()

func status_text() -> String:
	return "风暴阶段 %d  半径 %.0fm  下阶段 %.0fs" % [phase + 1, radius, maxf(phase_time, 0.0)]
