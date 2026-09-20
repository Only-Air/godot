class_name LootPickup
extends Area3D

var item: Dictionary = {}
var visual: MeshInstance3D
var bob_origin := 0.0
var phase := 0.0

func setup(data: Dictionary) -> void:
	item = data.duplicate(true)
	bob_origin = position.y
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	add_to_group("loot_pickups")
	_create_visual()
	body_entered.connect(_on_body_entered)

func _ready() -> void:
	bob_origin = position.y
	phase = randf() * TAU

func _create_visual() -> void:
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	collider.shape = sphere
	add_child(collider)
	visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.3, 0.45) if item.get("kind", "weapon") == "weapon" else Vector3(0.55, 0.55, 0.55)
	visual.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.get("color", Color("71d4ff"))
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.55
	visual.material_override = mat
	add_child(visual)

func _process(delta: float) -> void:
	phase += delta * 2.0
	rotation.y += delta * 0.8
	position.y = bob_origin + sin(phase) * 0.13

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_loot"): return
	if body.collect_loot(item): queue_free()
