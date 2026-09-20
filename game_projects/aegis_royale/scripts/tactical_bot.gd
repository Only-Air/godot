class_name TacticalBot
extends CharacterBody3D

signal eliminated(victim, killer)

var health := 100.0
var shield := 25.0
var target: Node3D
var storm: StormController
var think_timer := 0.0
var shot_timer := 0.0
var build_cooldown := 0.0
var strafe_sign := 1.0
var preferred_range := 28.0
var aggression := 0.65
var awareness := 0.65
var materials := 180
var state := "loot"
var strategic_goal := Vector3.ZERO
var last_known_target_position := Vector3.ZERO
var build_material: StandardMaterial3D
var weapon := ItemDatabase.weapon("vanguard_ar", "uncommon")
var last_damage_source: Node

func setup(color: Color, skill: float = 0.6) -> void:
	aggression = clampf(skill, 0.2, 1.0)
	awareness = clampf(skill + randf_range(-0.12, 0.12), 0.2, 1.0)
	preferred_range = lerpf(38.0, 18.0, aggression)
	_create_body(color)
	build_material = StandardMaterial3D.new()
	build_material.albedo_color = Color(color, 0.92)
	build_material.roughness = 0.85
	strategic_goal = global_position + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))

func _ready() -> void:
	add_to_group("combatants")
	add_to_group("bots")
	collision_layer = 2
	collision_mask = 5
	call_deferred("_find_storm")

func _find_storm() -> void:
	var storms := get_tree().get_nodes_in_group("storm_controller")
	if not storms.is_empty(): storm = storms[0]

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
		think_timer = lerpf(0.42, 0.16, awareness)
		_update_strategy()
	_execute_state(delta)
	move_and_slide()

func _update_strategy() -> void:
	if not is_instance_valid(storm): _find_storm()
	if is_instance_valid(storm) and not storm.is_safe(global_position, 7.0):
		state = "rotate"
		strategic_goal = storm.center
		return
	_choose_target()
	if is_instance_valid(target):
		last_known_target_position = target.global_position
		var distance := global_position.distance_to(target.global_position)
		if health < 38.0 and materials >= 40: state = "heal_defend"
		elif distance < 85.0: state = "combat"
		else: state = "hunt"
	else:
		state = "loot"
		if global_position.distance_to(strategic_goal) < 4.0: strategic_goal = _choose_roam_goal()

func _execute_state(delta: float) -> void:
	match state:
		"rotate": _move_toward_goal(strategic_goal, 7.0, delta)
		"loot": _loot_behavior(delta)
		"hunt": _move_toward_goal(last_known_target_position, 6.2, delta)
		"combat": _combat_behavior(delta)
		"heal_defend": _defensive_behavior(delta)
		_: _move_toward_goal(strategic_goal, 4.5, delta)

func _loot_behavior(delta: float) -> void:
	var loot := _nearest_loot(32.0)
	if is_instance_valid(loot): strategic_goal = loot.global_position
	_move_toward_goal(strategic_goal, 5.3, delta)
	if is_instance_valid(loot) and global_position.distance_to(loot.global_position) < 1.6: _collect_loot_node(loot)

func _combat_behavior(delta: float) -> void:
	if not is_instance_valid(target): return
	var offset := target.global_position - global_position
	var distance := offset.length()
	var flat := Vector3(offset.x, 0, offset.z).normalized()
	look_at(global_position + flat, Vector3.UP)
	var move_dir := Vector3.ZERO
	if distance > preferred_range + 5.0: move_dir += flat
	elif distance < preferred_range - 7.0: move_dir -= flat
	move_dir += flat.cross(Vector3.UP) * strafe_sign * 0.6
	velocity.x = move_toward(velocity.x, move_dir.x * 5.4, 18.0 * delta)
	velocity.z = move_toward(velocity.z, move_dir.z * 5.4, 18.0 * delta)
	if randf() < 0.009: strafe_sign *= -1.0
	if _has_line_of_sight():
		_shoot(distance)
		if distance < 18.0 and aggression > 0.62 and materials >= 20 and build_cooldown <= 0.0: _build_ramp_push(flat)
	elif build_cooldown <= 0.0 and materials >= 10: _build_cover(flat)

func _defensive_behavior(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	if build_cooldown <= 0.0 and materials >= 40: _build_defensive_box()
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > 28.0:
		health = minf(100.0, health + 7.0 * delta)
		if health >= 62.0: state = "combat"

func _move_toward_goal(goal: Vector3, speed: float, delta: float) -> void:
	var direction := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if direction.length_squared() < 1.0:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		return
	direction = direction.normalized()
	look_at(global_position + direction, Vector3.UP)
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)

func _choose_target() -> void:
	var best_score := INF
	var best_target: Node3D
	for candidate in get_tree().get_nodes_in_group("combatants"):
		if candidate == self or not is_instance_valid(candidate): continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > lerpf(52.0, 105.0, awareness): continue
		var score := distance
		if candidate == target: score *= 0.8
		if score < best_score:
			best_score = score
			best_target = candidate
	target = best_target

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
	var accuracy := clampf(0.9 - distance / 130.0, 0.18, 0.82) * aggression
	if randf() <= accuracy and target.has_method("apply_damage"):
		target.apply_damage(randf_range(7.0, 14.0) * float(ItemDatabase.RARITY[weapon.rarity].power), self)
	if randf() < 0.18 and build_cooldown <= 0.0 and materials >= 10: _build_cover((target.global_position - global_position).normalized())

func _build_cover(enemy_direction: Vector3) -> void:
	var piece := BuildPiece.new()
	get_tree().current_scene.add_child(piece)
	piece.global_position = _snap_build(global_position + enemy_direction * 1.8)
	piece.rotation.y = atan2(enemy_direction.x, enemy_direction.z)
	piece.setup("wall", build_material, get_instance_id(), "wood")
	materials -= 10
	build_cooldown = randf_range(2.6, 5.2) / aggression

func _build_ramp_push(enemy_direction: Vector3) -> void:
	for type in ["wall", "ramp"]:
		var piece := BuildPiece.new()
		get_tree().current_scene.add_child(piece)
		piece.global_position = _snap_build(global_position + enemy_direction * (1.6 if type == "wall" else 3.2))
		piece.rotation.y = atan2(enemy_direction.x, enemy_direction.z)
		piece.setup(type, build_material, get_instance_id(), "wood")
		materials -= 10
	build_cooldown = 5.0

func _build_defensive_box() -> void:
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var piece := BuildPiece.new()
		get_tree().current_scene.add_child(piece)
		piece.global_position = _snap_build(global_position + direction * 1.8)
		piece.rotation.y = atan2(direction.x, direction.z)
		piece.setup("wall", build_material, get_instance_id(), "wood")
		materials -= 10
	build_cooldown = 10.0

func _snap_build(position: Vector3) -> Vector3:
	return Vector3(snappedf(position.x, 2.0), snappedf(maxf(position.y, 0.0), 1.5), snappedf(position.z, 2.0))

func _nearest_loot(max_distance: float) -> LootPickup:
	var nearest: LootPickup
	var best := max_distance * max_distance
	for node in get_tree().get_nodes_in_group("loot_pickups"):
		if not is_instance_valid(node): continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance < best:
			best = distance
			nearest = node
	return nearest

func _collect_loot_node(loot: LootPickup) -> void:
	var item := loot.item
	match item.get("kind", ""):
		"weapon":
			if _weapon_score(item) > _weapon_score(weapon): weapon = item.duplicate(true)
		"consumable":
			if item.id in ["mini_shield", "shield_tonic"]: shield = minf(100.0, shield + 25.0)
			else: health = minf(100.0, health + 25.0)
		"resource": materials = mini(500, materials + int(item.amount))
	loot.queue_free()

func _weapon_score(item: Dictionary) -> float:
	if item.is_empty(): return 0.0
	return float(item.damage) * float(item.fire_rate) * float(ItemDatabase.RARITY[item.rarity].power)

func _choose_roam_goal() -> Vector3:
	if is_instance_valid(storm):
		var angle := randf() * TAU
		var distance := randf_range(5.0, maxf(8.0, storm.radius * 0.65))
		return storm.center + Vector3(cos(angle), 0, sin(angle)) * distance
	return Vector3(randf_range(-85, 85), 0, randf_range(-85, 85))

func apply_damage(amount: float, source = null) -> void:
	var absorbed := minf(shield, amount)
	shield -= absorbed
	health -= amount - absorbed
	if is_instance_valid(source):
		last_damage_source = source
		target = source
		last_known_target_position = source.global_position
		state = "combat"
	if health <= 0.0:
		eliminated.emit(self, last_damage_source)
		queue_free()
