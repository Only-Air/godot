extends Node3D

var player: RoyalePlayer
var storm: StormController
var map_generator: IslandMapGenerator
var drop_controller: DropController
var match_controller: MatchController
var profile := LocalProfile.new()
var lobby_layer: CanvasLayer
var world_started := false

func _ready() -> void:
	seed(Time.get_unix_time_from_system())
	profile.load_profile()
	_show_lobby()

func _show_lobby() -> void:
	lobby_layer = CanvasLayer.new()
	add_child(lobby_layer)
	var background := ColorRect.new()
	background.color = Color("172744")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lobby_layer.add_child(background)
	var title := Label.new()
	title.text = "AEGIS ROYALE"
	title.position = Vector2(70, 65)
	title.add_theme_font_size_override("font_size", 54)
	background.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "原创离线建造大逃杀 · 群岛行动"
	subtitle.position = Vector2(75, 132)
	subtitle.add_theme_font_size_override("font_size", 22)
	background.add_child(subtitle)
	var feature := Label.new()
	feature.text = "空中投放、滑翔与落点选择\n落地搜刮、五槽物品栏与三种材料\n中央湖、河网与九个原创兴趣点\n普通 / 简易建造与网格编辑\n会搜刮、转点、治疗、搭建掩体和推进的 AI"
	feature.position = Vector2(75, 220)
	feature.add_theme_font_size_override("font_size", 23)
	background.add_child(feature)
	var career := Label.new()
	career.text = "离线生涯：%d 场　%d 胜　最佳排名 #%d" % [int(profile.statistics.matches), int(profile.statistics.wins), int(profile.statistics.best_placement)]
	career.position = Vector2(75, 475)
	career.add_theme_font_size_override("font_size", 20)
	background.add_child(career)
	var play := Button.new()
	play.text = "开始离线比赛"
	play.position = Vector2(890, 515)
	play.size = Vector2(290, 64)
	play.add_theme_font_size_override("font_size", 25)
	play.pressed.connect(_start_match)
	background.add_child(play)
	var settings := Button.new()
	settings.text = "设置"
	settings.position = Vector2(890, 595)
	settings.size = Vector2(290, 48)
	settings.pressed.connect(_show_settings)
	background.add_child(settings)

func _show_settings() -> void:
	var popup := AcceptDialog.new()
	popup.title = "离线设置"
	popup.dialog_text = "画面：兼容渲染器\n比赛：%d 名战术 AI\nAI 难度：%.0f%%\n建造：比赛中按 V 切换简易模式\n本地档案：已启用\n联网功能：关闭（完全离线）" % [int(profile.settings.ai_count), float(profile.settings.ai_difficulty) * 100.0]
	popup.size = Vector2i(480, 330)
	lobby_layer.add_child(popup)
	popup.popup_centered()

func _start_match() -> void:
	if world_started: return
	world_started = true
	lobby_layer.queue_free()
	_create_world()

func _create_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("70a9d6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9d8ef")
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	map_generator = IslandMapGenerator.new()
	add_child(map_generator)
	map_generator.generate()
	storm = StormController.new()
	add_child(storm)
	player = RoyalePlayer.new()
	add_child(player)
	player.simple_build = bool(profile.settings.simple_build_default)
	player.simple_edit = bool(profile.settings.simple_edit_default)
	drop_controller = DropController.new()
	add_child(drop_controller)
	drop_controller.setup(player, Vector3(-88, 74, -88))
	var bot_count := clampi(int(profile.settings.ai_count), 7, 63)
	for i in bot_count:
		var bot := TacticalBot.new()
		bot.position = _spawn_near_poi(i)
		add_child(bot)
		var base_skill := float(profile.settings.ai_difficulty)
		bot.setup(Color.from_hsv(float(i) / float(bot_count), 0.6, 0.9), clampf(base_skill + randf_range(-0.28, 0.28), 0.2, 0.98))
	var hud := RoyaleHUD.new()
	add_child(hud)
	hud.setup(player, storm, drop_controller)
	match_controller = MatchController.new()
	add_child(match_controller)
	match_controller.setup(player, profile)

func _spawn_near_poi(index: int) -> Vector3:
	var poi: Dictionary = map_generator.poi_data[index % map_generator.poi_data.size()]
	var center: Vector3 = poi.position
	return center + Vector3(randf_range(-12, 12), 2.0, randf_range(-12, 12))
