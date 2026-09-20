class_name CombatProjectile
extends Area3D

## Rocket / grenade style projectile with gravity, blast falloff and
## structure damage.

var vel: Vector3 = Vector3.ZERO
var drop: float = 0.0
var damage: float = 90.0
var structure_mult: float = 2.0
var blast: float = 5.0
var life: float = 9.0
var shooter: Node = null
var done: bool = false
var world: Node3D

func launch(origin: Vector3, dir: Vector3, source: Node, w: Dictionary) -> void:
	world = get_parent() as Node3D
	global_position = origin
	shooter = source
	var speed: float = float(w.get("velocity", 46.0))
	vel = dir.normalized() * speed
	drop = 3.2
	damage = float(w.get("splash_damage", w.get("damage", 90.0)))
	structure_mult = float(w.get("structure_mult", 2.0))
	blast = float(w.get("splash", 5.0))
	collision_layer = 0
	collision_mask = 1 | 2 | 4
	monitoring = false
	monitorable = false

	var cs: CollisionShape3D = CollisionShape3D.new()
	var sp: SphereShape3D = SphereShape3D.new()
	sp.radius = 0.18
	cs.shape = sp
	add_child(cs)

	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	mi.mesh = sm
	mi.material_override = MatLib.glow(Color("ff9a3c"), 2.4)
	add_child(mi)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("ffa050")
	light.light_energy = 2.0
	light.omni_range = 8.0
	add_child(light)

	var trail: CPUParticles3D = CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.55
	trail.mesh = sm
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.08
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = 0.35
	trail.scale_amount_max = 0.7
	trail.color = Color(1.0, 0.6, 0.25, 0.6)
	add_child(trail)

func _physics_process(delta: float) -> void:
	if done:
		return
	life -= delta
	if life <= 0.0:
		explode(global_position)
		return
	var start: Vector3 = global_position
	vel.y -= drop * delta
	var end: Vector3 = start + vel * delta
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	q.collision_mask = 1 | 2 | 4
	if shooter is Actor:
		q.exclude = [(shooter as Actor).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		explode(hit["position"])
	else:
		global_position = end
		look_at(global_position + vel.normalized(), Vector3.UP)

func explode(point: Vector3) -> void:
	if done:
		return
	done = true
	velocity_off()
	global_position = point
	Effects.explosion(world, point, blast)
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = blast
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, point)
	q.collision_mask = 1 | 2 | 4
	if shooter is Actor:
		q.exclude = [(shooter as Actor).get_rid()]
	var hits: Array = get_world_3d().direct_space_state.intersect_shape(q, 64)
	var seen: Dictionary = {}
	for h in hits:
		var d: Dictionary = h
		var collider: Object = d.get("collider")
		if collider == null or not is_instance_valid(collider):
			continue
		if seen.has(collider):
			continue
		seen[collider] = true
		if not collider.has_method("apply_damage"):
			continue
		var node3d: Node3D = collider as Node3D
		if node3d == null:
			continue
		var dist: float = point.distance_to(node3d.global_position)
		var falloff: float = clampf(1.0 - dist / blast, 0.15, 1.0)
		var mult: float = 1.0
		if collider is BuildPiece or collider is HarvestProp:
			mult = structure_mult
		collider.call("apply_damage", damage * falloff * mult, shooter)
	await get_tree().create_timer(0.1).timeout
	queue_free()

func velocity_off() -> void:
	monitoring = false
	set_physics_process(false)
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
		elif c is OmniLight3D:
			(c as OmniLight3D).light_energy = 0.0
		elif c is CPUParticles3D:
			(c as CPUParticles3D).emitting = false
