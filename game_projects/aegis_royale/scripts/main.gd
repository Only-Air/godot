extends Node3D

## Match assembly: environment, island, storm, player, AI roster, HUD,
## pause menu and results.

const DROP_HEIGHT: float = 185.0

var profile: LocalProfile = LocalProfile.new()
var build_registry: Dictionary = {}
var terrain: Terrain
var map_builder: MapBuilder
var storm: Storm
var player: PlayerController
var hud: HUD
var bots: Array = []
var lobby: Lobby
var pause_layer: CanvasLayer
var result_layer: CanvasLayer
var paused: bool = false
var match_active: bool = false
var results_shown: bool = false
var kill_count: int = 0
var start_time: float = 0.0
var ai_count: int = 31
var ai_difficulty: float = 0.55

func _ready() -> void:
	randomize()
	profile.load_profile()
	_show_lobby()

# ------------------------------------------------------------------ lobby

func _show_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lobby = Lobby.new()
	lobby.setup(profile)
	add_child(lobby)
	lobby.start_match.connect(_on_start_match)
	lobby.settings_changed.connect(func() -> void: profile.save())

func _on_start_match() -> void:
	if match_active:
		return
	if lobby != null and is_instance_valid(lobby):
		lobby.queue_free()
	lobby = null
	_build_world()

# ------------------------------------------------------------------ world

func _build_world() -> void:
	ai_count = clampi(int(profile.settings.get("ai_count", 31)), 3, 63)
	ai_difficulty = clampf(float(profile.settings.get("ai_difficulty", 0.55)), 0.1, 1.0)

	_build_environment()

	terrain = Terrain.new()
	add_child(terrain)
	terrain.generate(MapBuilder.poi_definitions(), MapBuilder.road_list(), randi())

	map_builder = MapBuilder.new()
	add_child(map_builder)
	map_builder.build(terrain, randi())

	storm = Storm.new()
	add_child(storm)
	storm.setup()

	_spawn_player()
	_spawn_bots()

	hud = HUD.new()
	add_child(hud)
	hud.alive_total = bots.size() + 1
	hud.setup(player, storm, self, build_registry)

	_build_pause_menu()

	match_active = true
	start_time = Time.get_ticks_msec() / 1000.0

func _build_environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()

	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2c6ab0")
	sky_mat.sky_horizon_color = Color("bcd8ec")
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color("3a5a48")
	sky_mat.ground_horizon_color = Color("93a9b8")
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.ambient_light_sky_contribution = 1.0

	env.fog_enabled = true
	env.fog_light_color = Color("b6d2e8")
	env.fog_light_energy = 0.9
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.4

	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.12

	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.06

	we.environment = env
	add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, -132.0, 0.0)
	sun.light_color = Color("fff3dd")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_split_1 = 0.10
	sun.directional_shadow_split_2 = 0.24
	sun.directional_shadow_split_3 = 0.52
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.4
	add_child(sun)

func _spawn_player() -> void:
	player = PlayerController.new()
	player.setup_actor(self, "你", 0, Color("3f8fe0"), Color("ffd166"))
	player.build_registry = build_registry
	player.equip_starting_kit("service_pistol", 0, 60)
	player.sensitivity = float(profile.settings.get("mouse_sensitivity", 1.0))
	add_child(player)
	player.global_position = Vector3(0.0, DROP_HEIGHT, 0.0)
	player.camera.fov = float(profile.settings.get("field_of_view", 78.0))
	player.begin_drop(DROP_HEIGHT)
	player.died.connect(_on_actor_died)

func _spawn_bots() -> void:
	var pois: Array = MapBuilder.poi_definitions()
	var personalities: Array[String] = ["balanced", "aggressive", "builder", "marksman", "cautious"]
	for i: int in ai_count:
		var bot: Bot = Bot.new()
		var hue: float = float(i) / float(maxi(ai_count, 1))
		var outfit: Color = Color.from_hsv(hue, 0.55, 0.82)
		var accent: Color = Color.from_hsv(fmod(hue + 0.5, 1.0), 0.65, 0.95)
		bot.setup_actor(self, "AI-%02d" % (i + 1), i + 1, outfit, accent)
		bot.build_registry = build_registry
		var skill: float = clampf(ai_difficulty + randf_range(-0.18, 0.18), 0.12, 1.0)
		bot.configure(skill, personalities[i % personalities.size()])
		var pos: Vector3 = _bot_spawn_point(pois, i)
		if randf() < 0.8:
			bot.equip_starting_kit(WeaponDB.random_id(), mini(WeaponDB.roll_rarity_index(3), 3), randi_range(60, 180))
		else:
			bot.equip_starting_kit("service_pistol", 0, 40)
		add_child(bot)
		bot.global_position = pos
		bot.died.connect(_on_actor_died)
		bots.append(bot)

func _bot_spawn_point(pois: Array, index: int) -> Vector3:
	var x: float = 0.0
	var z: float = 0.0
	if index < pois.size():
		var p: Dictionary = pois[index]
		var a: float = randf() * TAU
		var r: float = randf_range(4.0, float(p["radius"]) * 0.9)
		x = float(p["x"]) + cos(a) * r
		z = float(p["z"]) + sin(a) * r
	else:
		var a2: float = randf() * TAU
		var r2: float = randf_range(20.0, 130.0)
		x = cos(a2) * r2
		z = sin(a2) * r2
	var y: float = 0.0
	if terrain != null:
		y = terrain.height_at(x, z)
	return Vector3(x, y + 1.2, z)

# ------------------------------------------------------------------ match

func _on_actor_died(victim: Actor, killer: Node) -> void:
	if hud == null:
		return
	var killer_name: String = "风暴"
	if killer is Actor:
		killer_name = (killer as Actor).display_name
	if killer == player:
		kill_count += 1
	hud.push_kill(killer_name, victim.display_name)
	hud.alive_total = _alive_count()
	if victim == player:
		_finish_match(false, _alive_count() + 1)

func _alive_count() -> int:
	var n: int = 0
	for b in bots:
		var bot: Bot = b
		if is_instance_valid(bot) and not bot.is_dead:
			n += 1
	if player != null and is_instance_valid(player) and not player.is_dead:
		n += 1
	return n

func _process(_delta: float) -> void:
	if not match_active or results_shown:
		return
	if hud != null:
		hud.alive_total = _alive_count()
	if _alive_count() <= 1:
		var won: bool = player != null and is_instance_valid(player) and not player.is_dead
		_finish_match(won, 1 if won else 2)

func _finish_match(won: bool, placement: int) -> void:
	if results_shown:
		return
	results_shown = true
	match_active = false
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - start_time
	profile.record(won, placement, kill_count)
	_show_results(won, placement, elapsed)

func _show_results(won: bool, placement: int, elapsed: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null and is_instance_valid(player):
		player.set_ui_locked(true)
	result_layer = CanvasLayer.new()
	add_child(result_layer)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.06, 0.11, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(shade)

	var title: Label = Label.new()
	title.text = "第一名  ·  最后生还者" if won else "第 %d 名" % placement
	title.position = Vector2(0, 150)
	title.size = Vector2(1600, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("ffd166") if won else Color("ff8a6b"))
	shade.add_child(title)

	var info: Label = Label.new()
	info.text = "淘汰 %d    存活时间 %02d:%02d    剩余 %d 人\n本局排名 #%d" % [
		kill_count, int(elapsed) / 60, int(elapsed) % 60, _alive_count(), placement]
	info.position = Vector2(0, 250)
	info.size = Vector2(1600, 120)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 24)
	shade.add_child(info)

	var career: Label = Label.new()
	career.text = "生涯：%d 场 · %d 胜 · 累计淘汰 %d · 最佳 #%d" % [
		int(profile.stats.get("matches", 0)), int(profile.stats.get("wins", 0)),
		int(profile.stats.get("kills", 0)), int(profile.stats.get("best_placement", 0))]
	career.position = Vector2(0, 390)
	career.size = Vector2(1600, 40)
	career.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	career.add_theme_font_size_override("font_size", 20)
	career.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	shade.add_child(career)

	var again: Button = Button.new()
	again.text = "再来一局"
	again.position = Vector2(620, 500)
	again.size = Vector2(360, 70)
	again.add_theme_font_size_override("font_size", 26)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	shade.add_child(again)

# ------------------------------------------------------------------ pause

func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var panel: ColorRect = ColorRect.new()
	panel.name = "Panel"
	panel.color = Color(0.03, 0.05, 0.09, 0.95)
	panel.position = Vector2(560, 170)
	panel.size = Vector2(480, 500)
	panel.visible = false
	pause_layer.add_child(panel)

	var title: Label = Label.new()
	title.text = "暂停"
	title.position = Vector2(34, 28)
	title.add_theme_font_size_override("font_size", 32)
	panel.add_child(title)

	var sens_label: Label = Label.new()
	sens_label.text = "鼠标灵敏度"
	sens_label.position = Vector2(34, 96)
	sens_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(sens_label)
	var sens: HSlider = HSlider.new()
	sens.position = Vector2(34, 124)
	sens.size = Vector2(400, 24)
	sens.min_value = 0.2
	sens.max_value = 3.0
	sens.step = 0.05
	sens.value = float(profile.settings.get("mouse_sensitivity", 1.0))
	panel.add_child(sens)
	sens.value_changed.connect(func(v: float) -> void:
		profile.settings["mouse_sensitivity"] = v
		if player != null and is_instance_valid(player):
			player.sensitivity = v
	)

	var fov_label: Label = Label.new()
	fov_label.text = "视野角度"
	fov_label.position = Vector2(34, 168)
	fov_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(fov_label)
	var fov: HSlider = HSlider.new()
	fov.position = Vector2(34, 196)
	fov.size = Vector2(400, 24)
	fov.min_value = 65.0
	fov.max_value = 105.0
	fov.step = 1.0
	fov.value = float(profile.settings.get("field_of_view", 78.0))
	panel.add_child(fov)
	fov.value_changed.connect(func(v: float) -> void:
		profile.settings["field_of_view"] = v
		if player != null and is_instance_valid(player) and is_instance_valid(player.camera):
			player.camera.fov = v
	)

	var tips: Label = Label.new()
	tips.text = "建造：Q 进入建造模式，左键按住可连续放板\n编辑：对准自己的墙按 F，左键开关格，F 确认\n简易模式：V 切换，放板更贴合近身"
	tips.position = Vector2(34, 240)
	tips.add_theme_font_size_override("font_size", 16)
	tips.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9))
	panel.add_child(tips)

	var resume: Button = Button.new()
	resume.text = "继续"
	resume.position = Vector2(34, 330)
	resume.size = Vector2(200, 50)
	resume.pressed.connect(_toggle_pause)
	panel.add_child(resume)

	var restart: Button = Button.new()
	restart.text = "重新开始"
	restart.position = Vector2(246, 330)
	restart.size = Vector2(188, 50)
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		profile.save()
		get_tree().reload_current_scene()
	)
	panel.add_child(restart)

	var quit: Button = Button.new()
	quit.text = "返回大厅"
	quit.position = Vector2(34, 392)
	quit.size = Vector2(400, 50)
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		profile.save()
		get_tree().reload_current_scene()
	)
	panel.add_child(quit)

func _unhandled_input(event: InputEvent) -> void:
	if not match_active or player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed("pause"):
		if player.build.is_editing():
			player.cancel_edit_mode()
			get_viewport().set_input_as_handled()
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	paused = not paused
	var panel: Node = pause_layer.get_node_or_null("Panel")
	if panel != null:
		(panel as ColorRect).visible = paused
	get_tree().paused = paused
	if player != null and is_instance_valid(player):
		player.set_ui_locked(paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if not paused:
		profile.save()
