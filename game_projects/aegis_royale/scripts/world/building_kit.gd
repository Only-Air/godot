class_name BuildingKit
extends RefCounted

## Static helpers that assemble readable, enterable buildings out of boxes:
## walls with real door and window openings, floors, staircases and roofs.

static func house(parent: Node3D, origin: Vector3, yaw: float, width: float, depth: float,
		floors: int, palette: Dictionary, with_roof: bool = true) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw)
	var wall_mat: StandardMaterial3D = palette.get("wall", MatLib.flat(Color("cfc4ae")))
	var trim_mat: StandardMaterial3D = palette.get("trim", MatLib.flat(Color("8d8272")))
	var roof_mat: StandardMaterial3D = palette.get("roof", MatLib.flat(Color("8c4b3c")))
	var floor_mat: StandardMaterial3D = palette.get("floor", MatLib.flat(Color("6f6252")))
	var glass_mat: StandardMaterial3D = MatLib.alpha(Color(0.55, 0.78, 0.88, 0.42), 0.1, false)

	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_position = origin
	body.global_transform = Transform3D(basis, origin)
	body.collision_layer = 1
	body.collision_mask = 2 | 4

	var hw: float = width * 0.5
	var hd: float = depth * 0.5
	var fh: float = 3.2
	var door_w: float = 1.5
	var door_h: float = 2.3

	for f: int in floors:
		var y: float = float(f) * fh
		_slab(body, Vector3(0.0, y - 0.15, 0.0), Vector3(width, 0.3, depth), floor_mat)
		if f > 0:
			_stairs(body, Vector3(-hw + 1.2, y - fh, 0.0), fh, fh, trim_mat)
		var door_side: int = 2 if f == 0 else 0
		_wall(body, Vector3(-hw, y, -hd), Vector3(hw, y, -hd), fh, wall_mat, trim_mat, glass_mat,
			door_w if door_side == 0 else -1.0, door_h, true)
		_wall(body, Vector3(hw, y, -hd), Vector3(hw, y, hd), fh, wall_mat, trim_mat, glass_mat,
			door_w if door_side == 1 else -1.0, door_h, true)
		_wall(body, Vector3(hw, y, hd), Vector3(-hw, y, hd), fh, wall_mat, trim_mat, glass_mat,
			door_w if door_side == 2 else -1.0, door_h, true)
		_wall(body, Vector3(-hw, y, hd), Vector3(-hw, y, -hd), fh, wall_mat, trim_mat, glass_mat,
			door_w if door_side == 3 else -1.0, door_h, true)

	if with_roof:
		var top: float = float(floors) * fh
		_slab(body, Vector3(0.0, top, 0.0), Vector3(width + 0.5, 0.3, depth + 0.5), roof_mat)
		_slab(body, Vector3(0.0, top + 0.35, 0.0), Vector3(width * 0.55, 0.5, depth * 0.55), roof_mat)
	else:
		_parapet(body, Vector3.ZERO, width, depth, float(floors) * fh, trim_mat)

static func warehouse(parent: Node3D, origin: Vector3, yaw: float, width: float, depth: float,
		height: float, palette: Dictionary) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw)
	var wall_mat: StandardMaterial3D = palette.get("wall", MatLib.flat(Color("9aa3ad")))
	var trim_mat: StandardMaterial3D = palette.get("trim", MatLib.flat(Color("5f6873")))
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_transform = Transform3D(basis, origin)
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var hw: float = width * 0.5
	var hd: float = depth * 0.5
	_slab(body, Vector3(0.0, -0.15, 0.0), Vector3(width, 0.3, depth), trim_mat)
	_wall(body, Vector3(-hw, 0.0, -hd), Vector3(hw, 0.0, -hd), height, wall_mat, trim_mat, null, width * 0.45, height * 0.72, false)
	_wall(body, Vector3(hw, 0.0, -hd), Vector3(hw, 0.0, hd), height, wall_mat, trim_mat, null, -1.0, 0.0, false)
	_wall(body, Vector3(hw, 0.0, hd), Vector3(-hw, 0.0, hd), height, wall_mat, trim_mat, null, -1.0, 0.0, false)
	_wall(body, Vector3(-hw, 0.0, hd), Vector3(-hw, 0.0, -hd), height, wall_mat, trim_mat, null, -1.0, 0.0, false)
	_slab(body, Vector3(0.0, height, 0.0), Vector3(width + 0.6, 0.35, depth + 0.6), trim_mat)
	for i: int in 3:
		_slab(body, Vector3(0.0, height + 0.6 + float(i) * 0.55, 0.0), Vector3(width + 0.6 - float(i) * 1.6, 0.4, depth + 0.6 - float(i) * 1.6), trim_mat)
	for i: int in 3:
		_slab(body, Vector3(-hw + 2.0 + float(i) * (width - 4.0) * 0.5, height * 0.5, 0.0), Vector3(2.2, 0.28, depth - 2.0), trim_mat)

static func tower(parent: Node3D, origin: Vector3, yaw: float, size: float, floors: int,
		palette: Dictionary) -> void:
	var wall_mat: StandardMaterial3D = palette.get("wall", MatLib.flat(Color("b7b0a2")))
	var trim_mat: StandardMaterial3D = palette.get("trim", MatLib.flat(Color("6b6459")))
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var hw: float = size * 0.5
	var fh: float = 3.0
	for f: int in floors:
		var y: float = float(f) * fh
		_slab(body, Vector3(0.0, y - 0.2, 0.0), Vector3(size, 0.35, size), trim_mat)
		var door: float = 1.3 if f == 0 else -1.0
		_wall(body, Vector3(-hw, y, -hw), Vector3(hw, y, -hw), fh, wall_mat, trim_mat, null, door, 2.2, false)
		_wall(body, Vector3(hw, y, -hw), Vector3(hw, y, hw), fh, wall_mat, trim_mat, null, -1.0, 0.0, true)
		_wall(body, Vector3(hw, y, hw), Vector3(-hw, y, hw), fh, wall_mat, trim_mat, null, -1.0, 0.0, true)
		_wall(body, Vector3(-hw, y, hw), Vector3(-hw, y, -hw), fh, wall_mat, trim_mat, null, -1.0, 0.0, false)
		if f < floors - 1:
			_stairs(body, Vector3(-hw + 0.9, y, hw - 1.6), fh, size - 2.6, trim_mat)
	_slab(body, Vector3(0.0, float(floors) * fh, 0.0), Vector3(size + 0.4, 0.3, size + 0.4), trim_mat)

static func container(parent: Node3D, origin: Vector3, yaw: float, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	_box(body, Vector3(6.0, 2.6, 2.5), Vector3(0.0, 1.3, 0.0), MatLib.metal(color))
	for i: int in 5:
		var x: float = -2.6 + float(i) * 1.3
		_box(body, Vector3(0.1, 2.5, 2.55), Vector3(x, 1.3, 0.0), MatLib.metal(color.darkened(0.35)))

static func tree(parent: Node3D, origin: Vector3, scale_factor: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_position = origin
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var trunk_h: float = 3.4 * scale_factor
	_box(body, Vector3(0.55 * scale_factor, trunk_h, 0.55 * scale_factor), Vector3(0.0, trunk_h * 0.5, 0.0),
		MatLib.flat(Color("6b4a30"), 0.0, 0.95))
	var leaf_mat: StandardMaterial3D = MatLib.foliage(Color("3f7a3c").lightened(randf_range(-0.06, 0.08)))
	var layers: int = 3
	for i: int in layers:
		var r: float = (2.6 - float(i) * 0.6) * scale_factor
		var y: float = trunk_h + 0.6 + float(i) * 1.5 * scale_factor
		var cone: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = r * 0.15
		cm.bottom_radius = r
		cm.height = 2.4 * scale_factor
		cm.radial_segments = 7
		cone.mesh = cm
		cone.material_override = leaf_mat
		cone.position = Vector3(0.0, y, 0.0)
		body.add_child(cone)

static func rock(parent: Node3D, origin: Vector3, scale_factor: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_position = origin
	body.rotation.y = randf() * TAU
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var s: float = scale_factor
	_box(body, Vector3(2.2 * s, 1.4 * s, 2.0 * s), Vector3(0.0, 0.55 * s, 0.0), MatLib.flat(Color("7d776c"), 0.0, 0.98))
	_box(body, Vector3(1.3 * s, 0.9 * s, 1.2 * s), Vector3(0.7 * s, 1.15 * s, 0.2 * s), MatLib.flat(Color("8a8479"), 0.0, 0.98))

static func barrier(parent: Node3D, origin: Vector3, yaw: float, length: float, palette: Dictionary) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var mat: StandardMaterial3D = palette.get("trim", MatLib.flat(Color("9aa0a8")))
	_box(body, Vector3(length, 0.9, 0.35), Vector3(0.0, 0.45, 0.0), mat)
	_box(body, Vector3(length, 0.16, 0.5), Vector3(0.0, 0.95, 0.0), MatLib.flat(Color("d8d2c4")))

static func watchtower(parent: Node3D, origin: Vector3, yaw: float, palette: Dictionary) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var leg_mat: StandardMaterial3D = palette.get("trim", MatLib.flat(Color("6b6459")))
	var deck_mat: StandardMaterial3D = palette.get("floor", MatLib.flat(Color("7a6a54")))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(body, Vector3(0.32, 7.0, 0.32), Vector3(sx * 1.8, 3.5, sz * 1.8), leg_mat)
	_box(body, Vector3(5.2, 0.35, 5.2), Vector3(0.0, 7.0, 0.0), deck_mat)
	_box(body, Vector3(5.2, 1.1, 0.25), Vector3(0.0, 7.6, -2.5), leg_mat)
	_box(body, Vector3(5.2, 1.1, 0.25), Vector3(0.0, 7.6, 2.5), leg_mat)
	_box(body, Vector3(0.25, 1.1, 5.2), Vector3(-2.5, 7.6, 0.0), leg_mat)
	_box(body, Vector3(0.25, 1.1, 5.2), Vector3(2.5, 7.6, 0.0), leg_mat)
	for i: int in 8:
		_box(body, Vector3(4.6, 0.22, 0.55), Vector3(0.0, 0.8 + float(i) * 0.85, -1.6 + float(i) * 0.0), deck_mat)

# ------------------------------------------------------------------ pieces

static func _slab(parent: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	_box(parent, size, pos, mat)

static func _parapet(parent: Node3D, _center: Vector3, width: float, depth: float, y: float, mat: StandardMaterial3D) -> void:
	var hw: float = width * 0.5
	var hd: float = depth * 0.5
	_box(parent, Vector3(width, 0.5, 0.3), Vector3(0.0, y + 0.25, -hd), mat)
	_box(parent, Vector3(width, 0.5, 0.3), Vector3(0.0, y + 0.25, hd), mat)
	_box(parent, Vector3(0.3, 0.5, depth), Vector3(-hw, y + 0.25, 0.0), mat)
	_box(parent, Vector3(0.3, 0.5, depth), Vector3(hw, y + 0.25, 0.0), mat)

## Wall segment from a to b (same y), with an optional door gap centred along
## its length and optional window band. Both endpoints are in body-local space.
static func _wall(parent: Node3D, a: Vector3, b: Vector3, height: float,
		wall_mat: StandardMaterial3D, trim_mat: StandardMaterial3D, glass_mat: StandardMaterial3D,
		door_offset: float, door_h: float, windows: bool) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.1:
		return
	var center: Vector3 = (a + b) * 0.5
	var yaw: float = atan2(dir.x, dir.z) + PI * 0.5
	var thickness: float = 0.28
	if door_offset >= 0.0:
		var dw: float = 1.5
		var left_len: float = (length - dw) * 0.5
		var lx: float = -(dw + left_len) * 0.5
		var rx: float = (dw + left_len) * 0.5
		_rot_box(parent, Vector3(left_len, height, thickness), center + _rot_x(yaw, lx), yaw, wall_mat)
		_rot_box(parent, Vector3(left_len, height, thickness), center + _rot_x(yaw, rx), yaw, wall_mat)
		var lintel_h: float = maxf(height - door_h, 0.2)
		_rot_box(parent, Vector3(dw, lintel_h, thickness), center + Vector3(0.0, height - lintel_h * 0.5, 0.0), yaw, trim_mat)
		if windows:
			_rot_box(parent, Vector3(left_len * 0.7, 1.1, thickness * 0.6), center + _rot_x(yaw, lx) + Vector3(0.0, height * 0.62, 0.0), yaw, trim_mat)
			_rot_box(parent, Vector3(left_len * 0.7, 1.1, thickness * 0.6), center + _rot_x(yaw, rx) + Vector3(0.0, height * 0.62, 0.0), yaw, trim_mat)
	else:
		_rot_box(parent, Vector3(length, height, thickness), center, yaw, wall_mat)
		if windows:
			var win_w: float = minf(1.6, length * 0.34)
			for off in [-length * 0.26, length * 0.26]:
				_rot_box(parent, Vector3(win_w, 1.2, thickness * 0.55), center + _rot_x(yaw, off) + Vector3(0.0, height * 0.62, 0.0), yaw, trim_mat)
				if glass_mat != null:
					_rot_box(parent, Vector3(win_w * 0.9, 1.05, 0.06), center + _rot_x(yaw, off) + Vector3(0.0, height * 0.62, 0.0), yaw, glass_mat)

static func _stairs(parent: Node3D, origin: Vector3, height: float, run: float, mat: StandardMaterial3D) -> void:
	var steps: int = maxi(4, int(height / 0.32))
	var step_h: float = height / float(steps)
	var step_d: float = maxf(0.5, run / float(steps))
	for i: int in steps:
		_box(parent, Vector3(1.6, step_h, step_d),
			origin + Vector3(0.0, step_h * 0.5 + float(i) * step_h, -run * 0.5 + float(i) * step_d + step_d * 0.5), mat)

static func _rot_x(yaw: float, offset: float) -> Vector3:
	return Vector3(cos(yaw) * offset, 0.0, -sin(yaw) * offset)

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var body: StaticBody3D = parent as StaticBody3D
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	if body != null:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)
	return mi

static func _rot_box(parent: Node3D, size: Vector3, pos: Vector3, yaw: float, mat: StandardMaterial3D) -> void:
	var body: StaticBody3D = parent as StaticBody3D
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = yaw
	mi.material_override = mat
	parent.add_child(mi)
	if body != null:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		cs.rotation.y = yaw
		body.add_child(cs)
