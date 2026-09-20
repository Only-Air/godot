class_name RoyalePlayer
extends CharacterBody3D

signal stats_changed
signal eliminated
signal hit_confirmed(damage: float, critical: bool)

var health := 100.0
var shield := 0.0
var inventory := RoyaleInventory.new()
var build_mode := false
var simple_build := false
var simple_edit := false
var selected_piece := "wall"
var selected_material := "wood"
var build_rotation := 0.0
var last_action_time := -10.0
var gravity := 22.0
var camera: Camera3D
var pivot: Node3D
var build_materials := {}
var build_preview: BuildPreview
var preview_valid := false
var preview_transform := Transform3D.IDENTITY
var recoil_pitch := 0.0
var bloom_heat := 0.0
var current_spread_pixels := 4.0

func _ready() -> void:
	add_to_group("combatants")
	collision_layer = 2
	collision_mask = 5
	_create_body()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	inventory.add_weapon(ItemDatabase.weapon("vanguard_ar", "common"))
	inventory.add_resource("wood", 100)
	inventory.changed.connect(_inventory_changed)
	_create_build_materials()
	build_preview = BuildPreview.new()
	get_tree().current_scene.call_deferred("add_child", build_preview)
	build_preview.visible = false

func _create_body() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.45
	capsule_mesh.height = 1.8
	mesh.mesh = capsule_mesh
	mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("46a7ff")
	mesh.material_override = mat
	add_child(mesh)
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.45, 0)
	add_child(pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0.65, 0.45, 4.5)
	camera.current = true
	pivot.add_child(camera)

func _create_build_materials() -> void:
	for type in ["wood", "stone", "metal"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = {"wood":Color("b98958"), "stone":Color("9299a2"), "metal":Color("6e91a5")}[type]
		mat.roughness = 0.82
		build_materials[type] = mat

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := float(get_meta("mouse_sensitivity", 1.0))
		rotate_y(-event.relative.x * 0.0025 * sensitivity)
		pivot.rotation.x = clamp(pivot.rotation.x - event.relative.y * 0.0025 * sensitivity, -1.15, 0.75)
	if event.is_action_pressed("build_toggle"):
		build_mode = not build_mode
		if is_instance_valid(build_preview): build_preview.visible = build_mode
		stats_changed.emit()
	if event.is_action_pressed("simple_mode"):
		simple_build = not simple_build
		simple_edit = simple_build
		stats_changed.emit()
	if event.is_action_pressed("build_wall"): _number_action(0, "wall")
	if event.is_action_pressed("build_floor"): _number_action(1, "floor")
	if event.is_action_pressed("build_ramp"): _number_action(2, "ramp")
	if event.is_action_pressed("build_roof"): _number_action(3, "roof")
	if event.is_action_pressed("inventory_slot_5") and not build_mode: inventory.select(4)
	if event.is_action_pressed("rotate_piece"): build_rotation += PI * 0.5
	if event.is_action_pressed("edit_piece"): _edit_target()
	if event.is_action_pressed("reload"): inventory.reload_selected()
	if event.is_action_pressed("interact"): _interact()
	if event.is_action_pressed("fire"):
		if build_mode: _place_build()
		else: _use_selected()

func _number_action(slot: int, piece: String) -> void:
	if build_mode:
		selected_piece = piece
		if is_instance_valid(build_preview): build_preview.rebuild(piece)
	else: inventory.select(slot)
	stats_changed.emit()

func _physics_process(delta: float) -> void:
	if not is_on_floor(): velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = 8.2
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := 10.5 if Input.is_action_pressed("sprint") else 6.8
	velocity.x = move_toward(velocity.x, direction.x * speed, 35.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 35.0 * delta)
	move_and_slide()
	_update_weapon_recovery(delta)
	if build_mode: _update_build_preview()
	if Input.is_action_pressed("fire") and not build_mode:
		var item := inventory.selected()
		if item.get("kind", "") == "weapon" and float(item.fire_rate) > 2.0: _fire(item)

func _update_weapon_recovery(delta: float) -> void:
	bloom_heat = move_toward(bloom_heat, 0.0, delta * 2.6)
	var recovery := minf(recoil_pitch, delta * 0.85)
	pivot.rotation.x = clamp(pivot.rotation.x + recovery, -1.15, 0.75)
	recoil_pitch -= recovery
	var item := inventory.selected()
	if item.get("kind", "") != "weapon":
		current_spread_pixels = 4.0
		return
	var move_factor := float(item.get("move_spread", 1.0)) if Vector2(velocity.x, velocity.z).length() > 1.0 else 1.0
	var aim_factor := 0.55 if Input.is_action_pressed("aim") else 1.0
	current_spread_pixels = maxf(2.0, float(item.spread) * 650.0 * move_factor * aim_factor * (1.0 + bloom_heat))
	camera.position.z = lerpf(camera.position.z, 3.2 if Input.is_action_pressed("aim") else 4.5, delta * 10.0)

func _update_build_preview() -> void:
	if not is_instance_valid(build_preview): return
	preview_transform = _calculate_build_transform()
	preview_valid = _can_place_build(preview_transform)
	build_preview.global_transform = preview_transform
	build_preview.set_valid(preview_valid)
	build_preview.visible = true

func _calculate_build_transform() -> Transform3D:
	var ray_origin := camera.global_position
	var ray_end := ray_origin + -camera.global_transform.basis.z * (5.0 if simple_build else 8.0)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	query.collision_mask = 1 | 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target := hit.position if hit else ray_end
	if simple_build: target = global_position + -global_transform.basis.z * 2.4
	target.x = snappedf(target.x, 4.0)
	target.z = snappedf(target.z, 4.0)
	target.y = snappedf(maxf(0.0, target.y), 3.0)
	return Transform3D(Basis(Vector3.UP, snappedf(rotation.y + build_rotation, PI * 0.5)), target)

func _can_place_build(candidate: Transform3D) -> bool:
	if int(inventory.resources.get(selected_material, 0)) < 10: return false
	var position_to_test := candidate.origin
	if position_to_test.distance_to(global_position) > 10.0: return false
	for existing in get_tree().get_nodes_in_group("build_pieces"):
		if is_instance_valid(existing) and existing.global_position.distance_to(position_to_test) < 0.45 and existing.piece_type == selected_piece: return false
	var supported := position_to_test.y <= 0.25
	if not supported:
		var down_query := PhysicsRayQueryParameters3D.create(position_to_test + Vector3.UP * 0.5, position_to_test + Vector3.DOWN * 1.2)
		down_query.exclude = [self]
		down_query.collision_mask = 1 | 4
		supported = not get_world_3d().direct_space_state.intersect_ray(down_query).is_empty()
	if not supported:
		for existing in get_tree().get_nodes_in_group("build_pieces"):
			if is_instance_valid(existing) and existing.global_position.distance_to(position_to_test) <= 4.2:
				supported = true
				break
	return supported

func _use_selected() -> void:
	var item := inventory.selected()
	if item.is_empty(): _harvest_swing()
	elif item.get("kind", "") == "weapon": _fire(item)
	elif item.get("kind", "") == "consumable":
		inventory.consume_selected(self)
		stats_changed.emit()

func _fire(weapon: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_action_time < 1.0 / float(weapon.fire_rate) or int(weapon.loaded) <= 0: return
	last_action_time = now
	weapon.loaded -= 1
	_apply_recoil(weapon)
	if weapon.get("class", "") == "explosive":
		_fire_projectile(weapon)
		stats_changed.emit()
		return
	var pellets := int(weapon.get("pellets", 1))
	for i in pellets:
		var center := camera.get_viewport().get_visible_rect().size * 0.5
		var point := center + Vector2(randf_range(-current_spread_pixels, current_spread_pixels), randf_range(-current_spread_pixels, current_spread_pixels))
		var origin := camera.project_ray_origin(point)
		var end := origin + camera.project_ray_normal(point) * float(weapon.range)
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [self]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit and hit.collider.has_method("apply_damage"):
			var damage := ItemDatabase.damage_at_distance(weapon, origin.distance_to(hit.position))
			var critical := false
			if hit.collider is RoyalePlayer or hit.collider is TacticalBot:
				critical = hit.collider.to_local(hit.position).y > 1.35
				if critical: damage *= 1.75
			if hit.collider is BuildPiece: damage *= float(weapon.get("structure_mult", 1.0))
			hit.collider.apply_damage(damage, self)
			hit_confirmed.emit(damage, critical)
	stats_changed.emit()

func _apply_recoil(weapon: Dictionary) -> void:
	var amount := float(weapon.get("recoil", 0.01))
	var applied := amount * (0.65 if Input.is_action_pressed("aim") else 1.0)
	pivot.rotation.x = clamp(pivot.rotation.x - applied, -1.15, 0.75)
	recoil_pitch += applied
	rotate_y(randf_range(-applied * 0.25, applied * 0.25))
	bloom_heat = minf(1.8, bloom_heat + 0.18)

func _fire_projectile(weapon: Dictionary) -> void:
	var projectile := CombatProjectile.new()
	get_tree().current_scene.add_child(projectile)
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var direction := camera.project_ray_normal(center)
	projectile.setup(camera.global_position + direction * 1.2, direction, self, weapon)

func _harvest_swing() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_action_time < 0.72: return
	last_action_time = now
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 4.0)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("harvest"): hit.collider.harvest(50.0, self)

func _interact() -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 4.2)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("interact"): hit.collider.interact(self)

func _place_build() -> void:
	_update_build_preview()
	if not preview_valid or not inventory.spend_resource(selected_material, 10): return
	var piece := BuildPiece.new()
	get_tree().current_scene.add_child(piece)
	piece.global_transform = preview_transform
	piece.setup(selected_piece, build_materials[selected_material], get_instance_id(), selected_material)
	if simple_build and selected_piece == "ramp" and Input.is_action_pressed("sprint"): _place_companion_wall(preview_transform)
	stats_changed.emit()

func _place_companion_wall(base_transform: Transform3D) -> void:
	if not inventory.spend_resource(selected_material, 10): return
	var wall := BuildPiece.new()
	get_tree().current_scene.add_child(wall)
	wall.global_transform = base_transform.translated_local(Vector3(0, 0, -2.0))
	wall.setup("wall", build_materials[selected_material], get_instance_id(), selected_material)

func _edit_target() -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 10.0)
	query.exclude = [self]
	query.collision_mask = 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is BuildPiece and int(hit.collider.owner_id) == get_instance_id():
		if simple_edit: hit.collider.simple_edit_from_local_hit(hit.collider.to_local(hit.position))
		else: hit.collider.cycle_edit(false)

func collect_loot(item: Dictionary) -> bool:
	match item.get("kind", ""):
		"weapon": return inventory.add_weapon(item)
		"consumable": return inventory.add_consumable(item.id, int(item.get("amount", 1)))
		"ammo":
			inventory.add_ammo(item.ammo, int(item.amount))
			return true
		"resource":
			inventory.add_resource(item.resource, int(item.amount))
			return true
	return false

func receive_resource(type: String, amount: int) -> void:
	inventory.add_resource(type, amount)

func apply_damage(amount: float, _source = null) -> void:
	var absorbed := minf(shield, amount)
	shield -= absorbed
	health -= amount - absorbed
	stats_changed.emit()
	if health <= 0.0:
		eliminated.emit()
		if is_instance_valid(build_preview): build_preview.queue_free()
		queue_free()

func _inventory_changed() -> void:
	stats_changed.emit()
