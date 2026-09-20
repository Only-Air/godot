class_name BuildSystem
extends Node

## Placement brain shared by the player and the AI. Handles grid targeting,
## validity, turbo building, and tile-level editing of owned structures.

const CELL: float = BuildPiece.CELL
const LEVEL: float = BuildPiece.LEVEL
const COST: int = 10
const MAX_DISTANCE: float = 15.0
const TURBO_INTERVAL: float = 0.075

const STEP_DIRS: Array[Vector3] = [
	Vector3(0.0, 0.0, -1.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 1.0),
	Vector3(-1.0, 0.0, 0.0),
]

var actor: Node3D
var world: Node3D
var registry: Dictionary
var terrain: Node

var piece_type: String = "wall"
var mat_type: String = "wood"
var rotation_steps: int = 0
var simple_mode: bool = false

var ghost: BuildPiece
var preview_valid: bool = false
var preview_transform: Transform3D = Transform3D.IDENTITY
var target_key: String = ""
var last_place_time: float = -10.0
var last_fail_reason: String = ""

var edit_piece: BuildPiece = null
var edit_backup: Array[int] = []
var edit_tile: int = -1

func setup(p_actor: Node3D, p_world: Node3D, p_registry: Dictionary) -> void:
	actor = p_actor
	world = p_world
	registry = p_registry
	var terrains: Array = get_tree().get_nodes_in_group("terrain")
	if not terrains.is_empty():
		terrain = terrains[0]
	ghost = BuildPiece.new()
	ghost.ghost = true
	world.add_child(ghost)
	ghost.setup("wall", "wood", 0, "")
	ghost.visible = false

func set_piece(p_type: String) -> void:
	piece_type = p_type
	_refresh_ghost()

func set_material(m: String) -> void:
	mat_type = m
	_refresh_ghost()

func cycle_material() -> String:
	var order: Array[String] = ["wood", "stone", "metal"]
	var i: int = order.find(mat_type)
	mat_type = order[(i + 1) % order.size()]
	_refresh_ghost()
	return mat_type

func rotate_step() -> void:
	rotation_steps = (rotation_steps + 1) % 4

func _refresh_ghost() -> void:
	if ghost == null or not is_instance_valid(ghost):
		return
	ghost.piece_type = piece_type
	ghost.mat_type = mat_type
	ghost.tiles = BuildPiece.FULL.duplicate()
	ghost.rebuild()

func set_ghost_visible(v: bool) -> void:
	if ghost != null and is_instance_valid(ghost):
		ghost.visible = v and edit_piece == null

func dir_for(yaw: float) -> Vector3:
	var step: int = int(round(yaw / (PI * 0.5))) + rotation_steps
	return STEP_DIRS[((step % 4) + 4) % 4]

func compute_target(pos: Vector3, yaw: float, pitch: float, aim_point: Vector3) -> void:
	var cell_x: int = int(floor(pos.x / CELL))
	var cell_z: int = int(floor(pos.z / CELL))
	var level: int = int(round(pos.y / LEVEL))
	var dir: Vector3 = dir_for(yaw)
	var center_x: float = (float(cell_x) + 0.5) * CELL
	var center_z: float = (float(cell_z) + 0.5) * CELL
	var base_y: float = float(level) * LEVEL
	var front_x: float = center_x + dir.x * CELL
	var front_z: float = center_z + dir.z * CELL
	var yaw_out: float = atan2(dir.x, dir.z)

	match piece_type:
		"wall":
			var px: float = center_x + dir.x * CELL * 0.5
			var pz: float = center_z + dir.z * CELL * 0.5
			var edge: int = ((int(round(yaw / (PI * 0.5))) + rotation_steps) % 4 + 4) % 4
			target_key = "wall:%d:%d:%d:%d" % [cell_x, level, cell_z, edge]
			preview_transform = Transform3D(Basis(Vector3.UP, yaw_out), Vector3(px, base_y, pz))
		"floor":
			var use_level: int = level + 1 if pitch > 0.25 else level
			target_key = "floor:%d:%d:%d" % [cell_x, use_level, cell_z]
			preview_transform = Transform3D(Basis(Vector3.UP, yaw_out), Vector3(center_x, float(use_level) * LEVEL - 0.1, center_z))
		"ramp":
			target_key = "ramp:%d:%d:%d" % [cell_x, level, cell_z]
			preview_transform = Transform3D(Basis(Vector3.UP, yaw_out), Vector3(front_x, base_y, front_z))
		"cone":
			var cl: int = level + 1
			target_key = "cone:%d:%d:%d" % [cell_x, cl, cell_z]
			preview_transform = Transform3D(Basis(Vector3.UP, yaw_out), Vector3(center_x, float(cl) * LEVEL, center_z))
		_:
			target_key = "wall:%d:%d:%d" % [cell_x, level, cell_z]
			preview_transform = Transform3D(Basis(Vector3.UP, yaw_out), Vector3(center_x, base_y, center_z))

	preview_valid = _validate(preview_transform.origin)
	if ghost != null and is_instance_valid(ghost):
		ghost.global_transform = preview_transform
		ghost.set_tint(Color(0.30, 0.85, 1.0, 0.42) if preview_valid else Color(1.0, 0.25, 0.25, 0.5))

func _validate(pos: Vector3) -> bool:
	last_fail_reason = ""
	if actor == null or not is_instance_valid(actor):
		return false
	if not _has_material():
		last_fail_reason = "材料不足"
		return false
	if pos.distance_to(actor.global_position) > MAX_DISTANCE:
		last_fail_reason = "超出范围"
		return false
	if registry.has(target_key):
		last_fail_reason = "已被占用"
		return false
	if terrain != null and is_instance_valid(terrain):
		var ground: float = terrain.call("height_at", pos.x, pos.z)
		if pos.y < ground - 0.4:
			last_fail_reason = "位于地形内"
			return false
	return true

func _has_material() -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if not "resources" in actor:
		return true
	var res: Dictionary = actor.resources
	return int(res.get(mat_type, 0)) >= COST

func can_place_now() -> bool:
	return preview_valid

func try_place(force: bool = false) -> bool:
	if edit_piece != null:
		return false
	if not preview_valid:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if not force and now - last_place_time < TURBO_INTERVAL:
		return false
	last_place_time = now
	_spawn(preview_transform, piece_type, mat_type, target_key, BuildPiece.FULL.duplicate())
	if actor != null and "resources" in actor:
		actor.resources[mat_type] = maxi(0, int(actor.resources.get(mat_type, 0)) - COST)
	if piece_type == "wall":
		pass
	elif piece_type == "cone":
		pass
	return true

func spawn_at(pos: Vector3, yaw: float, p_type: String, p_mat: String) -> BuildPiece:
	var key: String = "%s:%.1f:%.1f:%.1f" % [p_type, pos.x, pos.y, pos.z]
	var basis: Basis = Basis(Vector3.UP, yaw)
	var piece: BuildPiece = _spawn(Transform3D(basis, pos), p_type, p_mat, key, BuildPiece.FULL.duplicate())
	return piece

func _spawn(xform: Transform3D, p_type: String, p_mat: String, key: String, tiles: Array) -> BuildPiece:
	var piece: BuildPiece = BuildPiece.new()
	world.add_child(piece)
	piece.setup(p_type, p_mat, 0 if actor == null else int(actor.get_instance_id()), key, tiles)
	piece.global_transform = xform
	piece.scale = Vector3(0.55, 0.25, 0.55)
	var tw: Tween = piece.create_tween()
	tw.tween_property(piece, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	registry[key] = piece
	piece.tree_exiting.connect(_on_piece_exiting.bind(key, piece))
	if actor != null and actor.has_method("on_piece_built"):
		actor.call("on_piece_built", piece)
	return piece

func _on_piece_exiting(key: String, piece: BuildPiece) -> void:
	if registry.get(key) == piece:
		registry.erase(key)

# ---------------------------------------------------------------- editing

func begin_edit(piece: BuildPiece, hit_local: Vector3) -> bool:
	if piece == null or not is_instance_valid(piece) or piece.ghost:
		return false
	if actor != null and piece.owner_id != int(actor.get_instance_id()):
		return false
	if piece.piece_type != "wall" and piece.piece_type != "floor":
		return false
	edit_piece = piece
	edit_backup = piece.tiles.duplicate()
	edit_tile = piece.tile_index_from_local(hit_local)
	piece.set_tint(Color(0.35, 0.9, 1.0, 0.34))
	if ghost != null and is_instance_valid(ghost):
		ghost.visible = false
	return true

func hover_tile(hit_local: Vector3) -> int:
	if edit_piece == null:
		return -1
	edit_tile = edit_piece.tile_index_from_local(hit_local)
	return edit_tile

func toggle_hovered_tile() -> void:
	if edit_piece == null or edit_tile < 0:
		return
	edit_piece.toggle_tile(edit_tile)
	edit_piece.set_tint(Color(0.35, 0.9, 1.0, 0.34))

func confirm_edit() -> void:
	if edit_piece == null:
		return
	var p: BuildPiece = edit_piece
	var edited: bool = p.is_edited()
	edit_piece = null
	edit_tile = -1
	p.use_tint = false
	p.rebuild()
	if actor != null and edited and actor.has_method("on_piece_edited"):
		actor.call("on_piece_edited", p)

func cancel_edit() -> void:
	if edit_piece == null:
		return
	var p: BuildPiece = edit_piece
	p.tiles = edit_backup.duplicate()
	edit_piece = null
	edit_tile = -1
	p.use_tint = false
	p.rebuild()

func is_editing() -> bool:
	return edit_piece != null

# ---------------------------------------------------------------- AI helpers

## Place a defensive wall facing the given world direction. Used by the AI.
func ai_place_facing(from_pos: Vector3, face_dir: Vector3, p_type: String = "wall") -> BuildPiece:
	var dir: Vector3 = Vector3(face_dir.x, 0.0, face_dir.z).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var yaw: float = atan2(dir.x, dir.z)
	var cell_x: int = int(floor(from_pos.x / CELL))
	var cell_z: int = int(floor(from_pos.z / CELL))
	var level: int = int(round(from_pos.y / LEVEL))
	var center_x: float = (float(cell_x) + 0.5) * CELL
	var center_z: float = (float(cell_z) + 0.5) * CELL
	var base_y: float = float(level) * LEVEL
	var pos: Vector3 = Vector3.ZERO
	var key: String = ""
	if p_type == "wall":
		var edge: int = ((int(round(yaw / (PI * 0.5))) % 4) + 4) % 4
		pos = Vector3(center_x + dir.x * CELL * 0.5, base_y, center_z + dir.z * CELL * 0.5)
		key = "wall:%d:%d:%d:%d" % [cell_x, level, cell_z, edge]
	elif p_type == "floor":
		pos = Vector3(center_x, base_y - 0.1, center_z)
		key = "floor:%d:%d:%d" % [cell_x, level, cell_z]
	elif p_type == "ramp":
		pos = Vector3(center_x + dir.x * CELL, base_y, center_z + dir.z * CELL)
		key = "ramp:%d:%d:%d" % [cell_x, level, cell_z]
	else:
		pos = Vector3(center_x, base_y + LEVEL, center_z)
		key = "cone:%d:%d:%d" % [cell_x, level + 1, cell_z]
	if registry.has(key):
		return null
	if not _has_material():
		return null
	var piece: BuildPiece = _spawn(Transform3D(Basis(Vector3.UP, yaw), pos), p_type, mat_type, key, BuildPiece.FULL.duplicate())
	if actor != null and "resources" in actor:
		actor.resources[mat_type] = maxi(0, int(actor.resources.get(mat_type, 0)) - COST)
	return piece

## Box the actor in with four walls (panic defence / heal).
func ai_box_self() -> int:
	var placed: int = 0
	for i: int in 4:
		var d: Vector3 = STEP_DIRS[i]
		if ai_place_facing(actor.global_position, d, "wall") != null:
			placed += 1
	return placed
