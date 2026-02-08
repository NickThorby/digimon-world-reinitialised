class_name SaveManager
extends RefCounted
## Handles save/load I/O operations.

const SAVE_DIR := "user://saves/"
const JSON_EXTENSION := ".json"
const BINARY_EXTENSION := ".sav"


## Save game state to a slot. Uses JSON by default, binary if specified.
static func save_game(state: GameState, slot: String, binary: bool = false) -> bool:
	_ensure_save_dir()

	var path: String = SAVE_DIR + slot + (BINARY_EXTENSION if binary else JSON_EXTENSION)
	var data: Dictionary = state.to_dict()

	if binary:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("SaveManager: Could not open file for writing: %s" % path)
			return false
		file.store_var(data)
		file.close()
	else:
		var json_string := JSON.stringify(data, "\t")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("SaveManager: Could not open file for writing: %s" % path)
			return false
		file.store_string(json_string)
		file.close()

	print("SaveManager: Saved to %s" % path)
	return true


## Load game state from a slot.
static func load_game(slot: String) -> GameState:
	# Try JSON first, then binary
	var json_path: String = SAVE_DIR + slot + JSON_EXTENSION
	var bin_path: String = SAVE_DIR + slot + BINARY_EXTENSION

	if FileAccess.file_exists(json_path):
		return _load_json(json_path)
	elif FileAccess.file_exists(bin_path):
		return _load_binary(bin_path)

	push_error("SaveManager: No save found for slot: %s" % slot)
	return null


## Check if a save exists for a given slot.
static func save_exists(slot: String) -> bool:
	var json_path: String = SAVE_DIR + slot + JSON_EXTENSION
	var bin_path: String = SAVE_DIR + slot + BINARY_EXTENSION
	return FileAccess.file_exists(json_path) or FileAccess.file_exists(bin_path)


## Delete a save from a slot.
static func delete_save(slot: String) -> void:
	var json_path: String = SAVE_DIR + slot + JSON_EXTENSION
	var bin_path: String = SAVE_DIR + slot + BINARY_EXTENSION

	if FileAccess.file_exists(json_path):
		DirAccess.remove_absolute(json_path)
	if FileAccess.file_exists(bin_path):
		DirAccess.remove_absolute(bin_path)


## Get a list of all available save slots.
static func get_save_slots() -> Array[String]:
	_ensure_save_dir()
	var slots: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)

	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var slot := file_name.get_basename()
			if slot not in slots:
				slots.append(slot)
		file_name = dir.get_next()

	dir.list_dir_end()
	return slots


static func _load_json(path: String) -> GameState:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Could not open file: %s" % path)
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error: %s" % json.get_error_message())
		return null

	return GameState.from_dict(json.data)


static func _load_binary(path: String) -> GameState:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Could not open file: %s" % path)
		return null

	var data: Variant = file.get_var()
	file.close()

	if data is Dictionary:
		return GameState.from_dict(data)

	push_error("SaveManager: Invalid binary save data")
	return null


static func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
