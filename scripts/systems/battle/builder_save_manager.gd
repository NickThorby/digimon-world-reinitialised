class_name BuilderSaveManager
extends RefCounted
## Saves and loads builder teams to user://builder_teams/.


const SAVE_DIR := "user://builder_teams/"
const JSON_EXTENSION := ".json"


## Save a team to a named slot. Stamps saved_at before writing.
static func save_team(team: BuilderTeamState, slot: String) -> bool:
	_ensure_dir()
	team.saved_at = int(Time.get_unix_time_from_system())
	var path: String = SAVE_DIR + slot + JSON_EXTENSION
	var json_string := JSON.stringify(team.to_dict(), "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("BuilderSaveManager: Could not write to: %s" % path)
		return false
	file.store_string(json_string)
	file.close()
	print("BuilderSaveManager: Saved team to %s" % path)
	return true


## Load a team from a named slot.
static func load_team(slot: String) -> BuilderTeamState:
	var path: String = SAVE_DIR + slot + JSON_EXTENSION
	if not FileAccess.file_exists(path):
		push_error("BuilderSaveManager: No team found at: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BuilderSaveManager: Could not read: %s" % path)
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("BuilderSaveManager: JSON parse error: %s" % json.get_error_message())
		return null

	return BuilderTeamState.from_dict(json.data)


## Get list of saved team slot names.
static func get_team_slots() -> Array[String]:
	_ensure_dir()
	var slots: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(JSON_EXTENSION):
			slots.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	return slots


## Return lightweight summaries of all saved teams, sorted newest first.
static func get_team_summaries() -> Array[Dictionary]:
	var slots: Array[String] = get_team_slots()
	var summaries: Array[Dictionary] = []
	for slot: String in slots:
		var path: String = SAVE_DIR + slot + JSON_EXTENSION
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK:
			continue
		var data: Dictionary = json.data as Dictionary
		var member_names: Array[String] = []
		for member: Dictionary in data.get("members", []):
			var digi_key: StringName = StringName(member.get("key", ""))
			var digi_data: DigimonData = Atlas.digimon.get(digi_key) as DigimonData
			var display: String = digi_data.display_name if digi_data else str(digi_key)
			var level: int = member.get("level", 1)
			member_names.append("%s Lv.%d" % [display, level])
		summaries.append({
			"slot": slot,
			"name": data.get("name", slot),
			"member_count": data.get("members", []).size(),
			"member_names": member_names,
			"saved_at": data.get("saved_at", 0),
		})
	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["saved_at"]) > int(b["saved_at"])
	)
	return summaries


## Convert a display name to a filesystem-safe slot name.
## Appends _2, _3 etc. if the slot already exists.
static func sanitise_slot_name(display_name: String) -> String:
	var base: String = display_name.to_lower().strip_edges()
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]")
	base = regex.sub(base, "_", true)
	# Collapse multiple underscores
	var collapse := RegEx.new()
	collapse.compile("_+")
	base = collapse.sub(base, "_", true)
	base = base.strip_edges().trim_prefix("_").trim_suffix("_")
	if base == "":
		base = "team"
	var slot: String = base
	var suffix: int = 2
	while slot in get_team_slots():
		slot = "%s_%d" % [base, suffix]
		suffix += 1
	return slot


## Delete a saved team.
static func delete_team(slot: String) -> void:
	var path: String = SAVE_DIR + slot + JSON_EXTENSION
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
