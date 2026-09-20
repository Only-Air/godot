class_name MapBuilder
extends Node3D

## Assembles the island: themed points of interest with enterable buildings,
## roads, scattered filler structures, foliage, harvestables and loot.

const PALETTES: Dictionary = {
	"city": {
		"wall": null, "trim": null, "roof": null, "floor": null,
		"wall_c": Color("d3cbb8"), "trim_c": Color("7d7364"), "roof_c": Color("8a4a3c"), "floor_c": Color("6d6152"),
	},
	"industry": {
		"wall": null, "trim": null, "roof": null, "floor": null,
		"wall_c": Color("9aa3ad"), "trim_c": Color("59616b"), "roof_c": Color("5f6873"), "floor_c": Color("4d545c"),
	},
	"farm": {
		"wall": null, "trim": null, "roof": null, "floor": null,
		"wall_c": Color("c9b391"), "trim_c": Color("7a6446"), "roof_c": Color("8f5a3c"), "floor_c": Color("6f5c44"),
	},
	"resort": {
		"wall": null, "trim": null, "roof": null, "floor": null,
		"wall_c": Color("e2d3bd"), "trim_c": Color("a3785c"), "roof_c": Color("c2705a"), "floor_c": Color("8a7156"),
	},
	"science": {
		"wall": null, "trim": null, "roof": null, "floor": null,
		"wall_c": Color("c3cdd2"), "trim_c": Color("5f7b86"), "roof_c": Color("4f7a86"), "floor_c": Color("5c6a70"),
	},
}

static func poi_definitions() -> Array:
	return [
		{"name": "曙光中枢", "x": 0.0, "z": 0.0, "radius": 30.0, "blend": 20.0, "tier": 3, "kind": "city", "count": 9},
		{"name": "岬角通信站", "x": -94.0, "z": -86.0, "radius": 22.0, "blend": 18.0, "tier": 2, "kind": "science", "count": 5},
		{"name": "苍穹能源站", "x": 90.0, "z": -90.0, "radius": 24.0, "blend": 18.0, "tier": 2, "kind": "industry", "count": 6},
		{"name": "苇影研究园", "x": -92.0, "z": 78.0, "radius": 22.0, "blend": 18.0, "tier": 2, "kind": "science", "count": 5},
		{"name": "晴湾度假区", "x": 94.0, "z": 84.0, "radius": 26.0, "blend": 18.0, "tier": 2, "kind": "resort", "count": 7},
		{"name": "北境农场", "x": -16.0, "z": -120.0, "radius": 22.0, "blend": 18.0, "tier": 1, "kind": "farm", "count": 5},
		{"name": "赤潮工业港", "x": 12.0, "z": 122.0, "radius": 26.0, "blend": 18.0, "tier": 1, "kind": "industry", "count": 7},
		{"name": "松风镇", "x": -64.0, "z": 8.0, "radius": 20.0, "blend": 16.0, "tier": 1, "kind": "city", "count": 6},
		{"name": "镜湖社区", "x": 66.0, "z": -6.0, "radius": 20.0, "blend": 16.0, "tier": 1, "kind": "resort", "count": 6},
		{"name": "望海灯塔", "x": -124.0, "z": 44.0, "radius": 14.0, "blend": 14.0, "tier": 2, "kind": "science", "count": 3},
	]
	# Note: x/z here are original placement choices for this island layout.

static func road_list() -> Array:
	var pois: Array = poi_definitions()
	var roads: Array = []
	for i: int in pois.size():
		var p: Dictionary = pois[i]
		if i == 0:
			continue
		roads.append({"a": Vector2(0.0, 0.0), "b": Vector2(float(p["x"]), float(p["z"])), "width": 7.0})
	roads.append({"a": Vector2(-64.0, 8.0), "b": Vector2(-16.0, -120.0), "width": 6.0})
	roads.append({"a": Vector2(66.0, -6.0), "b": Vector2(90.0, -90.0), "width": 6.0})
	roads.append({"a": Vector2(12.0, 122.0), "b": Vector2(94.0, 84.0), "width": 6.0})
	roads.append({"a": Vector2(-94.0, -86.0), "b": Vector2(-16.0, -120.0), "width": 6.0})
	roads.append({"a": Vector2(-92.0, 78.0), "b": Vector2(12.0, 122.0), "width": 6.0})
	return roads

var terrain: Terrain
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var pois: Array = []
var container_count: int = 0
var loot_count: int = 0

func build(p_terrain: Terrain, p_seed: int) -> void:
	terrain = p_terrain
	rng.seed = p_seed
	pois = poi_definitions()
	_build_water()
	for poi in pois:
		_build_poi(poi)
	_build_filler()
	_build_scatter()

func _ground(x: float, z: float) -> float:
	if terrain == null:
		return 0.0
	return terrain.height_at(x, z)

func _palette(kind: String) -> Dictionary:
	var src: Dictionary = PALETTES.get(kind, PALETTES["city"])
	return {
		"wall": MatLib.flat(src["wall_c"], 0.0, 0.88),
		"trim": MatLib.flat(src["trim_c"], 0.0, 0.8),
		"roof": MatLib.flat(src["roof_c"], 0.0, 0.82),
		"floor": MatLib.flat(src["floor_c"], 0.0, 0.9),
	}

func _build_water() -> void:
	var water: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(1200.0, 1200.0)
	water.mesh = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.42, 0.62, 0.80)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	mat.metallic = 0.35
	water.material_override = mat
	water.position = Vector3(0.0, 0.25, 0.0)
	add_child(water)

func _build_poi(poi: Dictionary) -> void:
	var cx: float = float(poi["x"])
	var cz: float = float(poi["z"])
	var radius: float = float(poi["radius"])
	var kind: String = String(poi["kind"])
	var count: int = int(poi["count"])
	var tier: int = int(poi["tier"])
	var palette: Dictionary = _palette(kind)
	var node: Node3D = Node3D.new()
	node.name = "POI_" + String(poi["name"])
	add_child(node)

	var slots: Array = _layout_slots(cx, cz, radius, count)
	for i: int in slots.size():
		var s: Vector2 = slots[i]
		var gx: float = s.x
		var gz: float = s.y
		var gy: float = _ground(gx, gz)
		var yaw: float = rng.randf_range(-PI, PI)
		match kind:
			"industry":
				if i % 3 == 0:
					BuildingKit.warehouse(node, Vector3(gx, gy, gz), yaw, rng.randf_range(14.0, 20.0), rng.randf_range(12.0, 18.0), rng.randf_range(5.5, 7.5), palette)
				else:
					BuildingKit.house(node, Vector3(gx, gy, gz), yaw, rng.randf_range(8.0, 12.0), rng.randf_range(8.0, 11.0), rng.randi_range(1, 2), palette)
				if rng.randf() < 0.6:
					BuildingKit.container(node, Vector3(gx + rng.randf_range(-6, 6), gy, gz + rng.randf_range(-6, 6)), rng.randf_range(-PI, PI),
						[Color("c05a3c"), Color("3f7fa8"), Color("c9a13c"), Color("5a8f5c")][rng.randi() % 4])
			"farm":
				BuildingKit.house(node, Vector3(gx, gy, gz), yaw, rng.randf_range(9.0, 14.0), rng.randf_range(7.0, 10.0), 1, palette)
				if rng.randf() < 0.7:
					BuildingKit.barrier(node, Vector3(gx + rng.randf_range(-8, 8), gy, gz + rng.randf_range(-8, 8)), yaw + PI * 0.5, rng.randf_range(8.0, 16.0), palette)
			"resort":
				BuildingKit.house(node, Vector3(gx, gy, gz), yaw, rng.randf_range(8.0, 13.0), rng.randf_range(8.0, 12.0), rng.randi_range(1, 2), palette)
			"science":
				if i == 0:
					BuildingKit.tower(node, Vector3(gx, gy, gz), yaw, rng.randf_range(7.0, 9.0), rng.randi_range(3, 4), palette)
				elif i == 1:
					BuildingKit.watchtower(node, Vector3(gx, gy, gz), yaw, palette)
				else:
					BuildingKit.house(node, Vector3(gx, gy, gz), yaw, rng.randf_range(8.0, 12.0), rng.randf_range(8.0, 11.0), rng.randi_range(1, 2), palette)
			_:
				if i % 4 == 0:
					BuildingKit.tower(node, Vector3(gx, gy, gz), yaw, rng.randf_range(7.0, 10.0), rng.randi_range(2, 4), palette)
				else:
					BuildingKit.house(node, Vector3(gx, gy, gz), yaw, rng.randf_range(8.0, 13.0), rng.randf_range(8.0, 12.0), rng.randi_range(1, 2), palette)
		_spawn_container_cluster(node, Vector3(gx, gy, gz), tier)

	if kind == "science":
		BuildingKit.watchtower(node, Vector3(cx + radius * 0.7, _ground(cx + radius * 0.7, cz - radius * 0.7), cz - radius * 0.7), 0.0, palette)
	if tier >= 3:
		BuildingKit.warehouse(node, Vector3(cx + radius * 0.55, _ground(cx + radius * 0.55, cz + radius * 0.5), cz + radius * 0.5), PI * 0.25, 22.0, 16.0, 8.0, palette)
		BuildingKit.watchtower(node, Vector3(cx - radius * 0.7, _ground(cx - radius * 0.7, cz - radius * 0.6), cz - radius * 0.6), 0.0, palette)

	for i: int in int(radius * 0.9):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(radius * 0.3, radius * 1.25)
		var lx: float = cx + cos(a) * r
		var lz: float = cz + sin(a) * r
		_spawn_floor_loot(Vector3(lx, _ground(lx, lz), lz), tier)

func _layout_slots(cx: float, cz: float, radius: float, count: int) -> Array:
	var slots: Array = []
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = (radius * 1.5) / maxf(float(cols), 1.0)
	var start: float = -spacing * float(cols - 1) * 0.5
	for i: int in count:
		var row: int = i / cols
		var col: int = i % cols
		var jx: float = rng.randf_range(-2.5, 2.5)
		var jz: float = rng.randf_range(-2.5, 2.5)
		slots.append(Vector2(cx + start + float(col) * spacing + jx, cz + start + float(row) * spacing + jz))
	return slots

func _spawn_container_cluster(parent: Node3D, around: Vector3, tier: int) -> void:
	var n: int = 1 + tier
	for i: int in n:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(2.0, 9.0)
		var x: float = around.x + cos(a) * r
		var z: float = around.z + sin(a) * r
		_spawn_container(parent, Vector3(x, _ground(x, z), z), mini(tier, 2))

func _spawn_container(parent: Node3D, pos: Vector3, tier: int) -> void:
	var c: LootContainer = LootContainer.new()
	parent.add_child(c)
	c.global_position = pos + Vector3.UP * 0.1
	c.rotation.y = rng.randf_range(-PI, PI)
	c.setup(tier)
	container_count += 1

func _spawn_floor_loot(pos: Vector3, tier: int) -> void:
	if rng.randf() > 0.55:
		return
	var roll: float = rng.randf()
	var data: Dictionary = {}
	if roll < 0.42:
		var w: Dictionary = WeaponDB.random_weapon(mini(1 + tier, 5))
		w["kind"] = "weapon"
		data = w
	elif roll < 0.68:
		var ammo_type: String = ["light", "medium", "shells", "heavy"][rng.randi() % 4]
		data = {"kind": "ammo", "ammo": ammo_type, "amount": rng.randi_range(12, 36)}
	elif roll < 0.9:
		var ids: Array = WeaponDB.CONSUMABLES.keys()
		data = {"kind": "consumable", "id": String(ids[rng.randi() % ids.size()]), "amount": 1}
	else:
		data = {"kind": "resource", "resource": ["wood", "stone", "metal"][rng.randi() % 3], "amount": rng.randi_range(30, 80)}
	var p: LootPickup = LootPickup.new()
	add_child(p)
	p.global_position = pos + Vector3.UP * 0.7
	p.setup(data)
	loot_count += 1

func _build_filler() -> void:
	var palette: Dictionary = _palette("city")
	for i: int in 26:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(26.0, 122.0)
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		if _near_poi(x, z, 12.0):
			continue
		var gy: float = _ground(x, z)
		if gy < 1.6:
			continue
		BuildingKit.house(self, Vector3(x, gy, z), rng.randf_range(-PI, PI), rng.randf_range(7.0, 11.0), rng.randf_range(7.0, 10.0), 1, palette, rng.randf() < 0.6)
		_spawn_container_cluster(self, Vector3(x, gy, z), 0)

func _near_poi(x: float, z: float, margin: float) -> bool:
	for poi in pois:
		var p: Dictionary = poi
		var d: float = Vector2(x - float(p["x"]), z - float(p["z"])).length()
		if d < float(p["radius"]) + margin:
			return true
	return false

func _build_scatter() -> void:
	for i: int in 260:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(10.0, 148.0)
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		var gy: float = _ground(x, z)
		if gy < 1.5:
			continue
		if _near_poi(x, z, 2.0) and rng.randf() < 0.7:
			continue
		var slope: float = terrain.slope_at(x, z) if terrain != null else 0.0
		if slope > 0.45:
			continue
		if rng.randf() < 0.78:
			BuildingKit.tree(self, Vector3(x, gy, z), rng.randf_range(0.75, 1.5))
		else:
			BuildingKit.rock(self, Vector3(x, gy, z), rng.randf_range(0.7, 1.5))
	for i: int in 90:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(8.0, 145.0)
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		var gy: float = _ground(x, z)
		if gy < 1.5:
			continue
		_spawn_harvestable(Vector3(x, gy, z))

func _spawn_harvestable(pos: Vector3) -> void:
	var roll: float = rng.randf()
	var type: String = "wood"
	if roll < 0.5:
		type = "wood"
	elif roll < 0.82:
		type = "stone"
	else:
		type = "metal"
	var h: HarvestProp = HarvestProp.new()
	add_child(h)
	h.global_position = pos
	var size: Vector3 = Vector3(1.5, 4.5, 1.5)
	if type == "stone":
		size = Vector3(2.6, 1.8, 2.6)
	elif type == "metal":
		size = Vector3(2.0, 2.6, 2.0)
	h.setup(type, size)
