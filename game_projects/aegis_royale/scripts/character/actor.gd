class_name Actor
extends CharacterBody3D

## Shared combatant: movement, health, weapons, ammo, loot and build access.
## PlayerController and Bot both extend this and only supply intent.

signal died(victim: Actor, killer: Node)
signal damaged(amount: float, source: Node)
signal stats_changed
signal hit_confirm(amount: float, critical: bool)

const GRAVITY: float = 22.0
const SPEED_WALK: float = 5.6
const SPEED_SPRINT: float = 8.7
const SPEED_CROUCH: float = 3.0
const JUMP_VELOCITY: float = 7.7
const HEAD_HEIGHT: float = 1.50
const ACCEL_GROUND: float = 62.0
const ACCEL_AIR: float = 16.0

var display_name: String = "Actor"
var team: int = 0
var max_health: float = 100.0
var health: float = 100.0
var max_shield: float = 100.0
var shield: float = 0.0
var is_dead: bool = false

var resources: Dictionary = {"wood": 0, "stone": 0, "metal": 0}
var slots: Array = [{}, {}, {}, {}, {}]
var active_slot: int = 0
var ammo: Dictionary = {"light": 0, "medium": 0, "shells": 0, "heavy": 0, "rockets": 0}

var build: BuildSystem
var model: CharacterModel
var animator: CharacterAnimator
var rig: WeaponRig

var move_input: Vector2 = Vector2.ZERO
var want_jump: bool = false
var want_sprint: bool = false
var want_crouch: bool = false
var yaw: float = 0.0
var aim_pitch: float = 0.0
var trigger: bool = false
var fire_cooldown: float = 0.0
var burst_left: int = 0
var burst_timer: float = 0.0
var reload_timer: float = 0.0
var bloom: float = 0.0
var recoil: float = 0.0
var use_timer: float = 0.0
var use_item: Dictionary = {}
var aim_blend: float = 0.0
var last_damage_time: float = -20.0
var last_damage_source: Node = null
var skill: float = 0.6
var world: Node3D
var kills: int = 0
var crouching: bool = false
var want_aim: bool = false
var build_registry: Dictionary = {}
var last_hit_point: Vector3 = Vector3.ZERO
var last_hit_valid: bool = false

func aim_spread() -> float:
	var w: Dictionary = current_weapon()
	if w.is_empty():
		return 0.0
	return _current_spread(w)

func _ready() -> void:
	if build != null:
		build.setup(self, world, build_registry)

func setup_actor(p_world: Node3D, p_name: String, p_team: int, outfit: Color, accent: Color) -> void:
	world = p_world
	display_name = p_name
	team = p_team
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(52.0)

	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.40
	capsule.height = 1.75
	collider.shape = capsule
	collider.position = Vector3(0.0, 0.90, 0.0)
	add_child(collider)

	model = CharacterModel.new()
	model.build(outfit, accent)
	add_child(model)

	animator = CharacterAnimator.new()
	animator.setup(model)
	add_child(animator)

	rig = WeaponRig.new()
	model.torso.add_child(rig)

	add_to_group("actors")
	build = BuildSystem.new()
	add_child(build)

func equip_starting_kit(weapon_id: String = "vanguard_ar", rarity: int = 0, start_resources: int = 150) -> void:
	slots[0] = WeaponDB.make(weapon_id, rarity)
	active_slot = 0
	ammo["light"] = int(WeaponDB.AMMO_START["light"])
	ammo["medium"] = int(WeaponDB.AMMO_START["medium"])
	ammo["shells"] = int(WeaponDB.AMMO_START["shells"])
	ammo["heavy"] = int(WeaponDB.AMMO_START["heavy"])
	ammo["rockets"] = int(WeaponDB.AMMO_START["rockets"])
	resources["wood"] = start_resources
	resources["stone"] = start_resources / 2
	resources["metal"] = start_resources / 3
	if rig != null and not slots[0].is_empty():
		rig.build(slots[0])
	stats_changed.emit()

func current_weapon() -> Dictionary:
	if active_slot < 0 or active_slot >= slots.size():
		return {}
	var s: Dictionary = slots[active_slot]
	if String(s.get("kind", "")) == "weapon":
		return s
	return {}

func current_item() -> Dictionary:
	if active_slot < 0 or active_slot >= slots.size():
		return {}
	return slots[active_slot]

func select_slot(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	active_slot = index
	reload_timer = 0.0
	burst_left = 0
	var w: Dictionary = current_weapon()
	if rig != null:
		rig.build(w)
	stats_changed.emit()

func switch_to_best_weapon() -> void:
	var best: int = -1
	var best_score: float = -1.0
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		if String(s.get("kind", "")) != "weapon":
			continue
		var sc: float = WeaponDB.score(s)
		if sc > best_score:
			best_score = sc
			best = i
	if best >= 0 and best != active_slot:
		select_slot(best)

# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -1.0

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 45.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 45.0 * delta)
		move_and_slide()
		_update_visual(delta)
		return

	_tick_timers(delta)
	_move_step(delta)
	_weapon_step(delta)
	_update_visual(delta)

func _tick_timers(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	bloom = move_toward(bloom, 0.0, delta * 3.2)
	var recover: float = minf(recoil, delta * 1.7)
	aim_pitch = clampf(aim_pitch + recover, -1.35, 1.35)
	recoil -= recover
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
	if use_timer > 0.0:
		use_timer -= delta
		if use_timer <= 0.0:
			_finish_use()
	if burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			if _shoot_once():
				burst_left -= 1
				burst_timer = 0.085
			else:
				burst_left = 0

func _move_step(delta: float) -> void:
	crouching = want_crouch and is_on_floor()
	if want_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		want_jump = false

	var local_dir: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	if local_dir.length_squared() > 1.0:
		local_dir = local_dir.normalized()
	var dir: Vector3 = Basis(Vector3.UP, yaw) * local_dir

	var speed: float = SPEED_WALK
	if crouching:
		speed = SPEED_CROUCH
	elif want_sprint and move_input.y < -0.1:
		speed = SPEED_SPRINT
	if aim_blend > 0.4:
		speed *= 0.62
	if use_timer > 0.0:
		speed *= 0.45

	var accel: float = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	move_and_slide()

func _update_visual(delta: float) -> void:
	if model == null:
		return
	var planar: float = Vector2(velocity.x, velocity.z).length()
	animator.pose(delta, planar, SPEED_SPRINT, aim_blend > 0.45, aim_pitch,
		is_on_floor(), velocity.y, crouching, is_dead)
	if rig != null and is_instance_valid(rig):
		rig.set_stance(clampf(aim_blend, 0.0, 1.0), aim_pitch * 0.8)
	var target_yaw: float = _resolve_body_yaw()
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 15.0, 1.0))
	animator.set_lean(clampf(planar / SPEED_SPRINT, 0.0, 1.0) * 0.16)

func _resolve_body_yaw() -> float:
	return yaw

# ------------------------------------------------------------------ weapons

func _weapon_step(delta: float) -> void:
	var w: Dictionary = current_weapon()
	if w.is_empty():
		aim_blend = move_toward(aim_blend, 0.0, delta * 6.0)
		return
	var aim_target: float = 1.0 if (want_aim or trigger) else 0.0
	if use_timer > 0.0:
		return
	if reload_timer > 0.0:
		aim_blend = move_toward(aim_blend, maxf(aim_target, 0.5), delta * 6.0)
		return
	var ammo_type: String = String(w.get("ammo", "medium"))
	if int(w.get("loaded", 0)) <= 0:
		if trigger:
			try_reload()
		aim_blend = move_toward(aim_blend, maxf(aim_target, 0.4), delta * 6.0)
		return
	if trigger:
		if fire_cooldown <= 0.0 and burst_left <= 0:
			if bool(w.get("auto", true)):
				_shoot_once()
			else:
				var burst: int = int(w.get("burst", 1))
				burst_left = maxi(1, burst) - 1
				burst_timer = 0.085
				if not _shoot_once():
					burst_left = 0
		aim_blend = move_toward(aim_blend, maxf(aim_target, 0.9), delta * 10.0)
	else:
		aim_blend = move_toward(aim_blend, aim_target, delta * 8.0)

func _current_spread(w: Dictionary) -> float:
	var base: float = float(w.get("spread", 0.02))
	var move_factor: float = 1.0
	var planar: float = Vector2(velocity.x, velocity.z).length()
	if planar > 1.0:
		move_factor = float(w.get("move_spread", 1.5)) * clampf(planar / SPEED_SPRINT, 0.35, 1.2)
	var air_factor: float = 2.6 if not is_on_floor() else 1.0
	var aim_factor: float = 0.55 if aim_blend > 0.5 else 1.0
	var crouch_factor: float = 0.78 if crouching else 1.0
	return base * move_factor * air_factor * aim_factor * crouch_factor * (1.0 + bloom)

func _shoot_once() -> bool:
	var w: Dictionary = current_weapon()
	if w.is_empty():
		return false
	if int(w.get("loaded", 0)) <= 0:
		return false
	var ammo_type: String = String(w.get("ammo", "medium"))
	w["loaded"] = int(w["loaded"]) - 1
	slots[active_slot] = w

	var origin: Vector3 = aim_origin()
	var base_dir: Vector3 = aim_direction()
	var spread: float = _current_spread(w)
	var pellets: int = maxi(1, int(w.get("pellets", 1)))
	if bool(w.get("projectile", false)):
		_spawn_projectile(origin, base_dir, w)
	else:
		for i: int in pellets:
			_fire_ray(origin, _spread_dir(base_dir, spread), w, i == 0)

	if rig != null and is_instance_valid(rig):
		rig.flash()
	Effects.smoke_puff(world, origin, Color(0.85, 0.85, 0.85), 0.5)

	var rpm: float = maxf(float(w.get("rpm", 120.0)), 1.0)
	fire_cooldown = 60.0 / rpm
	bloom = minf(bloom + 0.14, 1.6)
	var kick: float = float(w.get("recoil", 0.012))
	recoil += kick
	aim_pitch = clampf(aim_pitch - kick * (0.45 if aim_blend > 0.5 else 1.0), -1.35, 1.35)
	stats_changed.emit()
	return true

func _spread_dir(dir: Vector3, spread: float) -> Vector3:
	if spread <= 0.0:
		return dir
	var basis: Basis = Basis(Vector3.UP, yaw)
	var right: Vector3 = basis.x
	var up: Vector3 = basis.y
	var a: float = randf() * TAU
	var r: float = sqrt(randf()) * spread
	return (dir + right * cos(a) * r + up * sin(a) * r).normalized()

func _fire_ray(origin: Vector3, dir: Vector3, w: Dictionary, primary: bool) -> void:
	var max_range: float = float(w.get("range", 150.0))
	var end: Vector3 = origin + dir * max_range
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	q.collision_mask = 1 | 2 | 4
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var point: Vector3 = end
	var tracer_color: Color = w.get("color", Color("ffd07a"))
	if tracer_color is Color:
		pass
	else:
		tracer_color = Color("ffd07a")

	if not hit.is_empty():
		point = hit["position"]
		last_hit_point = point
		last_hit_valid = true
		var collider: Object = hit["collider"]
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		if collider is Actor:
			var victim: Actor = collider
			if victim != self and victim.team != team and not victim.is_dead:
				var dist: float = origin.distance_to(point)
				var falloff: float = _falloff(w, dist)
				var head: bool = point.y > victim.global_position.y + HEAD_HEIGHT
				var dmg: float = float(w.get("damage", 20.0)) * falloff * (1.85 if head else 1.0)
				victim.take_damage(dmg, self, head)
				Effects.impact(world, point, normal, Color("e04b4b"), 0.8)
				Effects.smoke_puff(world, point, Color(0.75, 0.2, 0.2), 0.4)
			else:
				Effects.impact(world, point, normal, Color("c8c8c8"), 0.6)
		elif collider is BuildPiece:
			var piece: BuildPiece = collider
			var dist2: float = origin.distance_to(point)
			var mult: float = float(w.get("structure_mult", 1.0))
			piece.apply_damage(float(w.get("damage", 20.0)) * _falloff(w, dist2) * mult, self)
			Effects.impact(world, point, normal, BuildPiece.MAT_COLOR.get(piece.mat_type, Color("bb8a52")), 0.7)
		else:
			Effects.impact(world, point, normal, Color("cfc7b4"), 0.55)
			if collider != null and collider.has_method("apply_damage"):
				collider.call("apply_damage", float(w.get("damage", 20.0)) * 0.5, self)

	if primary:
		Effects.tracer(world, origin, point, tracer_color, 0.030)
	else:
		Effects.tracer(world, origin, point, tracer_color, 0.020)

func _falloff(w: Dictionary, dist: float) -> float:
	var start: float = float(w.get("falloff_start", 40.0))
	var end: float = float(w.get("falloff_end", 120.0))
	var min_mult: float = float(w.get("min_mult", 0.6))
	if dist <= start:
		return 1.0
	if dist >= end:
		return min_mult
	var t: float = (dist - start) / maxf(end - start, 0.001)
	return lerpf(1.0, min_mult, t)

func _spawn_projectile(origin: Vector3, dir: Vector3, w: Dictionary) -> void:
	var p: CombatProjectile = CombatProjectile.new()
	world.add_child(p)
	p.launch(origin, dir, self, w)

func try_reload() -> bool:
	var w: Dictionary = current_weapon()
	if w.is_empty():
		return false
	var mag: int = int(w.get("mag", 1))
	if int(w.get("loaded", 0)) >= mag:
		return false
	var ammo_type: String = String(w.get("ammo", "medium"))
	if int(ammo.get(ammo_type, 0)) <= 0:
		return false
	reload_timer = float(w.get("reload", 2.0))
	stats_changed.emit()
	return true

func _finish_reload() -> void:
	var w: Dictionary = current_weapon()
	if w.is_empty():
		return
	var mag: int = int(w.get("mag", 1))
	var ammo_type: String = String(w.get("ammo", "medium"))
	var need: int = mag - int(w.get("loaded", 0))
	var have: int = int(ammo.get(ammo_type, 0))
	var take: int = mini(need, have)
	w["loaded"] = int(w.get("loaded", 0)) + take
	ammo[ammo_type] = have - take
	slots[active_slot] = w
	stats_changed.emit()

func is_reloading() -> bool:
	return reload_timer > 0.0

# ------------------------------------------------------------------ aim hooks

func aim_origin() -> Vector3:
	if rig != null and is_instance_valid(rig):
		return rig.muzzle_position()
	return global_position + Vector3.UP * HEAD_HEIGHT

func aim_direction() -> Vector3:
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, aim_pitch)
	return -basis.z

# ------------------------------------------------------------------ damage

func take_damage(amount: float, source: Node = null, head: bool = false) -> void:
	if is_dead:
		return
	var remaining: float = amount
	if shield > 0.0:
		var absorbed: float = minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	health -= remaining
	last_damage_time = Time.get_ticks_msec() / 1000.0
	if source != null:
		last_damage_source = source
	damaged.emit(amount, source)
	if source is Actor:
		(source as Actor).notify_hit(amount, head)
	if health <= 0.0:
		die(source)

func notify_hit(amount: float, head: bool) -> void:
	hit_confirm.emit(amount, head)

func heal(amount: float, cap: float) -> void:
	health = minf(minf(health + amount, cap), max_health)
	stats_changed.emit()

func add_shield(amount: float, cap: float) -> void:
	shield = minf(minf(shield + amount, cap), max_shield)
	stats_changed.emit()

func die(killer: Node) -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if build != null:
		build.set_ghost_visible(false)
	Effects.smoke_puff(world, global_position + Vector3.UP * 1.0, Color(0.3, 0.3, 0.35), 1.2)
	Effects.debris_burst(world, global_position + Vector3.UP * 1.0, Color("9aa0a8"), 6)
	if killer is Actor:
		(killer as Actor).kills += 1
	died.emit(self, killer)
	stats_changed.emit()

func time_since_damage() -> float:
	return Time.get_ticks_msec() / 1000.0 - last_damage_time

# ------------------------------------------------------------------ loot

func receive_resource(type: String, amount: int) -> void:
	resources[type] = clampi(int(resources.get(type, 0)) + amount, 0, 999)
	stats_changed.emit()

func collect_loot(item: Dictionary) -> bool:
	var kind: String = String(item.get("kind", "weapon"))
	if kind == "ammo":
		var t: String = String(item.get("ammo", "medium"))
		ammo[t] = clampi(int(ammo.get(t, 0)) + int(item.get("amount", 12)), 0, 999)
		stats_changed.emit()
		return true
	if kind == "resource":
		receive_resource(String(item.get("resource", "wood")), int(item.get("amount", 20)))
		return true
	if kind == "consumable":
		return add_consumable(String(item.get("id", "bandage")), int(item.get("amount", 1)))
	if kind == "weapon":
		return add_weapon(item)
	return false

func add_weapon(item: Dictionary) -> bool:
	var empty: int = -1
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		if s.is_empty():
			empty = i
			break
	if empty >= 0:
		var w: Dictionary = item.duplicate(true)
		w["kind"] = "weapon"
		if not w.has("loaded"):
			w["loaded"] = int(w.get("mag", 1))
		slots[empty] = w
		ammo[String(w.get("ammo", "medium"))] = clampi(
			int(ammo.get(String(w.get("ammo", "medium")), 0)) + int(WeaponDB.AMMO_START.get(String(w.get("ammo", "medium")), 20)), 0, 999)
		if empty == active_slot or current_weapon().is_empty():
			select_slot(empty)
		stats_changed.emit()
		return true
	return false

func add_consumable(id: String, amount: int = 1) -> bool:
	var data: Dictionary = WeaponDB.CONSUMABLES.get(id, {})
	if data.is_empty():
		return false
	var stack: int = int(data.get("stack", 1))
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		if String(s.get("kind", "")) == "consumable" and String(s.get("id", "")) == id:
			if int(s.get("amount", 0)) < stack:
				s["amount"] = mini(stack, int(s.get("amount", 0)) + amount)
				slots[i] = s
				stats_changed.emit()
				return true
	var empty: int = -1
	for i: int in slots.size():
		if (slots[i] as Dictionary).is_empty():
			empty = i
			break
	if empty < 0:
		return false
	var entry: Dictionary = data.duplicate(true)
	entry["kind"] = "consumable"
	entry["id"] = id
	entry["amount"] = mini(amount, stack)
	slots[empty] = entry
	stats_changed.emit()
	return true

func use_selected() -> bool:
	var item: Dictionary = current_item()
	if String(item.get("kind", "")) != "consumable":
		return false
	use_item = item
	use_timer = float(item.get("use_time", 2.0))
	return true

func _finish_use() -> void:
	if use_item.is_empty():
		return
	var id: String = String(use_item.get("id", ""))
	var data: Dictionary = WeaponDB.CONSUMABLES.get(id, {})
	if not data.is_empty():
		if data.has("health"):
			heal(float(data["health"]), float(data.get("health_cap", 100.0)))
		if data.has("shield"):
			add_shield(float(data["shield"]), float(data.get("shield_cap", 100.0)))
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		if String(s.get("kind", "")) == "consumable" and String(s.get("id", "")) == id:
			s["amount"] = int(s.get("amount", 0)) - 1
			if int(s["amount"]) <= 0:
				slots[i] = {}
			else:
				slots[i] = s
			break
	use_item = {}
	stats_changed.emit()

# ------------------------------------------------------------------ build hooks

func on_piece_built(_piece: BuildPiece) -> void:
	pass

func on_piece_edited(_piece: BuildPiece) -> void:
	pass

func is_using_item() -> bool:
	return use_timer > 0.0
