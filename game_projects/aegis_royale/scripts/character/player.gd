class_name PlayerController
extends Actor

## Local player: over-shoulder camera, build mode, tile editing, looting.

var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var build_mode: bool = false
var simple_mode: bool = false
var sensitivity: float = 1.0
var ui_locked: bool = false
var harvest_cooldown: float = 0.0
var melee_cooldown: float = 0.0
var drop_mode: bool = false
var drop_speed: float = -22.0
var glider_open: bool = false

func _ready() -> void:
	super._ready()
	_setup_camera()

func _setup_camera() -> void:
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	if world != null:
		world.add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 3.4
	arm.position = Vector3(0.62, 0.16, 0.0)
	arm.collision_mask = 1 | 4
	arm.margin = 0.35
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.current = true
	arm.add_child(camera)

func aim_origin() -> Vector3:
	if camera != null and is_instance_valid(camera):
		return camera.global_position
	return global_position + Vector3.UP * HEAD_HEIGHT

func aim_direction() -> Vector3:
	if camera != null and is_instance_valid(camera):
		return -camera.global_transform.basis.z
	return super.aim_direction()

func _resolve_body_yaw() -> float:
	if aim_blend > 0.4 or build_mode:
		return yaw
	var local: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	if local.length_squared() < 0.04:
		return yaw
	var world_dir: Vector3 = Basis(Vector3.UP, yaw) * local
	return atan2(-world_dir.x, -world_dir.z)

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if ui_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		yaw -= mm.relative.x * 0.0022 * sensitivity
		aim_pitch = clampf(aim_pitch - mm.relative.y * 0.0022 * sensitivity, -1.35, 1.35)
		return
	if is_dead:
		return
	if event.is_action_pressed("build_toggle"):
		build_mode = not build_mode
		if build_mode and build.is_editing():
			build.cancel_edit()
		build.set_ghost_visible(build_mode)
		stats_changed.emit()
	elif event.is_action_pressed("simple_mode"):
		simple_mode = not simple_mode
		build.simple_mode = simple_mode
		stats_changed.emit()
	elif event.is_action_pressed("rotate_piece"):
		if build_mode:
			build.rotate_step()
	elif event.is_action_pressed("material_cycle"):
		if build_mode:
			build.cycle_material()
			stats_changed.emit()
	elif event.is_action_pressed("edit_piece"):
		_handle_edit_key()
	elif event.is_action_pressed("reload"):
		if not build_mode:
			try_reload()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("slot_1"): _slot_press(0)
	elif event.is_action_pressed("slot_2"): _slot_press(1)
	elif event.is_action_pressed("slot_3"): _slot_press(2)
	elif event.is_action_pressed("slot_4"): _slot_press(3)
	elif event.is_action_pressed("slot_5"): _slot_press(4)
	elif event.is_action_pressed("wheel_up"):
		if not build_mode:
			select_slot((active_slot - 1 + slots.size()) % slots.size())
	elif event.is_action_pressed("wheel_down"):
		if not build_mode:
			select_slot((active_slot + 1) % slots.size())
	elif event.is_action_pressed("fire"):
		_on_fire_pressed()

func _slot_press(index: int) -> void:
	if build_mode:
		var order: Array[String] = ["wall", "floor", "ramp", "cone"]
		if index < order.size():
			build.set_piece(order[index])
		stats_changed.emit()
	else:
		select_slot(index)

func _on_fire_pressed() -> void:
	if build_mode:
		if build.is_editing():
			build.toggle_hovered_tile()
		return
	if current_weapon().is_empty():
		_melee_harvest()

func _physics_process(delta: float) -> void:
	if drop_mode:
		_glide(delta)
		_update_camera(delta)
		return
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	harvest_cooldown = maxf(0.0, harvest_cooldown - delta)
	if ui_locked:
		move_input = Vector2.ZERO
		trigger = false
		want_aim = false
		want_sprint = false
		want_jump = false
		super._physics_process(delta)
		_update_camera(delta)
		return
	if is_dead:
		move_input = Vector2.ZERO
		trigger = false
		super._physics_process(delta)
		_update_camera(delta)
		return

	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	want_sprint = Input.is_action_pressed("sprint")
	want_crouch = Input.is_action_pressed("crouch")
	want_jump = Input.is_action_pressed("jump")
	want_aim = Input.is_action_pressed("aim") and not build_mode
	trigger = Input.is_action_pressed("fire") and not build_mode and not build.is_editing() \
		and not current_weapon().is_empty()

	super._physics_process(delta)

	if build_mode:
		_update_build(delta)
	else:
		build.set_ghost_visible(false)
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if pivot == null or not is_instance_valid(pivot):
		return
	pivot.global_position = global_position + Vector3(0.0, 1.52, 0.0)
	pivot.rotation = Vector3(aim_pitch, yaw, 0.0)
	var aim: float = clampf(aim_blend, 0.0, 1.0)
	arm.spring_length = lerpf(3.4, 1.50, aim)
	arm.position = Vector3(0.62, 0.16, 0.0).lerp(Vector3(0.42, 0.10, 0.0), aim)
	camera.fov = lerpf(78.0, 60.0, aim)

# ------------------------------------------------------------------ building

func _update_build(_delta: float) -> void:
	var aim_point: Vector3 = aim_origin() + aim_direction() * 9.0
	if build.is_editing():
		build.set_ghost_visible(false)
		var pick: Dictionary = _pick_build()
		if not pick.is_empty():
			var piece: BuildPiece = pick.get("piece")
			var pos: Vector3 = pick.get("position", Vector3.ZERO)
			if piece != null and piece == build.edit_piece:
				build.hover_tile(piece.to_local(pos))
		return
	build.set_ghost_visible(true)
	build.compute_target(global_position, yaw, aim_pitch, aim_point)
	if Input.is_action_pressed("fire"):
		build.try_place()

func _pick_build() -> Dictionary:
	var origin: Vector3 = aim_origin()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + aim_direction() * 6.0)
	q.collision_mask = 4
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider")
	if collider is BuildPiece:
		return {"piece": collider, "position": hit["position"], "normal": hit.get("normal", Vector3.UP)}
	return {}

func _handle_edit_key() -> void:
	if not build_mode:
		return
	if build.is_editing():
		build.confirm_edit()
		stats_changed.emit()
		return
	var pick: Dictionary = _pick_build()
	if pick.is_empty():
		return
	var piece: BuildPiece = pick.get("piece")
	var pos: Vector3 = pick.get("position", Vector3.ZERO)
	if build.begin_edit(piece, piece.to_local(pos)):
		stats_changed.emit()

func cancel_edit_mode() -> void:
	if build.is_editing():
		build.cancel_edit()

# ------------------------------------------------------------------ interaction

func _interact() -> void:
	var origin: Vector3 = aim_origin()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + aim_direction() * 4.5)
	q.collision_mask = 1 | 4
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider != null and collider.has_method("interact"):
		collider.call("interact", self)

func _melee_harvest() -> void:
	if melee_cooldown > 0.0:
		return
	melee_cooldown = 0.45
	var origin: Vector3 = aim_origin()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + aim_direction() * 4.0)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	var point: Vector3 = hit["position"]
	Effects.impact(world, point, hit.get("normal", Vector3.UP), Color("cfc7b4"), 0.7)
	if collider != null and collider.has_method("harvest"):
		collider.call("harvest", 26.0, self)

func set_ui_locked(locked: bool) -> void:
	ui_locked = locked
	if locked:
		trigger = false
		want_aim = false

func begin_drop(height: float) -> void:
	drop_mode = true
	glider_open = false
	drop_speed = -22.0
	global_position.y = height

func _glide(delta: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.is_action_pressed("jump"):
		glider_open = true
	if global_position.y <= 42.0:
		glider_open = true
	drop_speed = lerpf(drop_speed, -7.5 if glider_open else -24.0, delta * 3.5)
	var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed: float = 17.0 if glider_open else 10.0
	global_position += dir * speed * delta
	global_position.y += drop_speed * delta
	aim_pitch = clampf(aim_pitch, -1.1, 0.5)
	rotation.y = lerp_angle(rotation.y, yaw, minf(delta * 8.0, 1.0))
	if rig != null and is_instance_valid(rig):
		rig.set_stance(0.0, aim_pitch * 0.5)
	var ground: float = 0.0
	var terrains: Array = get_tree().get_nodes_in_group("terrain")
	if not terrains.is_empty():
		ground = float(terrains[0].call("height_at", global_position.x, global_position.z))
	if global_position.y <= ground + 1.05:
		global_position.y = ground + 1.05
		drop_mode = false
		velocity = Vector3.ZERO
		if world != null:
			Effects.smoke_puff(world, global_position, Color(0.88, 0.86, 0.78), 1.8)
			Effects.debris_burst(world, global_position, Color("9aa08a"), 5)
		stats_changed.emit()

func drop_status() -> String:
	if not drop_mode:
		return ""
	if glider_open:
		return "滑翔中 · WASD 调整方向"
	return "自由落体 · 按 空格 展开滑翔翼"
