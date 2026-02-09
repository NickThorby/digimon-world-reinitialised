class_name BuilderSaveManager
extends RefCounted
## Saves and loads builder teams to user://builder_teams/.


const SAVE_DIR := "user://builder_teams/"
const JSON_EXTENSION := ".json"


## Save a team to a named slot.
static func save_team(team: BuilderTeamState, slot: String) -> bool:
	_ensure_dir()
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


## Delete a saved team.
static func delete_team(slot: String) -> void:
	var path: String = SAVE_DIR + slot + JSON_EXTENSION
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
