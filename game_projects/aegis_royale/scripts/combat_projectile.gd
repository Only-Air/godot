class_name CombatProjectile
extends Area3D

var projectile_velocity: Vector3 = Vector3.ZERO
var projectile_gravity: float = 0.0
var damage: float = 90.0
var structure_multiplier: float = 2.0
var blast_radius: float = 5.0
var max_lifetime: float = 8.0
var owner_actor: Node
var exploded: bool = false

func setup(origin: Vector3, direction: Vector3, source: Node, weapon: Dictionary) -> void:
	global_position = origin
	owner_actor = source
	projectile_velocity = direction.normalized() * float(weapon.get("projectile_speed", 44.0))
	projectile_gravity = float(weapon.get("projectile_gravity", 2.4))
	damage = float(weapon.damage)
	structure_multiplier = float(weapon.get("structure_mult", 2.0))
	blast_radius = float(weapon.get("splash", 5.0))
	collision_layer = 0
	collision_mask = 1 | 2 | 4
	monitoring = true
	monitorable = false
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.16
	shape_node.shape = shape
	add_child(shape_node)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("ff9f43")
	material.emission_enabled = true
	material.emission = Color("ff6f1f") * 2.0
	mesh.material_override = material
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if exploded: return
	max_lifetime -= delta
	if max_lifetime <= 0.0:
		_explode(global_position)
		return
	var start: Vector3 = global_position
	projectile_velocity.y -= projectile_gravity * delta
	var destination: Vector3 = start + projectile_velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, destination)
	query.collision_mask = collision_mask
	if is_instance_valid(owner_actor): query.exclude = [owner_actor]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): _explode(hit["position"] as Vector3)
	else: global_position = destination

func _explode(position: Vector3) -> void:
	if exploded: return
	exploded = true
	global_position = position
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = blast_radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 1 | 2 | 4
	query.exclude = [owner_actor] if is_instance_valid(owner_actor) else []
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 64)
	var damaged: Dictionary = {}
	for hit: Dictionary in hits:
		var collider: Object = hit["collider"]
		if not is_instance_valid(collider) or damaged.has(collider): continue
		damaged[collider] = true
		if not collider.has_method("apply_damage"): continue
		var collider_node: Node3D = collider as Node3D
		var distance: float = position.distance_to(collider_node.global_position)
		var falloff: float = clampf(1.0 - distance / blast_radius, 0.2, 1.0)
		var multiplier: float = structure_multiplier if collider is BuildPiece or collider is HarvestProp else 1.0
		collider.apply_damage(damage * falloff * multiplier, owner_actor)
	_create_explosion_visual()
	await get_tree().create_timer(0.18).timeout
	queue_free()

func _create_explosion_visual() -> void:
	projectile_velocity = Vector3.ZERO
	collision_mask = 0
	var flash: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = blast_radius * 0.55
	sphere.height = blast_radius * 1.1
	flash.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.35, 0.08, 0.58)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.18, 0.03) * 2.0
	flash.material_override = material
	add_child(flash)
