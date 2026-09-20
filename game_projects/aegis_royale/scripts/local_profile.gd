class_name LocalProfile
extends RefCounted

const SAVE_PATH := "user://aegis_profile.json"

var settings := {
	"mouse_sensitivity": 1.0,
	"simple_build_default": false,
	"simple_edit_default": false,
	"ai_count": 31,
	"ai_difficulty": 0.62,
	"show_build_help": true
}
var statistics := {
	"matches": 0,
	"wins": 0,
	"eliminations": 0,
	"best_placement": 0
}

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY: return
	var loaded: Dictionary = parsed
	if loaded.has("settings"):
		for key in loaded.settings: settings[key] = loaded.settings[key]
	if loaded.has("statistics"):
		for key in loaded.statistics: statistics[key] = loaded.statistics[key]

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"settings":settings, "statistics":statistics}, "  "))

func record_match(won: bool, placement: int, eliminations: int) -> void:
	statistics.matches += 1
	statistics.eliminations += eliminations
	if won: statistics.wins += 1
	if int(statistics.best_placement) == 0 or placement < int(statistics.best_placement):
		statistics.best_placement = placement
	save_profile()
