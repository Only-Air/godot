extends Node3D

var player: RoyalePlayer
var storm: StormController
var lobby_layer: CanvasLayer
var world_started := false

func _ready() -> void:
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
	subtitle.text = "原创战术大逃杀原型 · 群岛行动"
	subtitle.position = Vector2(75, 132)
	subtitle.add_theme_font_size_override("font_size", 22)
	background.add_child(subtitle)
	var feature := Label.new()
	feature.text = "第三人称战斗\n动态风暴圈\n模块化建造与编辑\n简易建造 / 简易编辑\n会搭建掩体与包围走位的战术 AI"
	feature.position = Vector2(75, 230)
	feature.add_theme_font_size_override("font_size", 24)
	background.add_child(feature)
	var play := Button.new()
	play.text = "开始单人演练"
	play.position = Vector2(890, 515)
	play.size = Vector2(290, 64)
	play.add_theme_font_size_override("font_size", 25)
	play.pressed.connect(_start_match)
	background.add_child(play)
	var settings := Button.new()
	settings.text = "设置（原型）"
	settings.position = Vector2(890, 595)
	settings.size = Vector2(290, 48)
	settings.pressed.connect(_show_settings)
	background.add_child(settings)

func _show_settings() -> void:
	var popup := AcceptDialog.new()
	popup.title = "设置"
	popup.dialog_text = "画面：兼容渲染器\n鼠标灵敏度：默认\n建造设置：比赛中按 V 切换简易模式\n辅助功能：高对比 HUD 已启用"
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
	_create_island()
	player = RoyalePlayer.new()
	player.position = Vector3(0, 2, 36)
	add_child(player)
	storm = StormController.new()
	add_child(storm)
	for i in 15:
		var bot := TacticalBot.new()
		bot.position = Vector3(randf_range(-82, 82), 2, randf_range(-82, 82))
		add_child(bot)
		bot.setup(Color.from_hsv(float(i) / 15.0, 0.6, 0.9), randf_range(0.35, 0.9))
	var hud := RoyaleHUD.new()
	add_child(hud)
	hud.setup(player, storm)

func _create_island() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 2
	add_child(ground)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 112.0
	cylinder.bottom_radius = 118.0
	cylinder.height = 3.0
	cylinder.radial_segments = 64
	mesh.mesh = cylinder
	mesh.position.y = -1.5
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("4e8b55")
	ground_mat.roughness = 1.0
	mesh.material_override = ground_mat
	ground.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 112.0
	shape.height = 3.0
	collider.shape = shape
	collider.position.y = -1.5
	ground.add_child(collider)
	for i in 28:
		_create_landmark(Vector3(randf_range(-90, 90), 0, randf_range(-90, 90)), i)

func _create_landmark(pos: Vector3, index: int) -> void:
	if Vector2(pos.x, pos.z).length() > 98.0: return
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(randf_range(5, 12), randf_range(3, 10), randf_range(5, 12))
	mesh.mesh = box
	mesh.position.y = box.size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = [Color("d67c5c"), Color("d4bd67"), Color("6da4a8"), Color("876ba8")][index % 4]
	mesh.material_override = mat
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	collision.position.y = box.size.y * 0.5
	body.add_child(collision)
