class_name Bot
extends Actor

## Tactical AI. Runs a utility state machine with real perception (FOV + line of
## sight), target memory, range management, burst fire discipline, reactive
## cover building, ramp pushes, panic boxing and storm rotation.

enum State { LOOT, ROTATE, ENGAGE, DEFEND, PUSH }

const EYE_HEIGHT: float = 1.45

var state: int = State.LOOT
var target: Actor = null
var has_target: bool = false
var target_memory: float = 0.0
var last_known: Vector3 = Vector3.ZERO

var scan_timer: float = 0.0
var decision_timer: float = 0.0
var aim_error: Vector2 = Vector2.ZERO
var aim_error_timer: float = 0.0
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var burst_time: float = 0.0
var burst_cooldown: float = 0.0
var build_cooldown: float = 0.0
var react_window: float = 0.0
var reaction_delay: float = 0.0
var waypoint: Vector3 = Vector3.ZERO
var waypoint_timer: float = 0.0
var stuck_timer: float = 0.0
var last_pos: Vector3 = Vector3.ZERO
var jump_timer: float = 0.0
var heal_hold: float = 0.0
var loot_target: Node3D = null
var loot_scan_timer: float = 0.0
var storm: Storm = null
var aggression: float = 0.5
var caution: float = 0.5
var view_range: float = 72.0
var preferred_range: float = 22.0
var personality: String = "balanced"
var boxed: bool = false
var box_timer: float = 0.0
var push_timer: float = 0.0

func configure(p_skill: float, p_personality: String) -> void:
	skill = clampf(p_skill, 0.15, 1.0)
	personality = p_personality
	view_range = lerpf(46.0, 92.0, skill)
	reaction_delay = lerpf(0.52, 0.11, skill)
	match personality:
		"aggressive":
			aggression = clampf(skill + 0.25, 0.2, 1.0)
			caution = clampf(skill - 0.25, 0.1, 1.0)
		"builder":
			aggression = clampf(skill - 0.05, 0.2, 1.0)
			caution = clampf(skill + 0.2, 0.1, 1.0)
		"marksman":
			aggression = clampf(skill - 0.15, 0.2, 1.0)
			caution = clampf(skill + 0.1, 0.1, 1.0)
		"cautious":
			aggression = clampf(skill - 0.25, 0.2, 1.0)
			caution = clampf(skill + 0.3, 0.1, 1.0)
		_:
			aggression = skill
			caution = skill

func _ready() -> void:
	super._ready()
	call_deferred("_find_storm")

func _find_storm() -> void:
	var list: Array = get_tree().get_nodes_in_group("storm")
	if not list.is_empty():
		storm = list[0]

func _physics_process(delta: float) -> void:
	if not is_dead:
		_think(delta)
	super._physics_process(delta)

# ------------------------------------------------------------------ thinking

func _think(delta: float) -> void:
	scan_timer -= delta
	decision_timer -= delta
	aim_error_timer -= delta
	strafe_timer -= delta
	loot_scan_timer -= delta
	waypoint_timer -= delta
	react_window -= delta
	build_cooldown = maxf(0.0, build_cooldown - delta)
	burst_cooldown = maxf(0.0, burst_cooldown - delta)
	jump_timer -= delta

	if scan_timer <= 0.0:
		scan_timer = lerpf(0.30, 0.12, skill)
		_scan()
	if aim_error_timer <= 0.0:
		aim_error_timer = randf_range(0.30, 0.75)
		_refresh_aim_error()
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(1.0, 2.6)
		strafe_dir = 1.0 if randf() < 0.5 else -1.0
	if decision_timer <= 0.0:
		decision_timer = randf_range(0.22, 0.45)
		_decide()
	_react()
	_act(delta)
	_check_stuck(delta)

func _scan() -> void:
	var best: Actor = null
	var best_score: float = -1.0
	for node in get_tree().get_nodes_in_group("actors"):
		var other: Actor = node as Actor
		if other == null or other == self or other.is_dead or other.team == team:
			continue
		var dist: float = global_position.distance_to(other.global_position)
		if dist > view_range:
			continue
		if not _has_los(other):
			continue
		var score: float = 1.0 - dist / view_range
		if other == target:
			score += 0.35
		if score > best_score:
			best_score = score
			best = other
	if best != null:
		target = best
		has_target = true
		target_memory = 4.0
		last_known = best.global_position
	elif has_target:
		target_memory -= scan_timer + 0.05
		if target_memory <= 0.0 or not is_instance_valid(target) or target.is_dead:
			has_target = false
			target = null
			if not is_instance_valid(target):
				target = null

func _has_los(other: Actor) -> bool:
	var from: Vector3 = global_position + Vector3.UP * EYE_HEIGHT
	var to: Vector3 = other.global_position + Vector3.UP * EYE_HEIGHT
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 4
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()

func _refresh_aim_error() -> void:
	var base: float = lerpf(0.075, 0.012, skill)
	var dist_factor: float = 1.0
	if has_target and is_instance_valid(target):
		dist_factor = clampf(global_position.distance_to(target.global_position) / 40.0, 0.6, 2.2)
	var mag: float = base * dist_factor
	aim_error = Vector2(randf_range(-mag, mag), randf_range(-mag * 0.7, mag * 0.7))

func _decide() -> void:
	var storm_urgent: bool = false
	if storm != null and is_instance_valid(storm):
		var d: float = storm.distance_to_center(global_position)
		if d > storm.radius - 12.0:
			storm_urgent = true
	if storm_urgent:
		state = State.ROTATE
		return
	var hp_ratio: float = health / max_health
	if has_target and is_instance_valid(target) and not target.is_dead:
		var dist: float = global_position.distance_to(target.global_position)
		if hp_ratio < 0.35 and caution > 0.3:
			state = State.DEFEND
		elif dist < 16.0 and aggression > 0.6 and hp_ratio > 0.45:
			state = State.PUSH
		else:
			state = State.ENGAGE
		return
	if (hp_ratio < 0.72 or shield < max_shield * 0.45) and _has_heal():
		state = State.DEFEND
		return
	state = State.LOOT

func _react() -> void:
	if react_window <= 0.0 or build_cooldown > 0.0:
		return
	if last_damage_source == null or not is_instance_valid(last_damage_source):
		return
	var src: Node3D = last_damage_source as Node3D
	if src == null:
		return
	var dir: Vector3 = (src.global_position - global_position)
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()
	if int(resources.get("wood", 0)) >= BuildSystem.COST:
		if build.ai_place_facing(global_position, dir, "wall") != null:
			build_cooldown = randf_range(0.55, 1.4) / maxf(aggression, 0.25)
			react_window = 0.0

# ------------------------------------------------------------------ acting

func _act(delta: float) -> void:
	match state:
		State.ENGAGE: _do_engage(delta)
		State.PUSH: _do_push(delta)
		State.DEFEND: _do_defend(delta)
		State.ROTATE: _do_rotate(delta)
		_: _do_loot(delta)

func _do_engage(delta: float) -> void:
	if not _has_live_target():
		move_input = Vector2.ZERO
		trigger = false
		return
	var to: Vector3 = target.global_position - global_position
	var dist: float = to.length()
	var flat: Vector3 = Vector3(to.x, 0.0, to.z).normalized()
	_aim_at(target.global_position + Vector3.UP * 1.15, delta)

	var move: Vector3 = Vector3.ZERO
	if dist > preferred_range + 7.0:
		move += flat
	elif dist < preferred_range - 6.0:
		move -= flat
	move += flat.cross(Vector3.UP) * strafe_dir * 0.85
	if caution > 0.55 and dist < 10.0:
		move -= flat * 1.2
	_apply_move(move, false)
	_combat_fire(delta, dist)
	if build_cooldown <= 0.0 and caution > 0.5 and dist < 26.0 and randf() < 0.25:
		if build.ai_place_facing(global_position, flat, "wall") != null:
			build_cooldown = randf_range(1.1, 2.4)

func _do_push(delta: float) -> void:
	if not _has_live_target():
		move_input = Vector2.ZERO
		trigger = false
		return
	var to: Vector3 = target.global_position - global_position
	var dist: float = to.length()
	var flat: Vector3 = Vector3(to.x, 0.0, to.z).normalized()
	_aim_at(target.global_position + Vector3.UP * 1.15, delta)
	var move: Vector3 = flat + flat.cross(Vector3.UP) * strafe_dir * 0.35
	_apply_move(move, true)
	_combat_fire(delta, dist)
	push_timer -= delta
	if push_timer <= 0.0 and build_cooldown <= 0.0 and int(resources.get("wood", 0)) >= BuildSystem.COST * 2:
		push_timer = randf_range(0.9, 1.8)
		build_cooldown = randf_range(0.5, 1.1)
		var wall: BuildPiece = build.ai_place_facing(global_position + flat * 1.2, flat, "wall")
		if wall != null:
			build.ai_place_facing(global_position + flat * 1.2, flat, "ramp")
	if dist < 5.0 and randf() < 0.04:
		want_jump = true

func _do_defend(delta: float) -> void:
	if _has_live_target():
		_aim_at(target.global_position + Vector3.UP * 1.15, delta)
	else:
		var settle: Vector3 = last_known if last_known != Vector3.ZERO else global_position + Vector3.FORWARD * 8.0
		_aim_at(settle, delta)
	trigger = false
	box_timer -= delta
	if not boxed and int(resources.get("wood", 0)) >= BuildSystem.COST * 2:
		build.ai_box_self()
		build.ai_place_facing(global_position, Vector3.FORWARD, "floor")
		boxed = true
		box_timer = randf_range(4.0, 7.0)
	move_input = Vector2.ZERO
	if _has_heal() and not is_using_item() and not is_reloading():
		_use_heal()
	if boxed and box_timer <= 0.0 and health > max_health * 0.7:
		boxed = false
		state = State.ENGAGE if _has_live_target() else State.LOOT

func _do_rotate(delta: float) -> void:
	trigger = false
	if storm == null or not is_instance_valid(storm):
		state = State.LOOT
		return
	var to_center: Vector3 = storm.center - global_position
	to_center.y = 0.0
	var dist_to_center: float = to_center.length()
	var flat: Vector3 = to_center.normalized()
	var target_point: Vector3 = storm.center - flat * maxf(storm.radius * 0.45, 6.0)
	var to_point: Vector3 = target_point - global_position
	to_point.y = 0.0
	var move: Vector3 = to_point.normalized() if to_point.length() > 3.0 else Vector3.ZERO
	if move.length() > 0.1:
		_apply_move(move, true)
	else:
		move_input = Vector2.ZERO
	if _has_live_target() and global_position.distance_to(target.global_position) < 30.0:
		_aim_at(target.global_position + Vector3.UP * 1.15, delta)
	else:
		_aim_at(global_position + move * 10.0 + Vector3.UP * 1.0, delta)
	if _has_live_target():
		_combat_fire(delta, global_position.distance_to(target.global_position))
	if dist_to_center > storm.radius and randf() < 0.05:
		want_jump = true

func _do_loot(delta: float) -> void:
	trigger = false
	if loot_scan_timer <= 0.0:
		loot_scan_timer = randf_range(0.5, 1.1)
		loot_target = _find_loot()
	if loot_target != null and is_instance_valid(loot_target):
		var to: Vector3 = loot_target.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist < 2.2:
			loot_target = null
		else:
			_apply_move(to.normalized(), dist > 12.0)
			_aim_at(loot_target.global_position + Vector3.UP * 0.8, delta)
			return
	var container: Node3D = _find_container()
	if container != null:
		var cto: Vector3 = container.global_position - global_position
		cto.y = 0.0
		if cto.length() < 2.6:
			if container.has_method("interact"):
				container.call("interact", self)
		else:
			_apply_move(cto.normalized(), false)
			_aim_at(container.global_position + Vector3.UP * 0.6, delta)
			return
	if waypoint_timer <= 0.0 or global_position.distance_to(waypoint) < 4.0:
		waypoint_timer = randf_range(3.0, 7.0)
		waypoint = _pick_patrol_point()
	var wto: Vector3 = waypoint - global_position
	wto.y = 0.0
	if wto.length() > 3.0:
		_apply_move(wto.normalized(), wto.length() > 20.0)
	_aim_at(global_position + wto.normalized() * 8.0 + Vector3.UP * 1.2, delta)

# ------------------------------------------------------------------ helpers

func _has_live_target() -> bool:
	return has_target and target != null and is_instance_valid(target) and not target.is_dead

func _aim_at(point: Vector3, delta: float) -> void:
	var eye: Vector3 = global_position + Vector3.UP * EYE_HEIGHT
	var to: Vector3 = point - eye
	var flat: Vector3 = Vector3(to.x, 0.0, to.z)
	if flat.length_squared() < 0.0001:
		return
	var desired_yaw: float = atan2(-to.x, -to.z)
	var desired_pitch: float = asin(clampf(to.normalized().y, -1.0, 1.0))
	var turn: float = lerpf(5.5, 15.0, skill)
	yaw = lerp_angle(yaw, desired_yaw + aim_error.x, minf(delta * turn, 1.0))
	aim_pitch = lerpf(aim_pitch, clampf(desired_pitch + aim_error.y, -1.2, 1.2), minf(delta * turn, 1.0))

func _aim_aligned(point: Vector3, tolerance: float) -> bool:
	var dir: Vector3 = aim_direction()
	var to: Vector3 = (point - (global_position + Vector3.UP * EYE_HEIGHT)).normalized()
	return dir.dot(to) > cos(tolerance)

func _combat_fire(delta: float, dist: float) -> void:
	var w: Dictionary = current_weapon()
	if w.is_empty():
		if _has_better_weapon_in_slots():
			switch_to_best_weapon()
		return
	if int(w.get("loaded", 0)) <= 0:
		trigger = false
		if not is_reloading():
			try_reload()
		return
	var aim_point: Vector3 = target.global_position + Vector3.UP * 1.15 if _has_live_target() else global_position + aim_direction() * 20.0
	if _has_live_target():
		var lead: Vector3 = target.velocity * (dist / maxf(float(w.get("velocity", 200.0)), 1.0)) * lerpf(0.2, 1.0, skill)
		aim_point += lead
	var tolerance: float = lerpf(0.20, 0.045, skill)
	var aligned: bool = _aim_aligned(aim_point, tolerance)
	var visible: bool = (not _has_live_target()) or _has_los(target)
	if burst_time > 0.0:
		burst_time -= delta
		trigger = aligned and visible
	elif burst_cooldown <= 0.0 and aligned and visible:
		burst_time = randf_range(0.22, 0.75) * lerpf(0.7, 1.3, aggression)
		burst_cooldown = randf_range(0.18, 0.55) / maxf(aggression, 0.25)
		trigger = true
	else:
		trigger = false

func _apply_move(world_dir: Vector3, sprint: bool) -> void:
	var flat: Vector3 = Vector3(world_dir.x, 0.0, world_dir.z)
	if flat.length_squared() < 0.0001:
		move_input = Vector2.ZERO
		return
	flat = flat.normalized()
	var local: Vector3 = Basis(Vector3.UP, yaw).inverse() * flat
	move_input = Vector2(local.x, local.z)
	if move_input.length() > 1.0:
		move_input = move_input.normalized()
	want_sprint = sprint
	want_crouch = false

func _check_stuck(delta: float) -> void:
	if move_input.length() < 0.2:
		stuck_timer = 0.0
		last_pos = global_position
		return
	if global_position.distance_to(last_pos) < 0.06:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_pos = global_position
	if stuck_timer > 0.55:
		stuck_timer = 0.0
		want_jump = true
		strafe_dir = -strafe_dir

func _find_loot() -> Node3D:
	var best: Node3D = null
	var best_score: float = -1.0
	var current: Dictionary = current_weapon()
	var current_score: float = WeaponDB.score(current) if not current.is_empty() else 0.0
	for node in get_tree().get_nodes_in_group("loot"):
		var pickup: Node3D = node as Node3D
		if pickup == null or not is_instance_valid(pickup):
			continue
		var dist: float = global_position.distance_to(pickup.global_position)
		if dist > 45.0:
			continue
		var item: Dictionary = {}
		if "item" in pickup:
			item = pickup.get("item")
		var value: float = 0.35
		if String(item.get("kind", "")) == "weapon":
			var ws: float = WeaponDB.score(item)
			value = 1.0 if ws > current_score * 1.04 else 0.1
		elif String(item.get("kind", "")) == "consumable":
			value = 0.8 if health < max_health * 0.8 or shield < max_shield * 0.6 else 0.2
		elif String(item.get("kind", "")) == "ammo":
			value = 0.6
		var score: float = value - dist / 60.0
		if score > best_score:
			best_score = score
			best = pickup
	if best_score < 0.05:
		return null
	return best

func _find_container() -> Node3D:
	var best: Node3D = null
	var best_dist: float = 34.0
	for node in get_tree().get_nodes_in_group("containers"):
		var c: Node3D = node as Node3D
		if c == null or not is_instance_valid(c):
			continue
		if bool(c.get("opened")):
			continue
		var d: float = global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			best = c
	return best

func _pick_patrol_point() -> Vector3:
	var base: Vector3 = global_position
	if storm != null and is_instance_valid(storm):
		base = storm.center
		var inner: float = maxf(storm.radius * 0.6, 8.0)
		var angle: float = randf() * TAU
		var r: float = randf_range(0.0, inner)
		return Vector3(base.x + cos(angle) * r, 0.0, base.z + sin(angle) * r)
	var a: float = randf() * TAU
	var rr: float = randf_range(10.0, 40.0)
	return Vector3(base.x + cos(a) * rr, 0.0, base.z + sin(a) * rr)

func _has_heal() -> bool:
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		if String(s.get("kind", "")) == "consumable" and int(s.get("amount", 0)) > 0:
			var data: Dictionary = WeaponDB.CONSUMABLES.get(String(s.get("id", "")), {})
			if data.has("health") or data.has("shield"):
				return true
	return false

func _use_heal() -> void:
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		if String(s.get("kind", "")) != "consumable" or int(s.get("amount", 0)) <= 0:
			continue
		var data: Dictionary = WeaponDB.CONSUMABLES.get(String(s.get("id", "")), {})
		if data.is_empty():
			continue
		var need_health: bool = data.has("health") and health < max_health * 0.85
		var need_shield: bool = data.has("shield") and shield < max_shield * 0.85
		if need_health or need_shield:
			select_slot(i)
			use_selected()
			return

func _has_better_weapon_in_slots() -> bool:
	var best: int = -1
	var best_score: float = 0.0
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		if String(s.get("kind", "")) != "weapon":
			continue
		var sc: float = WeaponDB.score(s)
		if sc > best_score:
			best_score = sc
			best = i
	return best >= 0 and best != active_slot

func state_label() -> String:
	match state:
		State.ENGAGE: return "交战"
		State.PUSH: return "推进"
		State.DEFEND: return "防御"
		State.ROTATE: return "转点"
		_: return "搜刮"
