class_name SaveManager
extends RefCounted
## Handles save/load I/O operations with mode-based directories and metadata.

const TEST_SAVE_DIR := "user://saves/test/"
const STORY_SAVE_DIR := "user://saves/story/"
const JSON_EXTENSION := ".json"
const BINARY_EXTENSION := ".sav"


## Return the save directory for a given game mode.
static func get_save_dir(mode: Registry.GameMode) -> String:
	match mode:
		Registry.GameMode.STORY:
			return STORY_SAVE_DIR
		_:
			return TEST_SAVE_DIR


## Save game state to a slot. Wraps data in a metadata envelope.
static func save_game(
	state: GameState, slot: String,
	mode: Registry.GameMode = Registry.GameMode.TEST,
	binary: bool = false,
) -> bool:
	var save_dir: String = get_save_dir(mode)
	_ensure_dir(save_dir)

	var path: String = save_dir + slot + (BINARY_EXTENSION if binary else JSON_EXTENSION)
	var state_data: Dictionary = state.to_dict()

	# Build metadata
	var party_keys: Array[String] = []
	var party_levels: Array[int] = []
	for member: DigimonState in state.party.members:
		party_keys.append(str(member.key))
		party_levels.append(member.level)

	var meta: Dictionary = {
		"tamer_name": state.tamer_name,
		"play_time": state.play_time,
		"saved_at": Time.get_unix_time_from_system(),
		"party_keys": party_keys,
		"party_levels": party_levels,
		"mode": mode,
	}

	var envelope: Dictionary = {
		"meta": meta,
		"state": state_data,
	}

	if binary:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("SaveManager: Could not open file for writing: %s" % path)
			return false
		file.store_var(envelope)
		file.close()
	else:
		var json_string := JSON.stringify(envelope, "\t")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("SaveManager: Could not open file for writing: %s" % path)
			return false
		file.store_string(json_string)
		file.close()

	print("SaveManager: Saved to %s" % path)
	return true


## Load game state from a slot.
static func load_game(
	slot: String, mode: Registry.GameMode = Registry.GameMode.TEST,
) -> GameState:
	var save_dir: String = get_save_dir(mode)
	var json_path: String = save_dir + slot + JSON_EXTENSION
	var bin_path: String = save_dir + slot + BINARY_EXTENSION

	if FileAccess.file_exists(json_path):
		return _load_json(json_path)
	elif FileAccess.file_exists(bin_path):
		return _load_binary(bin_path)

	push_error("SaveManager: No save found for slot: %s" % slot)
	return null


## Check if a save exists for a given slot.
static func save_exists(
	slot: String, mode: Registry.GameMode = Registry.GameMode.TEST,
) -> bool:
	var save_dir: String = get_save_dir(mode)
	var json_path: String = save_dir + slot + JSON_EXTENSION
	var bin_path: String = save_dir + slot + BINARY_EXTENSION
	return FileAccess.file_exists(json_path) or FileAccess.file_exists(bin_path)


## Delete a save from a slot.
static func delete_save(
	slot: String, mode: Registry.GameMode = Registry.GameMode.TEST,
) -> void:
	var save_dir: String = get_save_dir(mode)
	var json_path: String = save_dir + slot + JSON_EXTENSION
	var bin_path: String = save_dir + slot + BINARY_EXTENSION

	if FileAccess.file_exists(json_path):
		DirAccess.remove_absolute(json_path)
	if FileAccess.file_exists(bin_path):
		DirAccess.remove_absolute(bin_path)


## Get a list of all available save slots for a mode.
static func get_save_slots(
	mode: Registry.GameMode = Registry.GameMode.TEST,
) -> Array[String]:
	var save_dir: String = get_save_dir(mode)
	_ensure_dir(save_dir)
	var slots: Array[String] = []
	var dir := DirAccess.open(save_dir)

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


## Read only the metadata portion of a save file.
## Returns the meta Dictionary, or an empty Dictionary if not found.
static func get_save_metadata(
	slot: String, mode: Registry.GameMode = Registry.GameMode.TEST,
) -> Dictionary:
	var save_dir: String = get_save_dir(mode)
	var json_path: String = save_dir + slot + JSON_EXTENSION
	var bin_path: String = save_dir + slot + BINARY_EXTENSION

	var data: Dictionary = {}
	if FileAccess.file_exists(json_path):
		data = _read_raw_json(json_path)
	elif FileAccess.file_exists(bin_path):
		data = _read_raw_binary(bin_path)

	return data.get("meta", {})


## Extract GameState from raw data, handling both envelope and flat formats.
static func _extract_state_data(raw: Dictionary) -> Dictionary:
	if raw.has("state") and raw["state"] is Dictionary:
		return raw["state"] as Dictionary
	# Flat format (legacy): the raw dict IS the state data.
	return raw


static func _load_json(path: String) -> GameState:
	var raw: Dictionary = _read_raw_json(path)
	if raw.is_empty():
		return null
	return GameState.from_dict(_extract_state_data(raw))


static func _load_binary(path: String) -> GameState:
	var raw: Dictionary = _read_raw_binary(path)
	if raw.is_empty():
		return null
	return GameState.from_dict(_extract_state_data(raw))


static func _read_raw_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Could not open file: %s" % path)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error: %s" % json.get_error_message())
		return {}

	if json.data is Dictionary:
		return json.data as Dictionary
	return {}


static func _read_raw_binary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Could not open file: %s" % path)
		return {}

	var data: Variant = file.get_var()
	file.close()

	if data is Dictionary:
		return data as Dictionary

	push_error("SaveManager: Invalid binary save data")
	return {}


static func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
