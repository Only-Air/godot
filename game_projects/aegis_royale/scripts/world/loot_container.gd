class_name LootContainer
extends StaticBody3D

## Searchable chest. Press interact to burst out loot.

var tier: int = 0
var opened: bool = false
var lid: Node3D
var world: Node3D

func setup(p_tier: int = 0) -> void:
	tier = p_tier
	collision_layer = 1
	collision_mask = 2 | 4
	add_to_group("containers")
	var base_mat: StandardMaterial3D = MatLib.metal(Color("c8963c") if tier == 0 else Color("4fa8d8"))
	var trim_mat: StandardMaterial3D = MatLib.metal(Color("6b5a34") if tier == 0 else Color("2c6a8c"))

	var body_mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.5, 0.85, 0.95)
	body_mesh.mesh = bm
	body_mesh.position = Vector3(0.0, 0.42, 0.0)
	body_mesh.material_override = base_mat
	add_child(body_mesh)

	lid = Node3D.new()
	lid.position = Vector3(0.0, 0.85, -0.475)
	add_child(lid)
	var lid_mesh: MeshInstance3D = MeshInstance3D.new()
	var lm: BoxMesh = BoxMesh.new()
	lm.size = Vector3(1.5, 0.18, 0.95)
	lid_mesh.mesh = lm
	lid_mesh.position = Vector3(0.0, 0.09, 0.475)
	lid_mesh.material_override = trim_mat
	lid.add_child(lid_mesh)

	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(1.5, 1.0, 0.95)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.5, 0.0)
	add_child(cs)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("ffd98a") if tier == 0 else Color("8ad8ff")
	light.light_energy = 0.9
	light.omni_range = 3.2
	light.position = Vector3(0.0, 0.9, 0.0)
	add_child(light)

func interact(_user: Node = null) -> bool:
	if opened:
		return false
	opened = true
	var tw: Tween = create_tween()
	tw.tween_property(lid, "rotation", Vector3(-1.9, 0.0, 0.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_loot()
	return true

func _spawn_loot() -> void:
	var parent: Node3D = get_parent() as Node3D
	if parent == null:
		return
	Effects.debris_burst(parent, global_position + Vector3.UP * 0.9, Color("ffd98a"), 6)
	var max_rarity: int = 5 if tier >= 2 else (4 if tier == 1 else 3)
	var count: int = 1 if tier == 0 else 2
	for i: int in count:
		var w: Dictionary = WeaponDB.random_weapon(max_rarity)
		w["kind"] = "weapon"
		_spawn(parent, w, Vector3(randf_range(-0.8, 0.8), 0.9, randf_range(-0.8, 0.8)))
		var ammo: Dictionary = {
			"kind": "ammo",
			"ammo": String(w.get("ammo", "medium")),
			"amount": randi_range(14, 40),
		}
		_spawn(parent, ammo, Vector3(randf_range(-1.1, 1.1), 0.9, randf_range(-1.1, 1.1)))
	if randf() < 0.85:
		var ids: Array = WeaponDB.CONSUMABLES.keys()
		var id: String = String(ids[randi() % ids.size()])
		_spawn(parent, {"kind": "consumable", "id": id, "amount": 1}, Vector3(randf_range(-0.9, 0.9), 0.9, randf_range(-0.9, 0.9)))
	if tier >= 1:
		var res: String = ["wood", "stone", "metal"][randi() % 3]
		_spawn(parent, {"kind": "resource", "resource": res, "amount": randi_range(40, 90)}, Vector3(randf_range(-1.0, 1.0), 0.9, randf_range(-1.0, 1.0)))

func _spawn(parent: Node3D, data: Dictionary, offset: Vector3) -> void:
	var pickup: LootPickup = LootPickup.new()
	parent.add_child(pickup)
	pickup.global_position = global_position + offset + Vector3.UP * 0.4
	pickup.setup(data)
