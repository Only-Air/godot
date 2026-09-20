class_name LootPickup
extends Area3D

## Floating world loot. Auto-collects when an actor walks over it.

var item: Dictionary = {}
var visual: MeshInstance3D
var base_y: float = 0.0
var phase: float = 0.0

func setup(data: Dictionary) -> void:
	item = data.duplicate(true)
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	add_to_group("loot")
	body_entered.connect(_on_body_entered)
	_build_visual()

func _ready() -> void:
	base_y = position.y
	phase = randf() * TAU

func _build_visual() -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sp: SphereShape3D = SphereShape3D.new()
	sp.radius = 1.1
	cs.shape = sp
	cs.position = Vector3(0.0, 0.0, 0.0)
	add_child(cs)

	var kind: String = String(item.get("kind", "weapon"))
	var color: Color = item.get("rarity_color", Color("7fd8ff"))
	if not (color is Color):
		color = Color("7fd8ff")
	var size: Vector3 = Vector3(0.9, 0.26, 0.42)
	match kind:
		"ammo":
			size = Vector3(0.42, 0.30, 0.30)
			color = Color("e6c65c")
		"consumable":
			size = Vector3(0.34, 0.44, 0.34)
			color = item.get("color", Color("6fd0e6"))
		"resource":
			size = Vector3(0.5, 0.4, 0.5)
			color = Color("b98a52")

	visual = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	visual.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.7
	mat.roughness = 0.4
	visual.material_override = mat
	add_child(visual)

	var beam: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 3.0
	cyl.radial_segments = 6
	beam.mesh = cyl
	beam.material_override = MatLib.alpha(Color(color.r, color.g, color.b, 0.16), 0.5, true)
	beam.position = Vector3(0.0, 1.4, 0.0)
	add_child(beam)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.7
	light.omni_range = 2.4
	add_child(light)

func _process(delta: float) -> void:
	phase += delta * 2.2
	rotation.y += delta * 0.9
	position.y = base_y + sin(phase) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_loot"):
		return
	if bool(body.call("collect_loot", item)):
		queue_free()
