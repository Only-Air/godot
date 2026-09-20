class_name BuildPiece
extends StaticBody3D

## A single grid structure. Walls and floors are made of a real 3x3 tile grid so
## they can be edited tile by tile (window, door, half wall, corner, holes).

const CELL: float = 4.0
const LEVEL: float = 3.0
const THICK: float = 0.20
const TILE_W: float = CELL / 3.0
const TILE_H: float = 1.0

const MAT_HEALTH: Dictionary = {"wood": 150.0, "stone": 300.0, "metal": 500.0}
const MAT_BUILD_TIME: Dictionary = {"wood": 0.10, "stone": 0.20, "metal": 0.32}
const MAT_COLOR: Dictionary = {
	"wood": Color("bb8a52"), "stone": Color("8f969f"), "metal": Color("6f849a"),
}

## 1 = solid, 0 = open. Index = row * 3 + col, row 0 is the top row.
const FULL: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1, 1]
const PRESETS: Dictionary = {
	"full": [1, 1, 1, 1, 1, 1, 1, 1, 1],
	"window": [1, 1, 1, 1, 0, 1, 1, 1, 1],
	"door": [1, 1, 1, 1, 1, 1, 1, 0, 1],
	"arch": [1, 1, 1, 1, 0, 1, 1, 0, 1],
	"half": [0, 0, 0, 1, 1, 1, 1, 1, 1],
	"low": [0, 0, 0, 0, 0, 0, 1, 1, 1],
	"left_door": [1, 1, 1, 1, 1, 1, 0, 1, 1],
	"right_door": [1, 1, 1, 1, 1, 1, 1, 1, 0],
	"pillar": [1, 0, 1, 0, 0, 0, 1, 0, 1],
	"stair": [1, 1, 1, 1, 1, 0, 1, 0, 0],
}

var piece_type: String = "wall"
var mat_type: String = "wood"
var tiles: Array[int] = []
var health: float = 150.0
var max_health: float = 150.0
var owner_id: int = 0
var cell_key: String = ""
var ghost: bool = false
var built_time: float = 0.0
var build_duration: float = 0.1

var visual_root: Node3D
var collision_root: Node3D
var tint_material: StandardMaterial3D
var tint_color: Color = Color.WHITE
var use_tint: bool = false
var destroyed: bool = false

func setup(p_type: String, p_mat: String, p_owner: int, p_key: String, p_tiles: Array = []) -> void:
	piece_type = p_type
	mat_type = p_mat
	owner_id = p_owner
	cell_key = p_key
	tiles = _coerce_tiles(p_tiles)
	max_health = float(MAT_HEALTH.get(mat_type, 150.0))
	health = max_health
	build_duration = float(MAT_BUILD_TIME.get(mat_type, 0.1))
	if not ghost:
		add_to_group("build_pieces")
	collision_layer = 0 if ghost else 4
	collision_mask = 0 if ghost else 3
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	collision_root = Node3D.new()
	collision_root.name = "Collision"
	add_child(collision_root)
	rebuild()
	if ghost:
		health = max_health

func _coerce_tiles(source: Array) -> Array[int]:
	var out: Array[int] = []
	if source.size() == 9:
		for v in source:
			out.append(int(v))
	else:
		out = FULL.duplicate()
	return out

func rebuild() -> void:
	if visual_root == null:
		return
	for c in visual_root.get_children():
		c.queue_free()
	for c in collision_root.get_children():
		c.queue_free()
	match piece_type:
		"wall": _build_wall()
		"floor": _build_floor()
		"ramp": _build_ramp()
		"cone": _build_cone()
		_: _build_wall()

func apply_preset(preset: String) -> void:
	tiles = _coerce_tiles(PRESETS.get(preset, FULL))
	rebuild()

func toggle_tile(index: int) -> void:
	if index < 0 or index >= 9:
		return
	tiles[index] = 0 if tiles[index] == 1 else 1
	rebuild()

func is_edited() -> bool:
	for v in tiles:
		if v == 0:
			return true
	return false

func set_tint(color: Color) -> void:
	use_tint = true
	tint_color = color
	tint_material = MatLib.alpha(color, 0.4, true)
	for c in visual_root.get_children():
		if c is MeshInstance3D:
			c.material_override = tint_material
	for c in collision_root.get_children():
		c.queue_free()

func _solid_material() -> StandardMaterial3D:
	var base: Color = MAT_COLOR.get(mat_type, Color("bb8a52"))
	if mat_type == "metal":
		return MatLib.metal(base)
	return MatLib.flat(base, 0.0, 0.9)

func _edge_material() -> StandardMaterial3D:
	var base: Color = MAT_COLOR.get(mat_type, Color("bb8a52"))
	return MatLib.flat(base.darkened(0.38), 0.0, 0.95)

func _build_wall() -> void:
	var solid: StandardMaterial3D = _solid_material()
	var edge: StandardMaterial3D = _edge_material()
	for row: int in 3:
		for col: int in 3:
			var idx: int = row * 3 + col
			if tiles[idx] == 0:
				continue
			var lx: float = (float(col) - 1.0) * TILE_W
			var ly: float = (1.0 - float(row)) * TILE_H + TILE_H * 0.5
			var inset: float = 0.012
			_add_box(Vector3(TILE_W - inset, TILE_H - inset, THICK), Vector3(lx, ly, 0.0), solid, true)
			if col < 2 and tiles[row * 3 + col + 1] == 1:
				_add_box(Vector3(0.03, TILE_H - inset, THICK + 0.01), Vector3(lx + TILE_W * 0.5, ly, 0.0), edge, false)
			if row < 2 and tiles[(row + 1) * 3 + col] == 1:
				_add_box(Vector3(TILE_W - inset, 0.03, THICK + 0.01), Vector3(lx, ly - TILE_H * 0.5, 0.0), edge, false)

func _build_floor() -> void:
	var solid: StandardMaterial3D = _solid_material()
	var edge: StandardMaterial3D = _edge_material()
	for row: int in 3:
		for col: int in 3:
			var idx: int = row * 3 + col
			if tiles[idx] == 0:
				continue
			var lx: float = (float(col) - 1.0) * TILE_W
			var lz: float = (float(row) - 1.0) * TILE_W
			_add_box(Vector3(TILE_W - 0.012, THICK, TILE_W - 0.012), Vector3(lx, 0.0, lz), solid, true)
			if col < 2 and tiles[row * 3 + col + 1] == 1:
				_add_box(Vector3(0.03, THICK + 0.01, TILE_W - 0.012), Vector3(lx + TILE_W * 0.5, 0.0, lz), edge, false)
			if row < 2 and tiles[(row + 1) * 3 + col] == 1:
				_add_box(Vector3(TILE_W - 0.012, THICK + 0.01, 0.03), Vector3(lx, 0.0, lz + TILE_W * 0.5), edge, false)

func _build_ramp() -> void:
	var solid: StandardMaterial3D = _solid_material()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(CELL - 0.06, LEVEL - 0.10, CELL - 0.06)
	prism.left_to_right = 1.0
	var vis: MeshInstance3D = MeshInstance3D.new()
	vis.mesh = prism
	vis.material_override = solid
	vis.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	vis.position = Vector3(0.0, (LEVEL - 0.10) * 0.5 + 0.05, 0.0)
	visual_root.add_child(vis)
	if not ghost:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = prism.create_convex_shape()
		cs.rotation = vis.rotation
		cs.position = vis.position
		collision_root.add_child(cs)

func _build_cone() -> void:
	var solid: StandardMaterial3D = _solid_material()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = CELL * 0.72
	mesh.height = LEVEL * 0.92
	mesh.radial_segments = 4
	mesh.rings = 1
	var vis: MeshInstance3D = MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = solid
	vis.rotation = Vector3(0.0, PI * 0.25, 0.0)
	vis.position = Vector3(0.0, LEVEL * 0.46, 0.0)
	visual_root.add_child(vis)
	if not ghost:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = mesh.create_convex_shape()
		cs.rotation = vis.rotation
		cs.position = vis.position
		collision_root.add_child(cs)

func _add_box(size: Vector3, pos: Vector3, mat: StandardMaterial3D, with_collision: bool) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	visual_root.add_child(mi)
	if with_collision and not ghost:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		collision_root.add_child(cs)

func apply_damage(amount: float, source: Node = null) -> void:
	if ghost or destroyed:
		return
	health -= amount
	_flash_hit()
	if health <= 0.0:
		destroyed = true
		var world: Node3D = get_parent() as Node3D
		if world != null:
			Effects.debris_burst(world, global_position + Vector3.UP * 1.2, MAT_COLOR.get(mat_type, Color.WHITE), 9)
			Effects.smoke_puff(world, global_position + Vector3.UP * 1.0, Color(0.8, 0.8, 0.8), 1.4)
		if source != null and source.has_method("receive_resource"):
			source.receive_resource(mat_type, 4)
		queue_free()

func _flash_hit() -> void:
	if visual_root == null:
		return
	for c in visual_root.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			mi.modulate = Color(1.8, 1.4, 1.4)
	var tw: Tween = create_tween()
	tw.tween_method(_set_modulate, Color(1.8, 1.4, 1.4), Color.WHITE, 0.18)

func _set_modulate(c: Color) -> void:
	if visual_root == null:
		return
	for ch in visual_root.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).modulate = c

func health_ratio() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)

func tile_index_from_local(local: Vector3) -> int:
	var col: int = clampi(int(floor((local.x + CELL * 0.5) / TILE_W)), 0, 2)
	var row: int = clampi(int(floor((LEVEL - local.y) / TILE_H)), 0, 2)
	return row * 3 + col

func local_from_tile(index: int) -> Vector3:
	var row: int = index / 3
	var col: int = index % 3
	return Vector3(
		(float(col) - 1.0) * TILE_W,
		(1.0 - float(row)) * TILE_H + TILE_H * 0.5,
		0.0
	)
