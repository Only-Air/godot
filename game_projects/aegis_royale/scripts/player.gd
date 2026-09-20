class_name RoyalePlayer
extends CharacterBody3D

signal stats_changed
signal eliminated

var health := 100.0
var shield := 50.0
var materials := 500
var weapon := WeaponData.get_weapon("ranger_rifle")
var ammo_in_mag := 30
var reserve_ammo := 180
var build_mode := false
var simple_build := false
var simple_edit := false
var selected_piece := "wall"
var build_rotation := 0.0
var last_shot_time := -10.0
var gravity := 22.0
var camera: Camera3D
var pivot: Node3D
var build_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("combatants")
	collision_layer = 2
	collision_mask = 5
	_create_body()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ammo_in_mag = int(weapon.magazine)
	build_material = StandardMaterial3D.new()
	build_material.albedo_color = Color(0.25, 0.72, 1.0, 0.82)
	build_material.roughness = 0.75

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
	if event.is_action_pressed("build_wall"): selected_piece = "wall"
	if event.is_action_pressed("build_floor"): selected_piece = "floor"
	if event.is_action_pressed("build_ramp"): selected_piece = "ramp"
	if event.is_action_pressed("build_roof"): selected_piece = "roof"
	if event.is_action_pressed("rotate_piece"): build_rotation += PI * 0.5
	if event.is_action_pressed("edit_piece"): _edit_target()
	if event.is_action_pressed("reload"): _reload()
	if event.is_action_pressed("fire"):
		if build_mode: _place_build()
		else: _fire()

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
		_fire()

func _fire() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_shot_time < 1.0 / float(weapon.fire_rate) or ammo_in_mag <= 0: return
	last_shot_time = now
	ammo_in_mag -= 1
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
			hit.collider.apply_damage(float(weapon.damage), self)
	stats_changed.emit()

func _reload() -> void:
	var needed := int(weapon.magazine) - ammo_in_mag
	var moved := mini(needed, reserve_ammo)
	ammo_in_mag += moved
	reserve_ammo -= moved
	stats_changed.emit()

func _place_build() -> void:
	if materials < 10: return
	var forward := -global_transform.basis.z
	var target := global_position + forward * (2.2 if simple_build else 4.0)
	target.x = snappedf(target.x, 2.0)
	target.z = snappedf(target.z, 2.0)
	target.y = snappedf(maxf(target.y, 0.0), 1.5)
	var piece := BuildPiece.new()
	get_tree().current_scene.add_child(piece)
	piece.global_position = target
	piece.rotation.y = snappedf(rotation.y + build_rotation, PI * 0.5)
	piece.setup(selected_piece, build_material, get_instance_id())
	materials -= 10
	stats_changed.emit()

func _edit_target() -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 10.0)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is BuildPiece:
		hit.collider.cycle_edit(simple_edit)

func apply_damage(amount: float, _source = null) -> void:
	var absorbed := minf(shield, amount)
	shield -= absorbed
	health -= amount - absorbed
	stats_changed.emit()
	if health <= 0.0:
		eliminated.emit()
		queue_free()

func heal_from_pickup(amount: float) -> void:
	health = minf(100.0, health + amount)
	stats_changed.emit()
