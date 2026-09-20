class_name StormController
extends Node3D

var radius := 145.0
var target_radius := 145.0
var phase := 0
var phase_time := 50.0
var center := Vector3.ZERO
var wall: MeshInstance3D
var phases := [145.0, 105.0, 72.0, 44.0, 24.0, 10.0]

func _ready() -> void:
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
		phase_time = maxf(22.0, 55.0 - phase * 6.0)
	radius = move_toward(radius, target_radius, delta * maxf(0.65, phase * 0.55))
	wall.scale = Vector3(radius, 1.0, radius)
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if is_instance_valid(combatant) and Vector2(combatant.global_position.x - center.x, combatant.global_position.z - center.z).length() > radius:
			if combatant.has_method("apply_damage"):
				combatant.apply_damage(delta * (2.0 + phase * 1.5), self)

func status_text() -> String:
	return "风暴阶段 %d  半径 %.0fm  下阶段 %.0fs" % [phase + 1, radius, maxf(phase_time, 0.0)]
