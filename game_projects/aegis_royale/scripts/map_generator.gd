class_name IslandMapGenerator
extends Node3D

const ISLAND_RADIUS := 112.0

var poi_data := [
	{"name":"曙光中枢", "position":Vector3(0, 0, 0), "color":Color("d7b34b"), "buildings":9, "tier":2},
	{"name":"岬角通信站", "position":Vector3(-72, 0, -62), "color":Color("5d8fb7"), "buildings":6, "tier":1},
	{"name":"苍穹能源站", "position":Vector3(68, 0, -66), "color":Color("7988bd"), "buildings":7, "tier":1},
	{"name":"苇影研究园", "position":Vector3(-70, 0, 58), "color":Color("679a6e"), "buildings":7, "tier":1},
	{"name":"晴湾度假区", "position":Vector3(69, 0, 62), "color":Color("d69370"), "buildings":8, "tier":1},
	{"name":"北境农场", "position":Vector3(0, 0, -78), "color":Color("b99b5b"), "buildings":6, "tier":0},
	{"name":"赤潮工业港", "position":Vector3(0, 0, 82), "color":Color("687b82"), "buildings":8, "tier":0},
	{"name":"松风镇", "position":Vector3(-48, 0, 8), "color":Color("b77969"), "buildings":7, "tier":0},
	{"name":"镜湖社区", "position":Vector3(50, 0, -5), "color":Color("8d78a8"), "buildings":7, "tier":0}
]

var poi_positions: Array[Vector3] = []

func generate() -> void:
	_create_island_base()
	_create_water_network()
	_create_roads_and_bridges()
	for poi in poi_data:
		_create_poi(poi)
	_scatter_resources()
	_scatter_floor_loot()

func _create_island_base() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 2
	add_child(ground)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = ISLAND_RADIUS
	cylinder.bottom_radius = ISLAND_RADIUS + 6.0
	cylinder.height = 3.0
	cylinder.radial_segments = 96
	mesh.mesh = cylinder
	mesh.position.y = -1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4e8b55")
	mat.roughness = 1.0
	mesh.material_override = mat
	ground.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = ISLAND_RADIUS
	shape.height = 3.0
	collider.shape = shape
	collider.position.y = -1.5
	ground.add_child(collider)

func _create_water_network() -> void:
	_create_water_patch(Vector3(0, 0.07, 0), Vector3(26, 0.12, 26))
	_create_water_patch(Vector3(0, 0.08, -54), Vector3(9, 0.12, 82))
	_create_water_patch(Vector3(0, 0.08, 57), Vector3(11, 0.12, 84))
	_create_water_patch(Vector3(-57, 0.08, 0), Vector3(86, 0.12, 9))
	_create_water_patch(Vector3(58, 0.08, 0), Vector3(86, 0.12, 10))

func _create_water_patch(pos: Vector3, size: Vector3) -> void:
	var water := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	water.mesh = box
	water.position = pos
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.13, 0.48, 0.72, 0.78)
	mat.metallic = 0.12
	mat.roughness = 0.22
	water.material_override = mat
	add_child(water)

func _create_roads_and_bridges() -> void:
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var road := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(7.0, 0.08, 92.0)
		road.mesh = box
		road.position = Vector3(sin(angle) * 52.0, 0.14, cos(angle) * 52.0)
		road.rotation.y = angle
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("55585c")
		mat.roughness = 1.0
		road.material_override = mat
		add_child(road)
	for bridge_pos in [Vector3(0, 0.45, -22), Vector3(0, 0.45, 22), Vector3(-22, 0.45, 0), Vector3(22, 0.45, 0)]:
		var bridge := HarvestProp.new()
		bridge.position = bridge_pos
		add_child(bridge)
		var along_x := absf(bridge_pos.x) > 0.0
		bridge.setup("metal", Vector3(15.0, 0.7, 6.0) if along_x else Vector3(6.0, 0.7, 15.0), Color("667681"))

func _create_poi(data: Dictionary) -> void:
	var center: Vector3 = data.position
	poi_positions.append(center)
	var marker := Node3D.new()
	marker.name = data.name
	marker.position = center
	marker.add_to_group("poi_markers")
	marker.set_meta("poi_name", data.name)
	marker.set_meta("loot_tier", data.tier)
	add_child(marker)
	for i in int(data.buildings):
		var angle := TAU * float(i) / float(data.buildings) + randf_range(-0.18, 0.18)
		var radius := 7.0 + (i % 3) * 4.5
		var pos := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if Vector2(pos.x, pos.z).length() > ISLAND_RADIUS - 6.0: continue
		var building := HarvestProp.new()
		building.position = pos
		building.rotation.y = angle + PI * 0.5
		add_child(building)
		var size := Vector3(randf_range(5.0, 9.5), randf_range(3.0, 8.0), randf_range(5.0, 9.0))
		building.setup("stone" if i % 3 else "metal", size, data.color)
		_create_container(pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), int(data.tier) > 0 and i % 3 == 0)
	for i in 3 + int(data.tier):
		_spawn_weapon(center + Vector3(randf_range(-13, 13), 0.7, randf_range(-13, 13)), mini(2 + int(data.tier), 4))

func _scatter_resources() -> void:
	for i in 78:
		var angle := randf() * TAU
		var radius := sqrt(randf()) * (ISLAND_RADIUS - 7.0)
		var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var prop := HarvestProp.new()
		prop.position = pos
		add_child(prop)
		if i % 3 == 0:
			prop.setup("wood", Vector3(1.1, randf_range(4.0, 7.2), 1.1), Color("4b713f"))
		elif i % 3 == 1:
			prop.setup("stone", Vector3(randf_range(1.6, 3.4), randf_range(1.1, 2.8), randf_range(1.6, 3.4)), Color("777e83"))
		else:
			prop.setup("metal", Vector3(randf_range(2.0, 4.4), randf_range(1.0, 2.2), randf_range(1.5, 3.0)), Color("587180"))

func _scatter_floor_loot() -> void:
	for i in 38:
		var angle := randf() * TAU
		var radius := sqrt(randf()) * (ISLAND_RADIUS - 8.0)
		_spawn_weapon(Vector3(cos(angle) * radius, 0.7, sin(angle) * radius), 2)

func _create_container(pos: Vector3, high_tier: bool) -> void:
	var container := LootContainer.new()
	container.position = pos
	add_child(container)
	container.setup(1 if high_tier else 0)

func _spawn_weapon(pos: Vector3, max_rarity: int) -> void:
	var pickup := LootPickup.new()
	pickup.position = pos
	add_child(pickup)
	var item := ItemDatabase.random_weapon(max_rarity)
	item.kind = "weapon"
	pickup.setup(item)

func nearest_poi(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := INF
	for pos in poi_positions:
		var distance := from.distance_squared_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = pos
	return best
