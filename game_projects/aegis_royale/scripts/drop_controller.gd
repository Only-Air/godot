class_name DropController
extends Node

signal drop_finished

var player: RoyalePlayer
var active := false
var glider_deployed := false
var vertical_speed := -18.0
var deploy_height := 28.0

func setup(controlled_player: RoyalePlayer, start_position: Vector3) -> void:
	player = controlled_player
	player.global_position = start_position
	player.set_physics_process(false)
	active = true

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player): return
	var horizontal := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward := -player.global_transform.basis.z
	var camera_right := player.global_transform.basis.x
	var direction := (camera_right * horizontal.x + camera_forward * -horizontal.y).normalized()
	if Input.is_action_pressed("jump") or player.global_position.y <= deploy_height:
		glider_deployed = true
	vertical_speed = -6.5 if glider_deployed else -18.0
	var horizontal_speed := 10.0 if glider_deployed else 6.0
	player.global_position += direction * horizontal_speed * delta
	player.global_position.y += vertical_speed * delta
	if player.global_position.y <= 1.2:
		player.global_position.y = 1.2
		active = false
		player.set_physics_process(true)
		drop_finished.emit()

func status_text() -> String:
	if not active: return ""
	if glider_deployed: return "滑翔中 · WASD 调整方向"
	return "自由落体 · 按空格展开滑翔装置"
