class_name Lobby
extends CanvasLayer

## Main menu: original styling, career card, mode row, settings and controls.

signal start_match
signal settings_changed

var profile: LocalProfile
var root: LobbyRoot
var settings_panel: Control
var sens_slider: HSlider
var ai_slider: HSlider
var diff_slider: HSlider
var fov_slider: HSlider

func setup(p_profile: LocalProfile) -> void:
	profile = p_profile

func _ready() -> void:
	root = LobbyRoot.new()
	root.lobby = self
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_ui()

func _build_ui() -> void:
	var title: Label = _label("AEGIS ROYALE", Vector2(90, 96), 68, Color(1, 1, 1))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var sub: Label = _label("离线建造大逃杀 · 原创岛屿 · 32 人单机对局", Vector2(94, 172), 22, Color(0.78, 0.88, 1.0))

	var card: ColorRect = ColorRect.new()
	card.color = Color(0.04, 0.07, 0.12, 0.72)
	card.position = Vector2(90, 232)
	card.size = Vector2(520, 200)
	add_child(card)
	_label("生涯记录", Vector2(114, 264), 22, Color(0.9, 0.95, 1.0), card)
	var st: Dictionary = profile.stats
	_label("比赛 %d    胜利 %d    前十 %d" % [int(st.get("matches", 0)), int(st.get("wins", 0)), int(st.get("top10", 0))],
		Vector2(114, 306), 19, Color(0.85, 0.9, 0.95), card)
	_label("淘汰 %d    最佳排名 #%d" % [int(st.get("kills", 0)), int(st.get("best_placement", 0))],
		Vector2(114, 340), 19, Color(0.85, 0.9, 0.95), card)
	_label("本地档案保存在 user://aegis_royale_profile.json", Vector2(114, 386), 14, Color(0.6, 0.68, 0.78), card)

	var play: Button = Button.new()
	play.text = "开始比赛"
	play.position = Vector2(1000, 560)
	play.size = Vector2(340, 76)
	play.add_theme_font_size_override("font_size", 30)
	play.pressed.connect(func() -> void: start_match.emit())
	add_child(play)

	var settings_btn: Button = Button.new()
	settings_btn.text = "设置"
	settings_btn.position = Vector2(1000, 652)
	settings_btn.size = Vector2(162, 56)
	settings_btn.add_theme_font_size_override("font_size", 21)
	settings_btn.pressed.connect(_toggle_settings)
	add_child(settings_btn)

	var quit_btn: Button = Button.new()
	quit_btn.text = "退出"
	quit_btn.position = Vector2(1178, 652)
	quit_btn.size = Vector2(162, 56)
	quit_btn.add_theme_font_size_override("font_size", 21)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	add_child(quit_btn)

	var controls: Label = _label(
		"WASD 移动　Shift 冲刺　Ctrl 蹲下　空格 跳跃/滑翔\n" +
		"左键 射击/建造　右键 瞄准　R 换弹　E 搜索\n" +
		"Q 建造模式　1-4 选择结构　F 编辑　G 旋转　V 简易模式　Z 切换建材\n" +
		"Esc 暂停与设置",
		Vector2(90, 500), 18, Color(0.72, 0.8, 0.9))
	controls.add_theme_constant_override("line_spacing", 8)

	_build_settings_panel()

func _build_settings_panel() -> void:
	settings_panel = ColorRect.new()
	settings_panel.color = Color(0.03, 0.05, 0.09, 0.95)
	settings_panel.position = Vector2(560, 150)
	settings_panel.size = Vector2(480, 470)
	settings_panel.visible = false
	add_child(settings_panel)
	_label("设置", Vector2(30, 30), 30, Color.WHITE, settings_panel)
	sens_slider = _slider(settings_panel, "鼠标灵敏度", 96, 0.2, 3.0, 0.05, float(profile.settings.get("mouse_sensitivity", 1.0)))
	ai_slider = _slider(settings_panel, "AI 数量", 176, 5.0, 63.0, 1.0, float(profile.settings.get("ai_count", 31)))
	diff_slider = _slider(settings_panel, "AI 难度", 256, 0.15, 1.0, 0.05, float(profile.settings.get("ai_difficulty", 0.55)))
	fov_slider = _slider(settings_panel, "视野角度", 336, 65.0, 105.0, 1.0, float(profile.settings.get("field_of_view", 78.0)))
	var close: Button = Button.new()
	close.text = "保存并关闭"
	close.position = Vector2(30, 404)
	close.size = Vector2(200, 46)
	close.pressed.connect(_toggle_settings)
	settings_panel.add_child(close)

func _slider(parent: Control, label: String, y: float, mn: float, mx: float, step: float, value: float) -> HSlider:
	var value_lbl: Label = _label("", Vector2(320, y), 18, Color("ffd166"), parent)
	var s: HSlider = HSlider.new()
	s.position = Vector2(30, y + 26)
	s.size = Vector2(400, 24)
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	parent.add_child(s)
	value_lbl.text = "%.2f" % value if step < 1.0 else "%d" % int(value)
	s.value_changed.connect(func(v: float) -> void:
		value_lbl.text = "%.2f" % v if step < 1.0 else "%d" % int(v)
		_apply_settings()
	)
	return s

func _apply_settings() -> void:
	profile.settings["mouse_sensitivity"] = float(sens_slider.value)
	profile.settings["ai_count"] = int(ai_slider.value)
	profile.settings["ai_difficulty"] = float(diff_slider.value)
	profile.settings["field_of_view"] = float(fov_slider.value)
	profile.save()
	settings_changed.emit()

func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	if not settings_panel.visible:
		_apply_settings()

func _label(txt: String, pos: Vector2, fsize: int, col: Color, parent: Control = null) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if parent != null:
		parent.add_child(l)
	else:
		add_child(l)
	return l

# ---------------------------------------------------------------------------

class LobbyRoot extends Control:
	var lobby: Lobby
	var t: float = 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var vp: Vector2 = size
		var top: Color = Color("132a4a")
		var bottom: Color = Color("0a1526")
		var steps: int = 48
		for i: int in steps:
			var f: float = float(i) / float(steps)
			var c: Color = top.lerp(bottom, f)
			draw_rect(Rect2(0.0, vp.y * f, vp.x, vp.y / float(steps) + 2.0), c, true)
		draw_circle(Vector2(vp.x * 0.78, vp.y * 0.42), 260.0, Color(0.18, 0.38, 0.66, 0.18))
		draw_circle(Vector2(vp.x * 0.78, vp.y * 0.42), 190.0, Color(0.28, 0.55, 0.85, 0.14))
		for i: int in 6:
			var y: float = vp.y * 0.70 + float(i) * 16.0
			draw_rect(Rect2(0.0, y, vp.x, 6.0), Color(0.20, 0.42, 0.68, 0.10 + 0.02 * float(i)), true)
		var pulse: float = 0.5 + 0.5 * sin(t * 1.4)
		draw_line(Vector2(90.0, 214.0), Vector2(90.0 + 360.0 * (0.6 + 0.4 * pulse), 214.0), Color(0.42, 0.78, 1.0, 0.75), 3.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(vp.x - 260.0, vp.y - 30.0), "v0.4.0-alpha  original assets only",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.55, 0.65, 0.78))
