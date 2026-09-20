class_name RoyalePlayer
extends CharacterBody3D

signal stats_changed
signal eliminated

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
		rotate_y(-event.relative.x * 0.0025)
		pivot.rotation.x = clamp(pivot.rotation.x - event.relative.y * 0.0025, -1.15, 0.75)
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("build_toggle"):
		build_mode = not build_mode
		stats_changed.emit()
	if event.is_action_pressed("simple_mode"):
		simple_build = not simple_build
		simple_edit = simple_build
		stats_changed.emit()
	if event.is_action_pressed("build_wall"): _number_action(0, "wall")
	if event.is_action_pressed("build_floor"): _number_action(1, "floor")
	if event.is_action_pressed("build_ramp"): _number_action(2, "ramp")
	if event.is_action_pressed("build_roof"): _number_action(3, "roof")
	if event.is_action_pressed("rotate_piece"): build_rotation += PI * 0.5
	if event.is_action_pressed("edit_piece"): _edit_target()
	if event.is_action_pressed("reload"): inventory.reload_selected()
	if event.is_action_pressed("interact"): _interact()
	if event.is_action_pressed("fire"):
		if build_mode: _place_build()
		else: _use_selected()

func _number_action(slot: int, piece: String) -> void:
	if build_mode: selected_piece = piece
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
	if Input.is_action_pressed("fire") and not build_mode:
		var item := inventory.selected()
		if item.get("kind", "") == "weapon" and float(item.fire_rate) > 2.0: _fire(item)

func _use_selected() -> void:
	var item := inventory.selected()
	if item.is_empty():
		_harvest_swing()
	elif item.get("kind", "") == "weapon":
		_fire(item)
	elif item.get("kind", "") == "consumable":
		inventory.consume_selected(self)
		stats_changed.emit()

func _fire(weapon: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_action_time < 1.0 / float(weapon.fire_rate) or int(weapon.loaded) <= 0: return
	last_action_time = now
	weapon.loaded -= 1
	var pellets := int(weapon.get("pellets", 1))
	for i in pellets:
		var center := camera.get_viewport().get_visible_rect().size * 0.5
		var spread := float(weapon.spread) * 650.0
		var point := center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		var origin := camera.project_ray_origin(point)
		var end := origin + camera.project_ray_normal(point) * float(weapon.range)
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [self]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit and hit.collider.has_method("apply_damage"):
			var multiplier := float(weapon.get("structure_mult", 1.0)) if hit.collider is BuildPiece else 1.0
			hit.collider.apply_damage(float(weapon.damage) * multiplier, self)
	stats_changed.emit()

func _harvest_swing() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_action_time < 0.72: return
	last_action_time = now
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 4.0)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("harvest"):
		hit.collider.harvest(50.0, self)

func _interact() -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 4.2)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("interact"): hit.collider.interact(self)

func _place_build() -> void:
	if not inventory.spend_resource(selected_material, 10): return
	var forward := -global_transform.basis.z
	var target := global_position + forward * (2.2 if simple_build else 4.0)
	target.x = snappedf(target.x, 2.0)
	target.z = snappedf(target.z, 2.0)
	target.y = snappedf(maxf(target.y, 0.0), 1.5)
	var piece := BuildPiece.new()
	get_tree().current_scene.add_child(piece)
	piece.global_position = target
	piece.rotation.y = snappedf(rotation.y + build_rotation, PI * 0.5)
	piece.setup(selected_piece, build_materials[selected_material], get_instance_id())
	piece.health = {"wood":150.0, "stone":300.0, "metal":500.0}[selected_material]
	stats_changed.emit()

func _edit_target() -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 10.0)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is BuildPiece and int(hit.collider.owner_id) == get_instance_id():
		hit.collider.cycle_edit(simple_edit)

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
		queue_free()

func _inventory_changed() -> void:
	stats_changed.emit()
