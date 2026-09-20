class_name HarvestProp
extends StaticBody3D

var health := 200.0
var resource_type := "wood"
var resource_per_hit := 8

func setup(type: String, size: Vector3, color: Color) -> void:
	resource_type = type
	health = {"wood":180.0, "stone":300.0, "metal":400.0}.get(type, 200.0)
	resource_per_hit = {"wood":10, "stone":8, "metal":6}.get(type, 8)
	collision_layer = 1
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position.y = size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = size.y * 0.5
	add_child(collider)

func harvest(amount: float, user) -> void:
	health -= amount
	if user != null and user.has_method("receive_resource"):
		user.receive_resource(resource_type, resource_per_hit)
	if health <= 0.0: queue_free()

func apply_damage(amount: float, source = null) -> void:
	health -= amount
	if source != null and source.has_method("receive_resource"):
		source.receive_resource(resource_type, maxi(1, resource_per_hit / 3))
	if health <= 0.0: queue_free()
