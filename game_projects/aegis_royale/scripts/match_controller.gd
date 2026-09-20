class_name MatchController
extends Node

signal match_ended(won: bool, placement: int)

var player: RoyalePlayer
var profile: LocalProfile
var active := false
var starting_combatants := 0
var eliminations := 0
var result_shown := false

func setup(controlled_player: RoyalePlayer, local_profile: LocalProfile) -> void:
	player = controlled_player
	profile = local_profile
	starting_combatants = get_tree().get_nodes_in_group("combatants").size()
	active = true
	player.eliminated.connect(_on_player_eliminated)

func _process(_delta: float) -> void:
	if not active or result_shown: return
	var combatants := get_tree().get_nodes_in_group("combatants")
	if combatants.size() == 1 and is_instance_valid(player) and combatants[0] == player:
		_finish(true, 1)

func _on_player_eliminated() -> void:
	var placement := maxi(2, get_tree().get_nodes_in_group("combatants").size())
	_finish(false, placement)

func _finish(won: bool, placement: int) -> void:
	if result_shown: return
	result_shown = true
	active = false
	profile.record_match(won, placement, eliminations)
	match_ended.emit(won, placement)
	_show_result(won, placement)

func _show_result(won: bool, placement: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	get_tree().current_scene.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.09, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var title := Label.new()
	title.text = "最后生还者！" if won else "本局结束"
	title.position = Vector2(430, 175)
	title.add_theme_font_size_override("font_size", 52)
	shade.add_child(title)
	var summary := Label.new()
	summary.text = "排名：#%d\n本地累计比赛：%d\n本地累计胜利：%d" % [placement, int(profile.statistics.matches), int(profile.statistics.wins)]
	summary.position = Vector2(500, 275)
	summary.add_theme_font_size_override("font_size", 25)
	shade.add_child(summary)
	var restart := Button.new()
	restart.text = "再来一局"
	restart.position = Vector2(500, 445)
	restart.size = Vector2(280, 58)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	shade.add_child(restart)
