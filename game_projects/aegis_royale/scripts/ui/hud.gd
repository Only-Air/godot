class_name HUD
extends CanvasLayer

## Single-pass canvas HUD: vitals, slots, materials, storm, minimap,
## dynamic crosshair, build panel, edit grid overlay, damage numbers.

var player: PlayerController
var storm: Storm
var world: Node3D
var canvas: HudCanvas
var build_registry: Dictionary = {}
var alive_total: int = 32
var kill_feed: Array = []
var edit_piece_ref: BuildPiece = null

func setup(p_player: PlayerController, p_storm: Storm, p_world: Node3D, p_registry: Dictionary) -> void:
	player = p_player
	storm = p_storm
	world = p_world
	build_registry = p_registry
	canvas = HudCanvas.new()
	canvas.hud = self
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	player.hit_confirm.connect(_on_hit)

func _on_hit(amount: float, critical: bool) -> void:
	if canvas == null:
		return
	var point: Vector3 = player.last_hit_point if player.last_hit_valid else player.global_position
	canvas.damage_numbers.append({
		"world": point,
		"value": amount,
		"crit": critical,
		"life": 0.85,
	})

func push_kill(killer: String, victim: String) -> void:
	kill_feed.append({"killer": killer, "victim": victim, "life": 5.0})
	if kill_feed.size() > 5:
		kill_feed.pop_front()

func _process(delta: float) -> void:
	if canvas != null:
		canvas.tick(delta)

# ---------------------------------------------------------------------------

class HudCanvas extends Control:
	var hud: HUD
	var damage_numbers: Array = []
	var hit_flash: float = 0.0
	var hurt_flash: float = 0.0

	func tick(delta: float) -> void:
		for i: int in range(damage_numbers.size() - 1, -1, -1):
			var d: Dictionary = damage_numbers[i]
			d["life"] = float(d["life"]) - delta
			if float(d["life"]) <= 0.0:
				damage_numbers.remove_at(i)
		hit_flash = maxf(0.0, hit_flash - delta * 3.0)
		for i: int in range(hud.kill_feed.size() - 1, -1, -1):
			var k: Dictionary = hud.kill_feed[i]
			k["life"] = float(k["life"]) - delta
			if float(k["life"]) <= 0.0:
				hud.kill_feed.remove_at(i)
		var p: Actor = hud.player
		if p != null and is_instance_valid(p) and p.time_since_damage() < 0.25:
			hurt_flash = 1.0
		hurt_flash = maxf(0.0, hurt_flash - delta * 2.2)
		queue_redraw()

	func _text(txt: String, pos: Vector2, fsize: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(txt, align, -1, fsize).x
		var x: float = pos.x
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x = pos.x - w * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			x = pos.x - w
		draw_string(font, Vector2(x, pos.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

	func _panel(rect: Rect2, col: Color, border: Color = Color(0, 0, 0, 0)) -> void:
		draw_rect(rect, col, true)
		if border.a > 0.0:
			draw_rect(rect, border, false, 2.0)

	func _draw() -> void:
		var vp: Vector2 = size
		if hud.player == null or not is_instance_valid(hud.player):
			return
		var p: PlayerController = hud.player
		if hurt_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.75, 0.05, 0.05, hurt_flash * 0.22), true)
		_draw_minimap(vp)
		_draw_storm_bar(vp)
		_draw_vitals(vp, p)
		_draw_slots(vp, p)
		_draw_materials(vp, p)
		_draw_crosshair(vp, p)
		_draw_damage_numbers(vp)
		_draw_kill_feed(vp)
		if p.build_mode:
			_draw_build_panel(vp, p)
		if p.build.is_editing():
			_draw_edit_overlay(p)
		if p.is_dead:
			_text("已被淘汰", Vector2(vp.x * 0.5, vp.y * 0.45), 46, Color("ff6b6b"), HORIZONTAL_ALIGNMENT_CENTER)
			_text("按 Esc 查看结算", Vector2(vp.x * 0.5, vp.y * 0.45 + 40.0), 20, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)

	# ------------------------------------------------------------- elements

	func _draw_vitals(vp: Vector2, p: Actor) -> void:
		var x: float = 40.0
		var y: float = vp.y - 118.0
		var w: float = 330.0
		var h: float = 22.0
		_text("%s" % p.display_name, Vector2(x, y - 12.0), 17, Color(1, 1, 1, 0.75))
		_panel(Rect2(x - 2.0, y - 2.0, w + 4.0, h + 4.0), Color(0.02, 0.03, 0.05, 0.62))
		var shield_ratio: float = clampf(p.shield / maxf(p.max_shield, 1.0), 0.0, 1.0)
		var health_ratio: float = clampf(p.health / maxf(p.max_health, 1.0), 0.0, 1.0)
		draw_rect(Rect2(x, y, w * shield_ratio, h * 0.42), Color("4fc3f7"), true)
		draw_rect(Rect2(x, y + h * 0.44, w * health_ratio, h * 0.56), Color("5fd97a") if health_ratio > 0.35 else Color("e0603c"), true)
		_text("%d" % int(ceil(p.health)), Vector2(x + w + 12.0, y + h * 0.86), 20, Color.WHITE)
		_text("护盾 %d" % int(p.shield), Vector2(x, y + h + 20.0), 15, Color(1, 1, 1, 0.8))

	func _draw_slots(vp: Vector2, p: Actor) -> void:
		var count: int = p.slots.size()
		var box: float = 92.0
		var gap: float = 8.0
		var total: float = float(count) * box + float(count - 1) * gap
		var x0: float = (vp.x - total) * 0.5
		var y: float = vp.y - 108.0
		for i: int in count:
			var slot: Dictionary = p.slots[i]
			var x: float = x0 + float(i) * (box + gap)
			var selected: bool = i == p.active_slot
			var bg: Color = Color(0.05, 0.07, 0.1, 0.72)
			var border: Color = Color(1, 1, 1, 0.22)
			if not slot.is_empty():
				var rc: Color = slot.get("rarity_color", Color(0.7, 0.8, 0.9))
				if rc is Color:
					border = rc
					bg = Color(rc.r * 0.22, rc.g * 0.22, rc.b * 0.22, 0.8)
			if selected:
				bg = Color(bg.r + 0.14, bg.g + 0.14, bg.b + 0.14, 0.9)
			_panel(Rect2(x, y, box, box * 0.72), bg, border)
			_text("%d" % (i + 1), Vector2(x + 8.0, y + 18.0), 14, Color(1, 1, 1, 0.6))
			if slot.is_empty():
				continue
			var label: String = String(slot.get("name", ""))
			if label.length() > 6:
				label = label.substr(0, 6)
			_text(label, Vector2(x + box * 0.5, y + box * 0.44), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			if String(slot.get("kind", "")) == "weapon":
				_text("%d / %d" % [int(slot.get("loaded", 0)), int(p.ammo.get(String(slot.get("ammo", "medium")), 0))],
					Vector2(x + box * 0.5, y + box * 0.64), 13, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
			elif String(slot.get("kind", "")) == "consumable":
				_text("x%d" % int(slot.get("amount", 0)),
					Vector2(x + box * 0.5, y + box * 0.64), 13, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
		if p.is_reloading():
			_text("换弹中…", Vector2(vp.x * 0.5, y - 14.0), 18, Color("ffd166"), HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_materials(vp: Vector2, p: Actor) -> void:
		var x: float = vp.x - 320.0
		var y: float = vp.y - 96.0
		_panel(Rect2(x - 12.0, y - 26.0, 300.0, 96.0), Color(0.03, 0.05, 0.08, 0.6))
		var items: Array = [["木材", "wood", Color("b98a52")], ["石材", "stone", Color("9299a2")], ["金属", "metal", Color("6f849a")]]
		for i: int in items.size():
			var row: Array = items[i]
			var ry: float = y + float(i) * 26.0
			draw_rect(Rect2(x - 4.0, ry - 14.0, 16.0, 16.0), row[2], true)
			_text("%s  %d" % [row[0], int(p.resources.get(row[1], 0))], Vector2(x + 22.0, ry), 17, Color.WHITE)
		_text("建造材料 (Z 切换)", Vector2(x - 4.0, y - 34.0), 13, Color(1, 1, 1, 0.5))

	func _draw_storm_bar(vp: Vector2) -> void:
		if hud.storm == null or not is_instance_valid(hud.storm):
			return
		var s: Storm = hud.storm
		var cx: float = vp.x * 0.5
		_panel(Rect2(cx - 150.0, 18.0, 300.0, 62.0), Color(0.06, 0.04, 0.12, 0.62))
		var label: String = "阶段 %d · %s" % [s.phase + 1, s.phase_label()]
		_text(label, Vector2(cx, 42.0), 18, Color(0.86, 0.72, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		var t: float = s.seconds_left()
		var time_col: Color = Color("ff8f6b") if t < 10.0 else Color.WHITE
		_text("%02d:%02d" % [int(t) / 60, int(t) % 60], Vector2(cx, 70.0), 24, time_col, HORIZONTAL_ALIGNMENT_CENTER)
		_text("存活 %d" % hud.alive_total, Vector2(vp.x - 40.0, 44.0), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)

	func _draw_minimap(vp: Vector2) -> void:
		var box: float = 210.0
		var origin: Vector2 = Vector2(vp.x - box - 34.0, 104.0)
		_panel(Rect2(origin, Vector2(box, box)), Color(0.04, 0.07, 0.11, 0.72), Color(1, 1, 1, 0.18))
		var p: Actor = hud.player
		var scale: float = 0.42
		var center: Vector2 = origin + Vector2(box, box) * 0.5
		draw_rect(Rect2(origin + Vector2(2, 2), Vector2(box - 4, box - 4)), Color(0.18, 0.34, 0.22, 0.35), true)
		var clip: Rect2 = Rect2(origin + Vector2(2, 2), Vector2(box - 4, box - 4))
		draw_set_transform(center, 0.0, Vector2.ONE)
		if hud.storm != null and is_instance_valid(hud.storm):
			var s: Storm = hud.storm
			var sc: Vector2 = Vector2((s.center.x - p.global_position.x) * scale, (s.center.z - p.global_position.z) * scale)
			draw_arc(sc, s.radius * scale, 0.0, TAU, 64, Color(0.72, 0.42, 1.0, 0.9), 2.0)
			draw_arc(sc, s.target_radius * scale, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.35), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for poi in MapBuilder.poi_definitions():
			var pd: Dictionary = poi
			var mp: Vector2 = center + Vector2((float(pd["x"]) - p.global_position.x) * scale, (float(pd["z"]) - p.global_position.z) * scale)
			if not clip.has_point(mp):
				continue
			draw_circle(mp, 3.5, Color(0.95, 0.85, 0.5, 0.85))
		draw_circle(center, 5.0, Color("63b3ff"))
		var fwd: Vector2 = Vector2(-sin(p.yaw), -cos(p.yaw)) * 11.0
		draw_line(center, center + fwd, Color("63b3ff"), 3.0)
		_text("N", origin + Vector2(box * 0.5, 14.0), 13, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_crosshair(vp: Vector2, p: Actor) -> void:
		var c: Vector2 = vp * 0.5
		var spread: float = clampf(p.aim_spread() * 2400.0, 5.0, 90.0)
		var col: Color = Color(1, 1, 1, 0.9)
		var len: float = 9.0
		var thick: float = 2.0
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + dir * spread, c + dir * (spread + len), col, thick)
		draw_circle(c, 1.6, Color(1, 1, 1, 0.85))
		if p.current_weapon().is_empty():
			draw_arc(c, 16.0, 0.0, TAU, 24, Color(1, 1, 1, 0.4), 1.5)
		if hit_flash > 0.0:
			var hc: Color = Color(1, 0.85, 0.3, hit_flash)
			draw_line(c + Vector2(-11, -11), c + Vector2(-4, -4), hc, 3.0)
			draw_line(c + Vector2(11, -11), c + Vector2(4, -4), hc, 3.0)
			draw_line(c + Vector2(-11, 11), c + Vector2(-4, 4), hc, 3.0)
			draw_line(c + Vector2(11, 11), c + Vector2(4, 4), hc, 3.0)

	func _draw_damage_numbers(vp: Vector2) -> void:
		var cam: Camera3D = hud.player.camera
		if cam == null or not is_instance_valid(cam):
			return
		for d in damage_numbers:
			var dd: Dictionary = d
			var life: float = float(dd["life"])
			var wp: Vector3 = dd["world"]
			var sp: Vector2 = cam.unproject_position(wp + Vector3.UP * (1.0 - life) * 1.2)
			if sp.x < -100.0 or sp.x > vp.x + 100.0:
				continue
			var alpha: float = clampf(life / 0.85, 0.0, 1.0)
			var crit: bool = bool(dd["crit"])
			var col: Color = Color(1.0, 0.82, 0.25, alpha) if crit else Color(1, 1, 1, alpha)
			var fs: int = 30 if crit else 24
			_text("%d" % int(round(float(dd["value"]))), sp, fs, col, HORIZONTAL_ALIGNMENT_CENTER)
			if crit:
				_text("爆头", sp + Vector2(0, 20), 14, Color(1.0, 0.6, 0.2, alpha), HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_kill_feed(vp: Vector2) -> void:
		var y: float = 100.0
		for k in hud.kill_feed:
			var kd: Dictionary = k
			var alpha: float = clampf(float(kd["life"]) / 5.0, 0.0, 1.0)
			var txt: String = "%s  淘汰  %s" % [kd["killer"], kd["victim"]]
			_text(txt, Vector2(40.0, y), 17, Color(1, 1, 1, alpha * 0.9))
			y += 24.0

	func _draw_build_panel(vp: Vector2, p: PlayerController) -> void:
		var names: Array = [["墙", "wall", "1"], ["地板", "floor", "2"], ["斜坡", "ramp", "3"], ["锥顶", "cone", "4"]]
		var box: float = 64.0
		var x: float = vp.x - 108.0
		var y0: float = vp.y * 0.5 - (float(names.size()) * (box + 8.0)) * 0.5
		for i: int in names.size():
			var row: Array = names[i]
			var y: float = y0 + float(i) * (box + 8.0)
			var active: bool = String(row[1]) == p.build.piece_type
			var bg: Color = Color(0.10, 0.35, 0.6, 0.85) if active else Color(0.05, 0.08, 0.12, 0.7)
			_panel(Rect2(x, y, box, box), bg, Color(1, 1, 1, 0.3) if active else Color(1, 1, 1, 0.12))
			_text(String(row[0]), Vector2(x + box * 0.5, y + box * 0.5 + 6.0), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			_text(String(row[2]), Vector2(x + box * 0.5, y + box - 6.0), 12, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		var info_y: float = y0 + float(names.size()) * (box + 8.0) + 8.0
		var mat_name: String = {"wood": "木材", "stone": "石材", "metal": "金属"}.get(p.build.mat_type, "木材")
		_text("建材: %s" % mat_name, Vector2(x + box * 0.5, info_y + 16.0), 15, Color("ffd166"), HORIZONTAL_ALIGNMENT_CENTER)
		var mode: String = "简易" if p.simple_mode else "普通"
		_text("模式: %s (V)" % mode, Vector2(x + box * 0.5, info_y + 36.0), 13, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		if not p.build.preview_valid:
			var reason: String = p.build.last_fail_reason
			if reason != "":
				_text(reason, Vector2(vp.x * 0.5, vp.y * 0.5 + 70.0), 18, Color("ff8080"), HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_edit_overlay(p: PlayerController) -> void:
		var piece: BuildPiece = p.build.edit_piece
		if piece == null or not is_instance_valid(piece):
			return
		var cam: Camera3D = p.camera
		if cam == null:
			return
		var half_w: float = BuildPiece.CELL * 0.5
		var corners: Array = []
		for row: int in 4:
			var row_pts: Array = []
			for col: int in 4:
				var lx: float = -half_w + float(col) * BuildPiece.TILE_W
				var ly: float = BuildPiece.LEVEL - float(row) * BuildPiece.TILE_H
				var wp: Vector3 = piece.to_global(Vector3(lx, ly, 0.0))
				row_pts.append(cam.unproject_position(wp))
			corners.append(row_pts)
		for row: int in 4:
			var pts: Array = corners[row]
			for col: int in 3:
				draw_line(pts[col], pts[col + 1], Color(0.4, 0.95, 1.0, 0.55), 2.0)
		for col: int in 4:
			for row: int in 3:
				var a: Vector2 = corners[row][col]
				var b: Vector2 = corners[row + 1][col]
				draw_line(a, b, Color(0.4, 0.95, 1.0, 0.55), 2.0)
		var hover: int = p.build.edit_tile
		if hover >= 0 and hover < 9:
			var hr: int = hover / 3
			var hc: int = hover % 3
			var tl: Vector2 = corners[hr][hc]
			var tr: Vector2 = corners[hr][hc + 1]
			var br: Vector2 = corners[hr + 1][hc + 1]
			var bl: Vector2 = corners[hr + 1][hc]
			draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), Color(1.0, 0.9, 0.3, 0.28))
			draw_line(tl, tr, Color(1, 0.9, 0.3, 0.95), 2.5)
			draw_line(tr, br, Color(1, 0.9, 0.3, 0.95), 2.5)
			draw_line(br, bl, Color(1, 0.9, 0.3, 0.95), 2.5)
			draw_line(bl, tl, Color(1, 0.9, 0.3, 0.95), 2.5)
		_text("编辑模式：左键开关格 · F 确认 · Esc 取消", Vector2(size.x * 0.5, size.y - 160.0), 17, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
