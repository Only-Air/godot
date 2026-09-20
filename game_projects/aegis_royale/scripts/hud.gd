class_name RoyaleHUD
extends CanvasLayer

var player: RoyalePlayer
var storm: StormController
var stats_label: Label
var storm_label: Label
var alive_label: Label
var crosshair: Label
var help_panel: ColorRect

func setup(controlled_player: RoyalePlayer, storm_controller: StormController) -> void:
	player = controlled_player
	storm = storm_controller
	_build_ui()
	player.stats_changed.connect(_refresh)

func _build_ui() -> void:
	stats_label = Label.new()
	stats_label.position = Vector2(28, 630)
	stats_label.add_theme_font_size_override("font_size", 21)
	add_child(stats_label)
	storm_label = Label.new()
	storm_label.position = Vector2(450, 22)
	storm_label.add_theme_font_size_override("font_size", 20)
	add_child(storm_label)
	alive_label = Label.new()
	alive_label.position = Vector2(1100, 22)
	alive_label.add_theme_font_size_override("font_size", 20)
	add_child(alive_label)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(635, 350)
	crosshair.add_theme_font_size_override("font_size", 26)
	add_child(crosshair)
	help_panel = ColorRect.new()
	help_panel.color = Color(0.02, 0.04, 0.08, 0.72)
	help_panel.position = Vector2(18, 18)
	help_panel.size = Vector2(360, 168)
	add_child(help_panel)
	var help := Label.new()
	help.position = Vector2(12, 9)
	help.text = "WASD 移动 / Shift 冲刺 / 空格跳跃\n左键射击或建造　R 换弹\nQ 战斗/建造　1-4 选择结构　G 旋转\nF 编辑准星所指结构　V 切换简易模式\n简易建造：结构更贴近角色、快速落板\n简易编辑：墙体在完整/半墙之间切换"
	help_panel.add_child(help)
	_refresh()

func _process(_delta: float) -> void:
	if is_instance_valid(storm): storm_label.text = storm.status_text()
	alive_label.text = "存活 %d" % get_tree().get_nodes_in_group("combatants").size()

func _refresh() -> void:
	if not is_instance_valid(player): return
	var mode := "建造" if player.build_mode else "战斗"
	var simple := "简易建造/编辑：开" if player.simple_build else "简易建造/编辑：关"
	stats_label.text = "生命 %.0f　护盾 %.0f　弹药 %d/%d　材料 %d\n%s模式　%s　结构：%s" % [player.health, player.shield, player.ammo_in_mag, player.reserve_ammo, player.materials, mode, simple, player.selected_piece]
