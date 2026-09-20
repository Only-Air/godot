class_name Storm
extends Node3D

## Phase based shrinking ring with an offset centre, matching the classic
## battle royale pacing: a safe wait, then a closing window.

signal phase_advanced(index: int)

const RADII: Array[float] = [178.0, 132.0, 96.0, 66.0, 42.0, 24.0, 12.0, 4.0]
const WAIT: Array[float] = [42.0, 34.0, 30.0, 26.0, 22.0, 18.0, 16.0]
const CLOSE: Array[float] = [36.0, 32.0, 28.0, 24.0, 20.0, 17.0, 14.0]

var center: Vector3 = Vector3.ZERO
var target_center: Vector3 = Vector3.ZERO
var radius: float = 178.0
var target_radius: float = 178.0
var phase: int = 0
var timer: float = 42.0
var shrinking: bool = false
var finished: bool = false
var wall: MeshInstance3D
var ring: MeshInstance3D
var material: StandardMaterial3D

func setup() -> void:
	add_to_group("storm")
	radius = RADII[0]
	target_radius = RADII[0]
	timer = WAIT[0]
	center = Vector3.ZERO
	target_center = Vector3.ZERO
	_build_visual()

func _build_visual() -> void:
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0.52, 0.24, 0.92, 0.26)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(0.45, 0.18, 0.85) * 0.7

	wall = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 60.0
	cyl.radial_segments = 96
	cyl.cap_top = false
	cyl.cap_bottom = false
	wall.mesh = cyl
	wall.material_override = material
	wall.position = Vector3(0.0, 30.0, 0.0)
	add_child(wall)

	ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.985
	torus.outer_radius = 1.015
	torus.rings = 96
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = MatLib.glow(Color(0.75, 0.45, 1.0), 1.8)
	ring.position = Vector3(0.0, 0.6, 0.0)
	add_child(ring)

func _process(delta: float) -> void:
	if finished:
		return
	timer -= delta
	if not shrinking:
		if timer <= 0.0:
			shrinking = true
			target_radius = RADII[mini(phase + 1, RADII.size() - 1)]
			_pick_center()
			timer = CLOSE[mini(phase, CLOSE.size() - 1)]
	else:
		var total: float = CLOSE[mini(phase, CLOSE.size() - 1)]
		var rate: float = maxf((RADII[mini(phase, RADII.size() - 1)] - target_radius) / maxf(total, 0.01), 0.6)
		radius = move_toward(radius, target_radius, rate * delta * 3.0)
		center = center.move_toward(target_center, maxf(1.2, radius * 0.02) * delta)
		if timer <= 0.0:
			phase += 1
			shrinking = false
			radius = target_radius
			center = target_center
			phase_advanced.emit(phase)
			if phase >= RADII.size() - 1:
				finished = true
			else:
				timer = WAIT[mini(phase, WAIT.size() - 1)]
	_apply_visual()
	_damage_outside(delta)

func _pick_center() -> void:
	var room: float = maxf(radius - target_radius - 4.0, 0.0)
	var angle: float = randf() * TAU
	var dist: float = randf_range(0.0, room)
	target_center = center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _apply_visual() -> void:
	global_position = Vector3(center.x, 0.0, center.z)
	wall.scale = Vector3(radius, 1.0, radius)
	ring.scale = Vector3(radius, radius, radius)
	var pulse: float = 0.22 + 0.06 * sin(Time.get_ticks_msec() / 420.0)
	material.albedo_color = Color(0.52, 0.24, 0.92, pulse)

func _damage_outside(delta: float) -> void:
	var dps: float = 1.6 + float(phase) * 1.5
	for a in get_tree().get_nodes_in_group("actors"):
		var actor: Actor = a as Actor
		if actor == null or actor.is_dead:
			continue
		if distance_to_center(actor.global_position) > radius:
			actor.take_damage(dps * delta, null)

func distance_to_center(pos: Vector3) -> float:
	return Vector2(pos.x - center.x, pos.z - center.z).length()

func is_safe(pos: Vector3, margin: float = 0.0) -> bool:
	return distance_to_center(pos) < radius - margin

func seconds_left() -> float:
	return maxf(timer, 0.0)

func is_shrinking() -> bool:
	return shrinking

func phase_label() -> String:
	if finished:
		return "最终区域"
	if shrinking:
		return "风暴推进中"
	return "风暴静止"
