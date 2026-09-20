class_name HarvestProp
extends StaticBody3D

## Destructible environment that yields wood / stone / metal.

var resource_type: String = "wood"
var health: float = 200.0
var max_health: float = 200.0
var per_hit: int = 10
var visual: MeshInstance3D

const COLORS: Dictionary = {
	"wood": Color("8a5f3a"), "stone": Color("8b8578"), "metal": Color("7d8b98"),
}
const HEALTH: Dictionary = {"wood": 180.0, "stone": 300.0, "metal": 420.0}
const YIELD: Dictionary = {"wood": 11, "stone": 9, "metal": 7}

func setup(type: String, size: Vector3, color_override: Color = Color(0, 0, 0, 0)) -> void:
	resource_type = type
	max_health = float(HEALTH.get(type, 200.0))
	health = max_health
	per_hit = int(YIELD.get(type, 8))
	collision_layer = 1
	collision_mask = 2 | 4
	add_to_group("harvestables")
	var col: Color = color_override if color_override.a > 0.0 else COLORS.get(type, Color("8a5f3a"))
	var mat: StandardMaterial3D = MatLib.flat(col, 0.0, 0.95) if type != "metal" else MatLib.metal(col)
	visual = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	visual.mesh = bm
	visual.position = Vector3(0.0, size.y * 0.5, 0.0)
	visual.material_override = mat
	add_child(visual)
	if type == "wood":
		var crown: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = maxf(size.x, size.z) * 1.5
		cm.height = size.y * 1.4
		cm.radial_segments = 6
		crown.mesh = cm
		crown.material_override = MatLib.foliage(Color("3f7a3c"))
		crown.position = Vector3(0.0, size.y * 1.5, 0.0)
		add_child(crown)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(cs)

func harvest(amount: float, user: Node) -> void:
	_damage(amount, user, true)

func apply_damage(amount: float, source: Node = null) -> void:
	_damage(amount, source, false)

func _damage(amount: float, user: Node, full_yield: bool) -> void:
	health -= amount
	if user != null and user.has_method("receive_resource"):
		var gain: int = per_hit if full_yield else maxi(1, per_hit / 3)
		user.call("receive_resource", resource_type, gain)
	if visual != null and is_instance_valid(visual):
		visual.modulate = Color(1.7, 1.4, 1.4)
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color.WHITE, 0.15)
	if health <= 0.0:
		var parent_node: Node3D = get_parent() as Node3D
		if parent_node != null:
			Effects.debris_burst(parent_node, global_position + Vector3.UP * 0.8, COLORS.get(resource_type, Color.WHITE), 8)
		queue_free()
