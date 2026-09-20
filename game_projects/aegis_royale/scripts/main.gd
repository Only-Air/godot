extends Node3D

var player: RoyalePlayer
var storm: StormController
var map_generator: IslandMapGenerator
var lobby_layer: CanvasLayer
var world_started := false

func _ready() -> void:
	seed(Time.get_unix_time_from_system())
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
	feature.text = "落地搜刮与五槽物品栏\n三种材料采集与即时建造\n中央湖、河网与九个原创兴趣点\n普通 / 简易建造与编辑\n会搜刮、转点、治疗、搭建掩体和推进的 AI"
	feature.position = Vector2(75, 230)
	feature.add_theme_font_size_override("font_size", 24)
	background.add_child(feature)
	var play := Button.new()
	play.text = "开始离线演练"
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
	popup.dialog_text = "画面：兼容渲染器\n比赛：31 名战术 AI\n建造：比赛中按 V 切换简易模式\n辅助功能：高对比 HUD 已启用\n联网功能：关闭（完全离线）"
	popup.size = Vector2i(480, 300)
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
	player.position = _spawn_near_poi(0)
	add_child(player)
	for i in 31:
		var bot := TacticalBot.new()
		bot.position = _spawn_near_poi(i + 1)
		add_child(bot)
		bot.setup(Color.from_hsv(float(i) / 31.0, 0.6, 0.9), randf_range(0.28, 0.94))
	var hud := RoyaleHUD.new()
	add_child(hud)
	hud.setup(player, storm)

func _spawn_near_poi(index: int) -> Vector3:
	var poi: Dictionary = map_generator.poi_data[index % map_generator.poi_data.size()]
	var center: Vector3 = poi.position
	return center + Vector3(randf_range(-12, 12), 2.0, randf_range(-12, 12))
