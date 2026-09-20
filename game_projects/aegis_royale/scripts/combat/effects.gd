class_name Effects
extends RefCounted

## Lightweight combat feedback: tracers, muzzle smoke, impact sparks,
## explosions and floating damage numbers (screen space handled by the HUD).

static func orient_along(node: Node3D, from: Vector3, to: Vector3) -> void:
	var dir: Vector3 = to - from
	if dir.length_squared() < 0.0001:
		return
	var up: Vector3 = Vector3.UP
	if absf(dir.normalized().dot(Vector3.UP)) > 0.995:
		up = Vector3.RIGHT
	node.look_at_from_position(from, to, up)

static func tracer(world: Node3D, from: Vector3, to: Vector3, color: Color, width: float = 0.032) -> void:
	if world == null or not is_instance_valid(world):
		return
	var dist: float = from.distance_to(to)
	if dist < 0.4:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(width, width, dist)
	mi.mesh = bm
	mi.material_override = MatLib.glow(color, 2.4)
	world.add_child(mi)
	orient_along(mi, (from + to) * 0.5, to)
	mi.global_position = (from + to) * 0.5
	var tw: Tween = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.02, 0.02, 1.0), 0.055)
	tw.tween_callback(mi.queue_free)

static func impact(world: Node3D, point: Vector3, normal: Vector3, color: Color, power: float = 1.0) -> void:
	if world == null or not is_instance_valid(world):
		return
	var holder: Node3D = Node3D.new()
	world.add_child(holder)
	holder.global_position = point
	var spark: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.05 * power
	sm.height = 0.10 * power
	spark.mesh = sm
	spark.material_override = MatLib.glow(color, 3.0)
	holder.add_child(spark)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 3.0
	holder.add_child(light)
	for i: int in 4:
		var chip: MeshInstance3D = MeshInstance3D.new()
		var cm: BoxMesh = BoxMesh.new()
		cm.size = Vector3(0.035, 0.035, 0.035)
		chip.mesh = cm
		chip.material_override = MatLib.flat(color.darkened(0.3))
		holder.add_child(chip)
		var dir: Vector3 = (normal + Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1))).normalized()
		var target: Vector3 = chip.position + dir * randf_range(0.4, 1.0)
		var ctw: Tween = chip.create_tween()
		ctw.tween_property(chip, "position", target, 0.28)
		ctw.parallel().tween_property(chip, "scale", Vector3.ZERO, 0.28)
	var tw: Tween = holder.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.10)
	tw.tween_interval(0.16)
	tw.tween_callback(holder.queue_free)

static func explosion(world: Node3D, point: Vector3, radius: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var holder: Node3D = Node3D.new()
	world.add_child(holder)
	holder.global_position = point
	var mat: StandardMaterial3D = MatLib.alpha(Color(1.0, 0.55, 0.15, 0.72), 0.5, true)
	var ball: MeshInstance3D = MeshInstance3D.new()
	var bm: SphereMesh = SphereMesh.new()
	bm.radius = radius * 0.5
	bm.height = radius
	ball.mesh = bm
	ball.material_override = mat
	ball.scale = Vector3.ONE * 0.25
	holder.add_child(ball)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var rm: TorusMesh = TorusMesh.new()
	rm.inner_radius = radius * 0.7
	rm.outer_radius = radius * 0.95
	ring.mesh = rm
	ring.material_override = MatLib.glow(Color(1.0, 0.72, 0.3), 2.0)
	ring.scale = Vector3(0.2, 0.2, 0.2)
	holder.add_child(ring)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("ffa040")
	light.light_energy = 6.0
	light.omni_range = radius * 3.0
	holder.add_child(light)
	var tw: Tween = holder.create_tween()
	tw.tween_property(ball, "scale", Vector3.ONE * 1.6, 0.22)
	tw.parallel().tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.35)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.30)
	tw.parallel().tween_property(ball, "scale", Vector3.ONE * 2.1, 0.30).set_delay(0.22)
	tw.tween_callback(holder.queue_free)

static func smoke_puff(world: Node3D, point: Vector3, color: Color, scale: float = 1.0) -> void:
	if world == null or not is_instance_valid(world):
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.18 * scale
	sm.height = 0.36 * scale
	mi.mesh = sm
	mi.material_override = MatLib.alpha(Color(color.r, color.g, color.b, 0.55), 1.0, true)
	world.add_child(mi)
	mi.global_position = point
	var tw: Tween = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.45)
	tw.parallel().tween_property(mi, "position", point + Vector3.UP * 0.9, 0.45)
	tw.tween_callback(mi.queue_free)

static func debris_burst(world: Node3D, point: Vector3, color: Color, count: int = 7) -> void:
	if world == null or not is_instance_valid(world):
		return
	var holder: Node3D = Node3D.new()
	world.add_child(holder)
	holder.global_position = point
	for i: int in count:
		var chip: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		var s: float = randf_range(0.08, 0.22)
		bm.size = Vector3(s, s * 0.6, s)
		chip.mesh = bm
		chip.material_override = MatLib.flat(color.darkened(randf_range(0.0, 0.35)))
		holder.add_child(chip)
		var dir: Vector3 = Vector3(randf_range(-1, 1), randf_range(0.3, 1.4), randf_range(-1, 1)).normalized()
		var ctw: Tween = chip.create_tween()
		ctw.tween_property(chip, "position", dir * randf_range(0.8, 2.0), 0.6)
		ctw.parallel().tween_property(chip, "rotation", Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), 0.6)
		ctw.parallel().tween_property(chip, "scale", Vector3.ZERO, 0.6)
	var tw: Tween = holder.create_tween()
	tw.tween_interval(0.65)
	tw.tween_callback(holder.queue_free)
