class_name ItemDatabase
extends RefCounted

const RARITY := {
	"common": {"label":"普通", "color":Color("b9c0c8"), "power":1.00},
	"uncommon": {"label":"优秀", "color":Color("58c66a"), "power":1.05},
	"rare": {"label":"稀有", "color":Color("3d91ff"), "power":1.10},
	"epic": {"label":"史诗", "color":Color("a45cff"), "power":1.16},
	"legendary": {"label":"传奇", "color":Color("f2a43b"), "power":1.22},
	"mythic": {"label":"特制", "color":Color("f2d14b"), "power":1.28}
}

const WEAPONS := {
	"vanguard_ar": {"name":"先锋步枪", "class":"assault", "ammo":"medium", "damage":30.0, "fire_rate":5.5, "magazine":30, "reload":2.35, "range":145.0, "spread":0.014, "move_spread":1.55, "recoil":0.010, "falloff_start":55.0, "falloff_end":135.0, "min_damage_mult":0.67, "structure_mult":1.0},
	"trident_burst": {"name":"三叉点射步枪", "class":"assault", "ammo":"medium", "damage":29.0, "fire_rate":7.2, "burst":3, "magazine":24, "reload":2.45, "range":138.0, "spread":0.011, "move_spread":1.45, "recoil":0.012, "falloff_start":58.0, "falloff_end":132.0, "min_damage_mult":0.7, "structure_mult":1.0},
	"breacher_pump": {"name":"破阵泵动霰弹枪", "class":"shotgun", "ammo":"shells", "damage":21.0, "pellets":8, "fire_rate":0.72, "magazine":5, "reload":4.4, "range":27.0, "spread":0.075, "move_spread":1.18, "recoil":0.035, "falloff_start":8.0, "falloff_end":25.0, "min_damage_mult":0.35, "structure_mult":1.15},
	"striker_auto": {"name":"强袭战术霰弹枪", "class":"shotgun", "ammo":"shells", "damage":15.5, "pellets":8, "fire_rate":1.45, "magazine":8, "reload":4.8, "range":25.0, "spread":0.09, "move_spread":1.15, "recoil":0.026, "falloff_start":7.0, "falloff_end":23.0, "min_damage_mult":0.38, "structure_mult":1.05},
	"cyclone_smg": {"name":"旋风冲锋枪", "class":"smg", "ammo":"light", "damage":18.0, "fire_rate":11.2, "magazine":30, "reload":2.15, "range":65.0, "spread":0.032, "move_spread":1.35, "recoil":0.007, "falloff_start":20.0, "falloff_end":60.0, "min_damage_mult":0.55, "structure_mult":1.2},
	"whisper_smg": {"name":"低语消音冲锋枪", "class":"smg", "ammo":"light", "damage":20.0, "fire_rate":8.8, "magazine":30, "reload":2.05, "range":72.0, "spread":0.021, "move_spread":1.25, "recoil":0.006, "falloff_start":24.0, "falloff_end":68.0, "min_damage_mult":0.58, "structure_mult":1.05, "suppressed":true},
	"service_pistol": {"name":"制式手枪", "class":"pistol", "ammo":"light", "damage":26.0, "fire_rate":6.6, "magazine":16, "reload":1.55, "range":85.0, "spread":0.019, "move_spread":1.35, "recoil":0.012, "falloff_start":28.0, "falloff_end":80.0, "min_damage_mult":0.6, "structure_mult":0.8},
	"shadow_pistol": {"name":"暗影消音手枪", "class":"pistol", "ammo":"light", "damage":28.0, "fire_rate":5.8, "magazine":12, "reload":1.45, "range":92.0, "spread":0.012, "move_spread":1.22, "recoil":0.010, "falloff_start":32.0, "falloff_end":88.0, "min_damage_mult":0.64, "structure_mult":0.8, "suppressed":true},
	"sentinel_bolt": {"name":"哨兵栓动狙击枪", "class":"sniper", "ammo":"heavy", "damage":105.0, "fire_rate":0.52, "magazine":1, "reload":2.85, "range":320.0, "spread":0.0015, "move_spread":5.0, "recoil":0.055, "falloff_start":210.0, "falloff_end":320.0, "min_damage_mult":0.82, "structure_mult":1.0},
	"siege_sniper": {"name":"攻城重型狙击枪", "class":"sniper", "ammo":"heavy", "damage":132.0, "fire_rate":0.34, "magazine":1, "reload":4.05, "range":350.0, "spread":0.001, "move_spread":5.5, "recoil":0.065, "falloff_start":235.0, "falloff_end":350.0, "min_damage_mult":0.86, "structure_mult":3.5},
	"bastion_lmg": {"name":"壁垒轻机枪", "class":"lmg", "ammo":"medium", "damage":25.0, "fire_rate":8.0, "magazine":60, "reload":4.7, "range":105.0, "spread":0.04, "move_spread":1.5, "recoil":0.009, "falloff_start":42.0, "falloff_end":100.0, "min_damage_mult":0.62, "structure_mult":1.45},
	"comet_launcher": {"name":"彗星发射器", "class":"explosive", "ammo":"rockets", "damage":92.0, "fire_rate":0.32, "magazine":1, "reload":3.0, "range":180.0, "spread":0.002, "move_spread":1.1, "recoil":0.04, "structure_mult":2.2, "splash":5.0, "projectile_speed":44.0, "projectile_gravity":2.4}
}

const CONSUMABLES := {
	"bandage": {"name":"绷带", "stack":15, "use_time":3.0, "health":15.0, "health_cap":75.0},
	"medkit": {"name":"医疗包", "stack":3, "use_time":8.0, "health":100.0, "health_cap":100.0},
	"mini_shield": {"name":"小型护盾剂", "stack":6, "use_time":2.0, "shield":25.0, "shield_cap":50.0},
	"shield_tonic": {"name":"大型护盾剂", "stack":3, "use_time":5.0, "shield":50.0, "shield_cap":100.0},
	"renewal_mix": {"name":"复合恢复饮料", "stack":2, "use_time":10.0, "health":100.0, "shield":100.0, "health_cap":100.0, "shield_cap":100.0}
}

const AMMO_START := {"light":36, "medium":30, "shells":8, "heavy":4, "rockets":1}
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]

static func weapon(id: String, rarity: String = "common") -> Dictionary:
	var data: Dictionary = WEAPONS.get(id, WEAPONS["vanguard_ar"]).duplicate(true)
	var rarity_data: Dictionary = RARITY.get(rarity, RARITY.common)
	data.id = id
	data.rarity = rarity
	data.damage *= float(rarity_data.power)
	data.reload /= lerpf(1.0, float(rarity_data.power), 0.65)
	data.color = rarity_data.color
	return data

static func damage_at_distance(weapon_data: Dictionary, distance: float) -> float:
	var start := float(weapon_data.get("falloff_start", weapon_data.get("range", 100.0)))
	var end := float(weapon_data.get("falloff_end", weapon_data.get("range", 100.0)))
	if distance <= start or end <= start: return float(weapon_data.damage)
	var t := clampf((distance - start) / (end - start), 0.0, 1.0)
	return float(weapon_data.damage) * lerpf(1.0, float(weapon_data.get("min_damage_mult", 0.65)), t)

static func random_weapon(max_rarity_index: int = 4) -> Dictionary:
	var ids := WEAPONS.keys()
	var rarity_index := mini(_weighted_rarity_index(), max_rarity_index)
	return weapon(ids[randi() % ids.size()], RARITY_ORDER[rarity_index])

static func _weighted_rarity_index() -> int:
	var roll := randf()
	if roll < 0.40: return 0
	if roll < 0.70: return 1
	if roll < 0.88: return 2
	if roll < 0.97: return 3
	return 4
