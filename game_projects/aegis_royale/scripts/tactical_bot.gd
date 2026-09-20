class_name TacticalBot
extends CharacterBody3D

var health := 100.0
var shield := 25.0
var target: Node3D
var think_timer := 0.0
var shot_timer := 0.0
var build_cooldown := 0.0
var strafe_sign := 1.0
var preferred_range := 28.0
var aggression := 0.65
var build_material: StandardMaterial3D

func setup(color: Color, skill: float = 0.6) -> void:
	aggression = clampf(skill, 0.2, 1.0)
	preferred_range = lerpf(38.0, 18.0, aggression)
	_create_body(color)
	build_material = StandardMaterial3D.new()
	build_material.albedo_color = Color(color, 0.92)
	build_material.roughness = 0.85

func _ready() -> void:
	add_to_group("combatants")
	collision_layer = 2
	collision_mask = 5

func _create_body(color: Color) -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	var mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.45
	body.height = 1.8
	mesh.mesh = body
	mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if not is_on_floor(): velocity.y -= 22.0 * delta
	think_timer -= delta
	shot_timer -= delta
	build_cooldown -= delta
	if think_timer <= 0.0:
		think_timer = randf_range(0.18, 0.38)
		_choose_target()
	if not is_instance_valid(target):
		_wander(delta)
		move_and_slide()
		return
	var offset := target.global_position - global_position
	var distance := offset.length()
	var flat := Vector3(offset.x, 0, offset.z).normalized()
	look_at(global_position + flat, Vector3.UP)
	var move_dir := Vector3.ZERO
	if distance > preferred_range + 5.0: move_dir += flat
	elif distance < preferred_range - 7.0: move_dir -= flat
	move_dir += flat.cross(Vector3.UP) * strafe_sign * 0.6
	velocity.x = move_toward(velocity.x, move_dir.x * 5.2, 18.0 * delta)
	velocity.z = move_toward(velocity.z, move_dir.z * 5.2, 18.0 * delta)
	if randf() < 0.008: strafe_sign *= -1.0
	if _has_line_of_sight() and distance < 85.0:
		_shoot(distance)
	elif build_cooldown <= 0.0 and distance < 55.0:
		_build_cover(flat)
	if health < 46.0 and build_cooldown <= 0.0:
		_build_defensive_box()
	move_and_slide()

func _choose_target() -> void:
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("combatants"):
		if candidate == self or not is_instance_valid(candidate): continue
		var d := global_position.distance_squared_to(candidate.global_position)
		if d < best_distance:
			best_distance = d
			target = candidate

func _has_line_of_sight() -> bool:
	if not is_instance_valid(target): return false
	var origin := global_position + Vector3.UP * 1.45
	var destination := target.global_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit and hit.collider == target

func _shoot(distance: float) -> void:
	if shot_timer > 0.0: return
	shot_timer = lerpf(0.48, 0.16, aggression)
	var accuracy := clampf(0.9 - distance / 130.0, 0.25, 0.82) * aggression
	if randf() <= accuracy and target.has_method("apply_damage"):
		target.apply_damage(randf_range(7.0, 14.0), self)
	if randf() < 0.18 and build_cooldown <= 0.0:
		_build_cover((target.global_position - global_position).normalized())

func _build_cover(enemy_direction: Vector3) -> void:
	var piece := BuildPiece.new()
	get_tree().current_scene.add_child(piece)
	piece.global_position = global_position + enemy_direction * 1.3
	piece.rotation.y = atan2(enemy_direction.x, enemy_direction.z)
	piece.setup("wall", build_material, get_instance_id())
	build_cooldown = randf_range(3.2, 5.8) / aggression

func _build_defensive_box() -> void:
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var piece := BuildPiece.new()
		get_tree().current_scene.add_child(piece)
		piece.global_position = global_position + direction * 1.8
		piece.rotation.y = atan2(direction.x, direction.z)
		piece.setup("wall", build_material, get_instance_id())
	build_cooldown = 12.0

func _wander(delta: float) -> void:
	velocity.x = sin(Time.get_ticks_msec() * 0.001 + get_instance_id()) * 2.0
	velocity.z = cos(Time.get_ticks_msec() * 0.001 + get_instance_id()) * 2.0

func apply_damage(amount: float, source = null) -> void:
	var absorbed := minf(shield, amount)
	shield -= absorbed
	health -= amount - absorbed
	if is_instance_valid(source): target = source
	if health <= 0.0: queue_free()
