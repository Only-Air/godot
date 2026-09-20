class_name PauseMenu
extends CanvasLayer

var player: RoyalePlayer
var profile: LocalProfile
var panel: ColorRect
var sensitivity_label: Label
var paused := false

func setup(controlled_player: RoyalePlayer, local_profile: LocalProfile) -> void:
	player = controlled_player
	profile = local_profile
	player.set_meta("mouse_sensitivity", float(profile.settings.mouse_sensitivity))
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu()
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	paused = not paused
	panel.visible = paused
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _build_menu() -> void:
	panel = ColorRect.new()
	panel.color = Color(0.025, 0.045, 0.09, 0.94)
	panel.position = Vector2(345, 95)
	panel.size = Vector2(590, 535)
	add_child(panel)
	var title := Label.new()
	title.text = "暂停与离线设置"
	title.position = Vector2(36, 28)
	title.add_theme_font_size_override("font_size", 34)
	panel.add_child(title)
	var sensitivity := HSlider.new()
	sensitivity.position = Vector2(40, 115)
	sensitivity.size = Vector2(500, 28)
	sensitivity.min_value = 0.35
	sensitivity.max_value = 2.0
	sensitivity.step = 0.05
	sensitivity.value = float(profile.settings.mouse_sensitivity)
	panel.add_child(sensitivity)
	sensitivity_label = Label.new()
	sensitivity_label.position = Vector2(40, 82)
	panel.add_child(sensitivity_label)
	sensitivity.value_changed.connect(func(value):
		profile.settings.mouse_sensitivity = value
		player.set_meta("mouse_sensitivity", value)
		_update_sensitivity_label(value)
	)
	_update_sensitivity_label(sensitivity.value)
	var simple_build := CheckBox.new()
	simple_build.text = "默认启用简易建造"
	simple_build.position = Vector2(40, 175)
	simple_build.button_pressed = bool(profile.settings.simple_build_default)
	simple_build.toggled.connect(func(value):
		profile.settings.simple_build_default = value
		player.simple_build = value
	)
	panel.add_child(simple_build)
	var simple_edit := CheckBox.new()
	simple_edit.text = "默认启用简易编辑"
	simple_edit.position = Vector2(40, 220)
	simple_edit.button_pressed = bool(profile.settings.simple_edit_default)
	simple_edit.toggled.connect(func(value):
		profile.settings.simple_edit_default = value
		player.simple_edit = value
	)
	panel.add_child(simple_edit)
	var help := Label.new()
	help.text = "灵敏度与简易模式立即应用并可保存。\nAI 数量和难度在下一局生效。\n当前比赛完全离线；退出不会上传任何数据。"
	help.position = Vector2(40, 285)
	help.add_theme_font_size_override("font_size", 18)
	panel.add_child(help)
	var resume := Button.new()
	resume.text = "继续比赛"
	resume.position = Vector2(40, 375)
	resume.size = Vector2(235, 52)
	resume.pressed.connect(_toggle_pause)
	panel.add_child(resume)
	var restart := Button.new()
	restart.text = "重新开始"
	restart.position = Vector2(305, 375)
	restart.size = Vector2(235, 52)
	restart.pressed.connect(func():
		profile.save_profile()
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	panel.add_child(restart)
	var save := Button.new()
	save.text = "保存设置"
	save.position = Vector2(40, 445)
	save.size = Vector2(500, 44)
	save.pressed.connect(profile.save_profile)
	panel.add_child(save)

func _update_sensitivity_label(value: float) -> void:
	sensitivity_label.text = "鼠标灵敏度：%.2f" % value
