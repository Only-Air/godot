class_name WeaponData
extends RefCounted

const POOL := {
	"ranger_rifle": {"name":"游骑步枪", "damage":31.0, "fire_rate":5.5, "magazine":30, "reload":2.2, "range":140.0, "spread":0.012, "color":Color("4db6ff")},
	"burst_carbine": {"name":"脉冲卡宾枪", "damage":27.0, "fire_rate":8.0, "magazine":24, "reload":2.4, "range":120.0, "spread":0.018, "color":Color("9b72ff")},
	"tactical_shotgun": {"name":"战术霰弹枪", "damage":18.0, "pellets":8, "fire_rate":1.35, "magazine":8, "reload":3.8, "range":32.0, "spread":0.085, "color":Color("61d46e")},
	"heavy_pistol": {"name":"重型手枪", "damage":48.0, "fire_rate":2.0, "magazine":7, "reload":2.0, "range":105.0, "spread":0.009, "color":Color("ffbd45")},
	"compact_smg": {"name":"紧凑冲锋枪", "damage":19.0, "fire_rate":11.0, "magazine":32, "reload":2.0, "range":68.0, "spread":0.03, "color":Color("45e1c2")},
	"marksman_bow": {"name":"侦察弓", "damage":72.0, "fire_rate":0.8, "magazine":1, "reload":1.25, "range":180.0, "spread":0.003, "color":Color("ed6a9a")}
}

static func get_weapon(id: String) -> Dictionary:
	return POOL.get(id, POOL["ranger_rifle"]).duplicate(true)

static func random_id() -> String:
	var keys := POOL.keys()
	return keys[randi() % keys.size()]
