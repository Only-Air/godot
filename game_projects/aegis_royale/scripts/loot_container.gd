class_name LootContainer
extends StaticBody3D

var opened := false
var container_tier := 0
var visual: MeshInstance3D

func setup(tier: int = 0) -> void:
	container_tier = tier
	collision_layer = 1
	collision_mask = 2
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 0.72, 0.72)
	collider.shape = shape
	collider.position.y = 0.36
	add_child(collider)
	visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	visual.mesh = box
	visual.position.y = 0.36
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d39a36") if tier == 0 else Color("69b9dc")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.18
	visual.material_override = mat
	add_child(visual)

func interact(_user = null) -> bool:
	if opened: return false
	opened = true
	visual.rotation.z = -0.65
	_spawn_loot()
	return true

func _spawn_loot() -> void:
	var weapon := LootPickup.new()
	get_tree().current_scene.add_child(weapon)
	weapon.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 1.1, randf_range(-0.6, 0.6))
	var weapon_data := ItemDatabase.random_weapon(4 if container_tier > 0 else 3)
	weapon_data.kind = "weapon"
	weapon.setup(weapon_data)
	var ammo_pickup := LootPickup.new()
	get_tree().current_scene.add_child(ammo_pickup)
	ammo_pickup.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 1.0, randf_range(-0.8, 0.8))
	ammo_pickup.setup({"kind":"ammo", "ammo":weapon_data.ammo, "amount":randi_range(12, 36), "color":Color("e9cb65")})
	if randf() < 0.72:
		var ids := ItemDatabase.CONSUMABLES.keys()
		var consumable := LootPickup.new()
		get_tree().current_scene.add_child(consumable)
		consumable.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 1.0, randf_range(-0.8, 0.8))
		consumable.setup({"kind":"consumable", "id":ids[randi() % ids.size()], "amount":1, "color":Color("60d9b3")})
