class_name RoyaleHUD
extends CanvasLayer

var player: RoyalePlayer
var storm: StormController
var stats_label: Label
var storm_label: Label
var alive_label: Label
var inventory_label: Label
var crosshair: Label
var help_panel: ColorRect

func setup(controlled_player: RoyalePlayer, storm_controller: StormController) -> void:
	player = controlled_player
	storm = storm_controller
	_build_ui()
	player.stats_changed.connect(_refresh)

func _build_ui() -> void:
	stats_label = Label.new()
	stats_label.position = Vector2(24, 618)
	stats_label.add_theme_font_size_override("font_size", 20)
	add_child(stats_label)
	inventory_label = Label.new()
	inventory_label.position = Vector2(470, 642)
	inventory_label.add_theme_font_size_override("font_size", 18)
	add_child(inventory_label)
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
	help_panel.size = Vector2(380, 184)
	add_child(help_panel)
	var help := Label.new()
	help.position = Vector2(12, 9)
	help.text = "WASD 移动 / Shift 冲刺 / 空格跳跃\n左键射击、使用或建造　R 换弹　E 搜索\nQ 战斗/建造　1-4 物品槽或建造结构\nF 编辑己方结构　G 旋转　V 简易模式\n空物品槽左键可采集场景材料\n靠近发光战利品自动拾取"
	help_panel.add_child(help)
	_refresh()

func _process(_delta: float) -> void:
	if is_instance_valid(storm): storm_label.text = storm.status_text()
	alive_label.text = "存活 %d" % get_tree().get_nodes_in_group("combatants").size()

func _refresh() -> void:
	if not is_instance_valid(player): return
	var mode := "建造" if player.build_mode else "战斗"
	var simple := "简易：开" if player.simple_build else "简易：关"
	var selected := player.inventory.selected()
	var item_text := "采集工具"
	var ammo_text := ""
	if selected.get("kind", "") == "weapon":
		item_text = "%s（%s）" % [selected.name, ItemDatabase.RARITY[selected.rarity].label]
		ammo_text = "　弹药 %d/%d" % [int(selected.loaded), int(player.inventory.ammo[selected.ammo])]
	elif selected.get("kind", "") == "consumable":
		item_text = "%s ×%d" % [selected.name, int(selected.quantity)]
	stats_label.text = "生命 %.0f　护盾 %.0f　%s%s\n木 %d　石 %d　金属 %d　%s　%s" % [player.health, player.shield, item_text, ammo_text, int(player.inventory.resources.wood), int(player.inventory.resources.stone), int(player.inventory.resources.metal), mode, simple]
	var slot_parts: Array[String] = []
	for i in player.inventory.slots.size():
		var slot := player.inventory.slots[i]
		var label := "空"
		if not slot.is_empty(): label = slot.get("name", "物品")
		var marker := ">" if i == player.inventory.selected_slot else " "
		slot_parts.append("%s%d:%s" % [marker, i + 1, label])
	inventory_label.text = "　".join(slot_parts)
