class_name CharacterModel
extends Node3D

## Procedural humanoid built from primitives, with named joints so the
## animator can drive a real walk/run/aim pose. Root sits at the feet.

const SKIN: Color = Color("d9a878")
const DARK: Color = Color("2b3340")

var hips: Node3D
var torso: Node3D
var head: Node3D
var head_mesh: MeshInstance3D
var visor: MeshInstance3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var chest_mesh: MeshInstance3D
var pack: Node3D

var outfit: Color = Color("3f7fd4")
var accent: Color = Color("f2c24c")

func build(outfit_color: Color, accent_color: Color, skin: Color = SKIN) -> void:
	outfit = outfit_color
	accent = accent_color
	var suit: StandardMaterial3D = MatLib.flat(outfit, 0.0, 0.72)
	var suit_dark: StandardMaterial3D = MatLib.flat(outfit.darkened(0.32), 0.0, 0.78)
	var accent_mat: StandardMaterial3D = MatLib.flat(accent, 0.18, 0.5)
	var skin_mat: StandardMaterial3D = MatLib.flat(skin, 0.0, 0.9)
	var dark_mat: StandardMaterial3D = MatLib.flat(DARK, 0.0, 0.6)

	hips = Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0.0, 0.90, 0.0)
	add_child(hips)

	_box(hips, Vector3(0.36, 0.24, 0.25), Vector3(0.0, 0.0, 0.0), suit_dark)

	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0.0, 0.11, 0.0)
	hips.add_child(torso)

	chest_mesh = _box(torso, Vector3(0.42, 0.46, 0.27), Vector3(0.0, 0.24, 0.0), suit)
	_box(torso, Vector3(0.44, 0.10, 0.29), Vector3(0.0, 0.44, 0.0), accent_mat)
	_box(torso, Vector3(0.30, 0.16, 0.06), Vector3(0.0, 0.26, -0.15), accent_mat)

	pack = Node3D.new()
	pack.name = "Pack"
	pack.position = Vector3(0.0, 0.26, 0.19)
	torso.add_child(pack)
	_box(pack, Vector3(0.30, 0.36, 0.16), Vector3.ZERO, suit_dark)
	_box(pack, Vector3(0.10, 0.14, 0.06), Vector3(0.0, 0.02, 0.09), accent_mat)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.55, 0.0)
	torso.add_child(head)
	_box(head, Vector3(0.16, 0.14, 0.16), Vector3(0.0, -0.02, 0.0), skin_mat)
	head_mesh = _box(head, Vector3(0.25, 0.26, 0.25), Vector3(0.0, 0.15, 0.0), skin_mat)
	visor = _box(head, Vector3(0.26, 0.10, 0.10), Vector3(0.0, 0.17, -0.10), dark_mat)
	_box(head, Vector3(0.27, 0.09, 0.27), Vector3(0.0, 0.28, 0.0), accent_mat)

	shoulder_l = _limb(torso, "ShoulderL", Vector3(-0.27, 0.42, 0.0))
	_box(shoulder_l, Vector3(0.15, 0.15, 0.15), Vector3(0.0, 0.0, 0.0), accent_mat)
	_box(shoulder_l, Vector3(0.13, 0.30, 0.13), Vector3(0.0, -0.16, 0.0), suit)
	elbow_l = _limb(shoulder_l, "ElbowL", Vector3(0.0, -0.31, 0.0))
	_box(elbow_l, Vector3(0.11, 0.28, 0.11), Vector3(0.0, -0.14, 0.0), suit)
	_box(elbow_l, Vector3(0.12, 0.10, 0.12), Vector3(0.0, -0.31, 0.0), skin_mat)

	shoulder_r = _limb(torso, "ShoulderR", Vector3(0.27, 0.42, 0.0))
	_box(shoulder_r, Vector3(0.15, 0.15, 0.15), Vector3(0.0, 0.0, 0.0), accent_mat)
	_box(shoulder_r, Vector3(0.13, 0.30, 0.13), Vector3(0.0, -0.16, 0.0), suit)
	elbow_r = _limb(shoulder_r, "ElbowR", Vector3(0.0, -0.31, 0.0))
	_box(elbow_r, Vector3(0.11, 0.28, 0.11), Vector3(0.0, -0.14, 0.0), suit)
	_box(elbow_r, Vector3(0.12, 0.10, 0.12), Vector3(0.0, -0.31, 0.0), skin_mat)

	hip_l = _limb(hips, "HipL", Vector3(-0.12, -0.08, 0.0))
	_box(hip_l, Vector3(0.17, 0.40, 0.17), Vector3(0.0, -0.20, 0.0), suit_dark)
	knee_l = _limb(hip_l, "KneeL", Vector3(0.0, -0.40, 0.0))
	_box(knee_l, Vector3(0.15, 0.36, 0.15), Vector3(0.0, -0.18, 0.0), suit)
	_box(knee_l, Vector3(0.16, 0.09, 0.26), Vector3(0.0, -0.38, 0.04), dark_mat)

	hip_r = _limb(hips, "HipR", Vector3(0.12, -0.08, 0.0))
	_box(hip_r, Vector3(0.17, 0.40, 0.17), Vector3(0.0, -0.20, 0.0), suit_dark)
	knee_r = _limb(hip_r, "KneeR", Vector3(0.0, -0.40, 0.0))
	_box(knee_r, Vector3(0.15, 0.36, 0.15), Vector3(0.0, -0.18, 0.0), suit)
	_box(knee_r, Vector3(0.16, 0.09, 0.26), Vector3(0.0, -0.38, 0.04), dark_mat)

func set_team_color(color: Color) -> void:
	outfit = color
	accent = color.lightened(0.4)

func _limb(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
