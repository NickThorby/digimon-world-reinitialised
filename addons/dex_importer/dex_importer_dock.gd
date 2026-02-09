@tool
extends VBoxContainer
## Dock panel UI and import orchestration for the Dex Importer.

const EXPECTED_VERSION: int = 1

const TECHNIQUE_FOLDER: String = "res://data/technique"
const ABILITY_FOLDER: String = "res://data/ability"
const DIGIMON_FOLDER: String = "res://data/digimon"
const EVOLUTION_FOLDER: String = "res://data/evolution"
const LOCATIONS_FILE: String = "res://data/locale/locations.json"

var _client: RefCounted
var _mapper: RefCounted
var _validator: RefCounted
var _writer: RefCounted
var _file_dialog: EditorFileDialog

@onready var _source_mode: OptionButton = %SourceMode
@onready var _api_url_container: HBoxContainer = %ApiUrlContainer
@onready var _api_url: LineEdit = %ApiUrl
@onready var _file_path_container: HBoxContainer = %FilePathContainer
@onready var _file_path: LineEdit = %FilePath
@onready var _browse_button: Button = %BrowseButton
@onready var _import_digimon: CheckBox = %ImportDigimon
@onready var _import_techniques: CheckBox = %ImportTechniques
@onready var _import_abilities: CheckBox = %ImportAbilities
@onready var _import_evolutions: CheckBox = %ImportEvolutions
@onready var _import_locations: CheckBox = %ImportLocations
@onready var _import_button: Button = %ImportButton
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _log_output: RichTextLabel = %LogOutput


func _ready() -> void:
	var DexClient: GDScript = load("res://addons/dex_importer/import/dex_client.gd")
	var DexMapper: GDScript = load("res://addons/dex_importer/import/dex_mapper.gd")
	var BrickValidator: GDScript = load("res://addons/dex_importer/import/brick_validator.gd")
	var ResourceWriter: GDScript = load("res://addons/dex_importer/import/resource_writer.gd")
	_client = DexClient.new()
	_mapper = DexMapper.new()
	_validator = BrickValidator.new()
	_writer = ResourceWriter.new()

	_source_mode.item_selected.connect(_on_source_mode_changed)
	_import_button.pressed.connect(_on_import_pressed)
	_browse_button.pressed.connect(_on_browse_pressed)


func _on_source_mode_changed(index: int) -> void:
	_api_url_container.visible = (index == 0)
	_file_path_container.visible = (index == 1)


func _on_browse_pressed() -> void:
	if not _file_dialog:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.add_filter("*.json", "JSON Files")
		_file_dialog.file_selected.connect(_on_file_selected)
		add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(800, 600))


func _on_file_selected(path: String) -> void:
	_file_path.text = path


func _on_import_pressed() -> void:
	_import_button.disabled = true
	_progress_bar.visible = true
	_progress_bar.value = 0.0
	_log_output.clear()
	_log("Starting import...")

	var data: Dictionary = await _fetch_data()
	if data.is_empty():
		_finish_import()
		return

	if not data.has("version") or data["version"] != EXPECTED_VERSION:
		_log_error("Version mismatch: expected %d, got %s" % [
			EXPECTED_VERSION, str(data.get("version", "missing"))
		])
		_finish_import()
		return

	_log("Export version: %d | Exported at: %s" % [
		data["version"], str(data.get("exported_at", "unknown"))
	])

	var valid_technique_keys: Dictionary = {}
	var valid_ability_keys: Dictionary = {}
	var step_count: float = 0.0
	var total_steps: float = 5.0

	# Step 1: Techniques
	if _import_techniques.button_pressed and data.has("techniques"):
		_set_progress(step_count, total_steps, "Importing techniques...")
		var result: Dictionary = _import_techniques_data(data["techniques"])
		valid_technique_keys = result.get("valid_keys", {})
	step_count += 1.0

	# Step 2: Abilities
	if _import_abilities.button_pressed and data.has("abilities"):
		_set_progress(step_count, total_steps, "Importing abilities...")
		var result: Dictionary = _import_abilities_data(data["abilities"])
		valid_ability_keys = result.get("valid_keys", {})
	step_count += 1.0

	# Step 3: Digimon
	if _import_digimon.button_pressed and data.has("digimon"):
		_set_progress(step_count, total_steps, "Importing Digimon...")
		_import_digimon_data(data["digimon"], valid_technique_keys, valid_ability_keys)
	step_count += 1.0

	# Step 4: Evolutions
	if _import_evolutions.button_pressed and data.has("evolutions"):
		_set_progress(step_count, total_steps, "Importing evolutions...")
		_import_evolutions_data(data["evolutions"])
	step_count += 1.0

	# Step 5: Locations
	if _import_locations.button_pressed and data.has("locations"):
		_set_progress(step_count, total_steps, "Importing locations...")
		_import_locations_data(data["locations"])
	step_count += 1.0

	_set_progress(total_steps, total_steps, "Done!")
	_log("Import complete.")

	# Refresh the editor filesystem
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	_finish_import()


func _fetch_data() -> Dictionary:
	if _source_mode.selected == 0:
		_log("Fetching from API: %s" % _api_url.text)
		return await _client.fetch_from_api(_api_url.text, self)
	else:
		_log("Reading from file: %s" % _file_path.text)
		return _client.fetch_from_file(_file_path.text)


func _import_techniques_data(techniques_array: Array) -> Dictionary:
	var imported: int = 0
	var discarded_empty: int = 0
	var discarded_invalid: int = 0
	var valid_keys: Dictionary = {}
	var imported_files: Array[String] = []

	for entry: Variant in techniques_array:
		if entry is not Dictionary:
			continue
		var dex_data: Dictionary = entry as Dictionary
		var game_id: String = dex_data.get("game_id", "")
		if game_id.is_empty():
			continue

		var bricks: Variant = dex_data.get("bricks", null)
		if bricks == null or (bricks is Array and (bricks as Array).is_empty()):
			discarded_empty += 1
			continue

		var validation: Dictionary = _validator.validate_bricks(bricks as Array)
		if not validation.get("valid", false):
			discarded_invalid += 1
			for err: Variant in validation.get("errors", []):
				_log_warning("Technique '%s': %s" % [game_id, str(err)])
			continue

		var resource: Resource = _mapper.map_technique(dex_data, _validator)
		if resource == null:
			discarded_invalid += 1
			continue

		var filename: String = game_id + ".tres"
		var error: int = _writer.write_resource(resource, TECHNIQUE_FOLDER, filename)
		if error == OK:
			imported += 1
			valid_keys[StringName(game_id)] = true
			imported_files.append(filename)
		else:
			_log_error("Failed to write technique '%s': error %d" % [game_id, error])

	_remove_stale_files(TECHNIQUE_FOLDER, imported_files)
	_log("Techniques: %d imported, %d discarded (no bricks), %d discarded (invalid bricks)" % [
		imported, discarded_empty, discarded_invalid
	])
	return {"valid_keys": valid_keys}


func _import_abilities_data(abilities_array: Array) -> Dictionary:
	var imported: int = 0
	var discarded_empty: int = 0
	var discarded_invalid: int = 0
	var valid_keys: Dictionary = {}
	var imported_files: Array[String] = []

	for entry: Variant in abilities_array:
		if entry is not Dictionary:
			continue
		var dex_data: Dictionary = entry as Dictionary
		var game_id: String = dex_data.get("game_id", "")
		if game_id.is_empty():
			continue

		var bricks: Variant = dex_data.get("bricks", null)
		if bricks == null or (bricks is Array and (bricks as Array).is_empty()):
			discarded_empty += 1
			continue

		var validation: Dictionary = _validator.validate_bricks(bricks as Array)
		if not validation.get("valid", false):
			discarded_invalid += 1
			for err: Variant in validation.get("errors", []):
				_log_warning("Ability '%s': %s" % [game_id, str(err)])
			continue

		var resource: Resource = _mapper.map_ability(dex_data, _validator)
		if resource == null:
			discarded_invalid += 1
			continue

		var filename: String = game_id + ".tres"
		var error: int = _writer.write_resource(resource, ABILITY_FOLDER, filename)
		if error == OK:
			imported += 1
			valid_keys[StringName(game_id)] = true
			imported_files.append(filename)
		else:
			_log_error("Failed to write ability '%s': error %d" % [game_id, error])

	_remove_stale_files(ABILITY_FOLDER, imported_files)
	_log("Abilities: %d imported, %d discarded (no bricks), %d discarded (invalid bricks)" % [
		imported, discarded_empty, discarded_invalid
	])
	return {"valid_keys": valid_keys}


func _import_digimon_data(
	digimon_array: Array,
	valid_technique_keys: Dictionary,
	valid_ability_keys: Dictionary,
) -> void:
	var imported: int = 0
	var imported_files: Array[String] = []

	for entry: Variant in digimon_array:
		if entry is not Dictionary:
			continue
		var dex_data: Dictionary = entry as Dictionary
		var game_id: String = dex_data.get("game_id", "")
		if game_id.is_empty():
			continue

		var resource: Resource = _mapper.map_digimon(
			dex_data, valid_technique_keys, valid_ability_keys
		)
		if resource == null:
			_log_error("Failed to map Digimon '%s'" % game_id)
			continue

		var filename: String = game_id + ".tres"
		var error: int = _writer.write_resource(resource, DIGIMON_FOLDER, filename)
		if error == OK:
			imported += 1
			imported_files.append(filename)
		else:
			_log_error("Failed to write Digimon '%s': error %d" % [game_id, error])

	_remove_stale_files(DIGIMON_FOLDER, imported_files)
	_log("Digimon: %d imported" % imported)


func _import_evolutions_data(evolutions_array: Array) -> void:
	var imported: int = 0
	var imported_files: Array[String] = []

	for entry: Variant in evolutions_array:
		if entry is not Dictionary:
			continue
		var dex_data: Dictionary = entry as Dictionary
		var from_id: String = dex_data.get("from_game_id", "")
		var to_id: String = dex_data.get("to_game_id", "")
		if from_id.is_empty() or to_id.is_empty():
			continue

		var resource: Resource = _mapper.map_evolution(dex_data)
		if resource == null:
			_log_error("Failed to map evolution '%s' -> '%s'" % [from_id, to_id])
			continue

		var filename: String = "%s_to_%s.tres" % [from_id, to_id]
		var error: int = _writer.write_resource(resource, EVOLUTION_FOLDER, filename)
		if error == OK:
			imported += 1
			imported_files.append(filename)
		else:
			_log_error("Failed to write evolution '%s': error %d" % [filename, error])

	_remove_stale_files(EVOLUTION_FOLDER, imported_files)
	_log("Evolutions: %d imported" % imported)


func _import_locations_data(locations_data: Variant) -> void:
	if locations_data == null:
		_log("Locations: skipped (no data)")
		return

	if locations_data is Dictionary:
		var loc_dict: Dictionary = locations_data as Dictionary
		var regions: Variant = loc_dict.get("regions", null)
		if regions == null or (regions is Array and (regions as Array).is_empty()):
			_log("Locations: skipped (empty)")
			return

	var dir: DirAccess = DirAccess.open("res://data/locale")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://data/locale")

	var json_string: String = JSON.stringify(locations_data, "\t")
	var file: FileAccess = FileAccess.open(LOCATIONS_FILE, FileAccess.WRITE)
	if file == null:
		_log_error("Failed to write locations file: %s" % LOCATIONS_FILE)
		return
	file.store_string(json_string)
	file.close()
	_log("Locations: written to %s" % LOCATIONS_FILE)


func _remove_stale_files(folder: String, imported_files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	var removed: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			if file_name not in imported_files:
				# Skip the class definition script
				if not file_name.ends_with("_data.gd"):
					var full_path: String = folder + "/" + file_name
					dir.remove(file_name)
					removed += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	if removed > 0:
		_log("Removed %d stale file(s) from %s" % [removed, folder])


func _set_progress(current: float, total: float, message: String) -> void:
	_progress_bar.value = (current / total) * 100.0
	_log(message)


func _finish_import() -> void:
	_import_button.disabled = false
	_progress_bar.visible = false


func _log(message: String) -> void:
	_log_output.append_text(message + "\n")
	print("[DexImporter] %s" % message)


func _log_warning(message: String) -> void:
	_log_output.append_text("[color=yellow]WARNING: %s[/color]\n" % message)
	push_warning("[DexImporter] %s" % message)


func _log_error(message: String) -> void:
	_log_output.append_text("[color=red]ERROR: %s[/color]\n" % message)
	push_error("[DexImporter] %s" % message)
