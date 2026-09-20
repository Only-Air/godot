class_name WeaponDB
extends RefCounted

## Original weapon pool. Stats are tuned for distinct roles rather than
## copied from any existing game.

const RARITY: Array[Dictionary] = [
	{"id": "common", "label": "普通", "color": Color("b6bfc9"), "power": 1.00},
	{"id": "uncommon", "label": "优秀", "color": Color("5ec46b"), "power": 1.06},
	{"id": "rare", "label": "稀有", "color": Color("3d8ef7"), "power": 1.12},
	{"id": "epic", "label": "史诗", "color": Color("a75cf5"), "power": 1.19},
	{"id": "legendary", "label": "传奇", "color": Color("f2a03c"), "power": 1.26},
	{"id": "mythic", "label": "特制", "color": Color("f5d94a"), "power": 1.34},
]

const WEAPONS: Dictionary = {
	"vanguard_ar": {
		"name": "先锋步枪", "kind": "rifle", "ammo": "medium", "damage": 31.0, "rpm": 330.0,
		"mag": 30, "reload": 2.30, "spread": 0.0140, "move_spread": 1.9, "recoil": 0.0115,
		"falloff_start": 55.0, "falloff_end": 140.0, "min_mult": 0.66, "structure_mult": 1.0,
		"auto": true, "velocity": 220.0, "color": Color("4fa3f0"),
	},
	"trident_burst": {
		"name": "三叉点射步枪", "kind": "rifle", "ammo": "medium", "damage": 30.0, "rpm": 420.0,
		"burst": 3, "mag": 24, "reload": 2.45, "spread": 0.0105, "move_spread": 1.7, "recoil": 0.0135,
		"falloff_start": 58.0, "falloff_end": 138.0, "min_mult": 0.68, "structure_mult": 1.0,
		"auto": false, "velocity": 240.0, "color": Color("9b7bf5"),
	},
	"breacher_pump": {
		"name": "破阵泵动霰弹枪", "kind": "shotgun", "ammo": "shells", "damage": 22.0, "pellets": 9,
		"rpm": 62.0, "mag": 5, "reload": 4.30, "spread": 0.070, "move_spread": 1.25, "recoil": 0.048,
		"falloff_start": 7.0, "falloff_end": 24.0, "min_mult": 0.30, "structure_mult": 1.25,
		"auto": false, "velocity": 150.0, "color": Color("6cc96f"),
	},
	"striker_auto": {
		"name": "强袭战术霰弹枪", "kind": "shotgun", "ammo": "shells", "damage": 16.0, "pellets": 9,
		"rpm": 88.0, "mag": 8, "reload": 4.80, "spread": 0.084, "move_spread": 1.2, "recoil": 0.036,
		"falloff_start": 6.0, "falloff_end": 22.0, "min_mult": 0.32, "structure_mult": 1.10,
		"auto": true, "velocity": 150.0, "color": Color("7ad2a0"),
	},
	"cyclone_smg": {
		"name": "旋风冲锋枪", "kind": "smg", "ammo": "light", "damage": 18.0, "rpm": 690.0,
		"mag": 30, "reload": 2.10, "spread": 0.0320, "move_spread": 1.15, "recoil": 0.0125,
		"falloff_start": 22.0, "falloff_end": 66.0, "min_mult": 0.52, "structure_mult": 1.20,
		"auto": true, "velocity": 190.0, "color": Color("54ddc0"),
	},
	"whisper_smg": {
		"name": "低语消音冲锋枪", "kind": "smg", "ammo": "light", "damage": 20.0, "rpm": 540.0,
		"mag": 30, "reload": 2.00, "spread": 0.0210, "move_spread": 1.10, "recoil": 0.0100,
		"falloff_start": 26.0, "falloff_end": 72.0, "min_mult": 0.55, "structure_mult": 1.05,
		"auto": true, "velocity": 200.0, "suppressed": true, "color": Color("8fb6c9"),
	},
	"service_pistol": {
		"name": "制式手枪", "kind": "pistol", "ammo": "light", "damage": 26.0, "rpm": 400.0,
		"mag": 16, "reload": 1.55, "spread": 0.0190, "move_spread": 1.35, "recoil": 0.0180,
		"falloff_start": 30.0, "falloff_end": 88.0, "min_mult": 0.60, "structure_mult": 0.80,
		"auto": false, "velocity": 180.0, "color": Color("e0c46a"),
	},
	"shadow_pistol": {
		"name": "暗影消音手枪", "kind": "pistol", "ammo": "light", "damage": 29.0, "rpm": 350.0,
		"mag": 12, "reload": 1.45, "spread": 0.0120, "move_spread": 1.20, "recoil": 0.0150,
		"falloff_start": 34.0, "falloff_end": 95.0, "min_mult": 0.62, "structure_mult": 0.80,
		"auto": false, "velocity": 190.0, "suppressed": true, "color": Color("7f8ea8"),
	},
	"sentinel_bolt": {
		"name": "哨兵栓动狙击枪", "kind": "sniper", "ammo": "heavy", "damage": 104.0, "rpm": 31.0,
		"mag": 1, "reload": 2.85, "spread": 0.0016, "move_spread": 3.4, "recoil": 0.0600,
		"falloff_start": 200.0, "falloff_end": 400.0, "min_mult": 0.95, "structure_mult": 1.0,
		"auto": false, "velocity": 420.0, "scope": 3.0, "color": Color("d8d2c0"),
	},
	"siege_sniper": {
		"name": "攻城重型狙击枪", "kind": "sniper", "ammo": "heavy", "damage": 132.0, "rpm": 20.0,
		"mag": 1, "reload": 4.05, "spread": 0.0010, "move_spread": 3.8, "recoil": 0.0700,
		"falloff_start": 220.0, "falloff_end": 440.0, "min_mult": 0.95, "structure_mult": 3.5,
		"auto": false, "velocity": 440.0, "scope": 3.6, "color": Color("c9a05c"),
	},
	"bastion_lmg": {
		"name": "壁垒轻机枪", "kind": "lmg", "ammo": "medium", "damage": 25.0, "rpm": 480.0,
		"mag": 60, "reload": 4.70, "spread": 0.0400, "move_spread": 2.2, "recoil": 0.0150,
		"falloff_start": 45.0, "falloff_end": 110.0, "min_mult": 0.62, "structure_mult": 1.45,
		"auto": true, "velocity": 210.0, "color": Color("b07a4a"),
	},
	"comet_launcher": {
		"name": "彗星发射器", "kind": "explosive", "ammo": "rockets", "damage": 92.0, "rpm": 19.0,
		"mag": 1, "reload": 3.00, "spread": 0.0020, "move_spread": 1.0, "recoil": 0.0500,
		"falloff_start": 400.0, "falloff_end": 500.0, "min_mult": 1.0, "structure_mult": 2.2,
		"auto": false, "velocity": 46.0, "projectile": true, "splash": 5.5, "splash_damage": 92.0,
		"color": Color("f07a3c"),
	},
}

const AMMO_START: Dictionary = {"light": 42, "medium": 36, "shells": 10, "heavy": 4, "rockets": 1}
const AMMO_MAX: Dictionary = {"light": 999, "medium": 999, "shells": 999, "heavy": 999, "rockets": 999}

const CONSUMABLES: Dictionary = {
	"bandage": {"name": "绷带", "stack": 15, "use_time": 2.6, "health": 15.0, "health_cap": 75.0, "color": Color("e8e2d0")},
	"medkit": {"name": "医疗包", "stack": 3, "use_time": 7.5, "health": 100.0, "health_cap": 100.0, "color": Color("e05c5c")},
	"mini_shield": {"name": "小型护盾剂", "stack": 6, "use_time": 2.0, "shield": 25.0, "shield_cap": 50.0, "color": Color("5cc8e8")},
	"shield_tonic": {"name": "大型护盾剂", "stack": 3, "use_time": 4.8, "shield": 50.0, "shield_cap": 100.0, "color": Color("4f8ce8")},
	"renewal_mix": {"name": "复合恢复饮料", "stack": 2, "use_time": 9.5, "health": 100.0, "shield": 100.0, "health_cap": 100.0, "shield_cap": 100.0, "color": Color("a86ce8")},
}

static func rarity(index: int) -> Dictionary:
	return RARITY[clampi(index, 0, RARITY.size() - 1)]

static func rarity_index_of(id: String) -> int:
	for i: int in RARITY.size():
		if String(RARITY[i]["id"]) == id:
			return i
	return 0

static func make(id: String, rarity_index: int = 0) -> Dictionary:
	var base: Dictionary = WEAPONS.get(id, WEAPONS["vanguard_ar"])
	var w: Dictionary = base.duplicate(true)
	var r: Dictionary = rarity(rarity_index)
	w["id"] = id
	w["rarity"] = rarity_index
	w["rarity_label"] = String(r["label"])
	w["rarity_color"] = r["color"]
	var power: float = float(r["power"])
	w["damage"] = float(w["damage"]) * power
	w["reload"] = float(w["reload"]) / lerpf(1.0, power, 0.6)
	if w.has("splash_damage"):
		w["splash_damage"] = float(w["splash_damage"]) * power
	w["loaded"] = int(w["mag"])
	return w

static func random_id() -> String:
	var ids: Array = WEAPONS.keys()
	return String(ids[randi() % ids.size()])

static func roll_rarity_index(max_index: int = 4) -> int:
	var roll: float = randf()
	var idx: int = 0
	if roll < 0.38: idx = 0
	elif roll < 0.66: idx = 1
	elif roll < 0.85: idx = 2
	elif roll < 0.96: idx = 3
	else: idx = 4
	return mini(idx, max_index)

static func random_weapon(max_rarity: int = 4) -> Dictionary:
	return make(random_id(), roll_rarity_index(max_rarity))

static func score(w: Dictionary) -> float:
	if w.is_empty():
		return 0.0
	var dps: float = float(w.get("damage", 0.0)) * float(w.get("rpm", 1.0)) / 60.0
	var pellets: int = int(w.get("pellets", 1))
	var mag: int = int(w.get("mag", 1))
	var burst: int = int(w.get("burst", 1))
	return dps * float(pellets) * float(burst) * (0.8 + 0.2 * float(mag) / 30.0)

static func role_distance(w: Dictionary) -> float:
	match String(w.get("kind", "rifle")):
		"shotgun": return 7.0
		"smg": return 14.0
		"pistol": return 16.0
		"sniper": return 60.0
		"lmg": return 26.0
		"explosive": return 30.0
		_: return 24.0
