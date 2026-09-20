class_name LocalProfile
extends RefCounted

const PATH: String = "user://aegis_royale_profile.json"

var settings: Dictionary = {
	"mouse_sensitivity": 1.0,
	"ai_count": 31,
	"ai_difficulty": 0.55,
	"field_of_view": 78.0,
}
var stats: Dictionary = {
	"matches": 0,
	"wins": 0,
	"kills": 0,
	"best_placement": 0,
	"top10": 0,
}

func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("settings") and typeof(data["settings"]) == TYPE_DICTIONARY:
		var s: Dictionary = data["settings"]
		for k in s.keys():
			settings[k] = s[k]
	if data.has("stats") and typeof(data["stats"]) == TYPE_DICTIONARY:
		var st: Dictionary = data["stats"]
		for k in st.keys():
			stats[k] = st[k]

func save() -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"settings": settings, "stats": stats}, "  "))
	f.close()

func record(won: bool, placement: int, kills: int) -> void:
	stats["matches"] = int(stats.get("matches", 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + kills
	if won:
		stats["wins"] = int(stats.get("wins", 0)) + 1
	if placement <= 10:
		stats["top10"] = int(stats.get("top10", 0)) + 1
	var best: int = int(stats.get("best_placement", 0))
	if best == 0 or placement < best:
		stats["best_placement"] = placement
	save()
