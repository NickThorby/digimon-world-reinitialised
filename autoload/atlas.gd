extends Node
## Loads and provides access to all data resources.

var digimon: Dictionary[StringName, Resource] = {}
var techniques: Dictionary[StringName, Resource] = {}
var abilities: Dictionary[StringName, Resource] = {}
var evolutions: Dictionary[StringName, Resource] = {}
var elements: Dictionary[StringName, Resource] = {}
var items: Dictionary[StringName, Resource] = {}
var status_effects: Dictionary[StringName, Resource] = {}
var personalities: Dictionary[StringName, Resource] = {}
var tamers: Dictionary[StringName, Resource] = {}
var shops: Dictionary[StringName, Resource] = {}
var zones: Dictionary = {}  ## StringName -> ZoneData


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	digimon = _load_resources_from_folder("res://data/digimon")
	techniques = _load_resources_from_folder("res://data/technique")
	abilities = _load_resources_from_folder("res://data/ability")
	evolutions = _load_resources_from_folder("res://data/evolution")
	elements = _load_resources_from_folder("res://data/element")
	items = _load_resources_from_folder_recursive("res://data/item")
	status_effects = _load_resources_from_folder("res://data/status_effect")
	personalities = _load_resources_from_folder("res://data/personality")
	tamers = _load_resources_from_folder("res://data/tamer")
	shops = _load_resources_from_folder("res://data/shop")
	_load_zones_from_json()

	_print_load_summary()


func _print_load_summary() -> void:
	print("Atlas loaded:")
	print("  Digimon: %d" % digimon.size())
	print("  Techniques: %d" % techniques.size())
	print("  Abilities: %d" % abilities.size())
	print("  Evolutions: %d" % evolutions.size())
	print("  Elements: %d" % elements.size())
	print("  Items: %d" % items.size())
	print("  Status Effects: %d" % status_effects.size())
	print("  Personalities: %d" % personalities.size())
	print("  Tamers: %d" % tamers.size())
	print("  Shops: %d" % shops.size())
	print("  Zones: %d" % zones.size())


func _load_resources_from_folder(path: String) -> Dictionary[StringName, Resource]:
	var result: Dictionary[StringName, Resource] = {}
	var dir := DirAccess.open(path)

	if dir == null:
		push_warning("Atlas: Could not open directory: %s" % path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path := path.path_join(file_name)
			var resource := load(resource_path)
			if resource != null and resource.has_method("get") and "key" in resource:
				result[resource.key] = resource
		file_name = dir.get_next()

	dir.list_dir_end()
	return result


func _load_resources_from_folder_recursive(path: String) -> Dictionary[StringName, Resource]:
	var result: Dictionary[StringName, Resource] = {}
	var dir := DirAccess.open(path)

	if dir == null:
		push_warning("Atlas: Could not open directory: %s" % path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var full_path := path.path_join(file_name)

		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_resources := _load_resources_from_folder_recursive(full_path)
			result.merge(sub_resources)
		elif file_name.ends_with(".tres"):
			var resource := load(full_path)
			if resource != null and resource.has_method("get") and "key" in resource:
				result[resource.key] = resource

		file_name = dir.get_next()

	dir.list_dir_end()
	return result


func _load_zones_from_json() -> void:
	var path := "res://data/locale/locations.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Atlas: Could not open locations file: %s" % path)
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("Atlas: Failed to parse locations JSON: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data as Dictionary
	if data == null:
		return

	for region: Variant in data.get("regions", []):
		if region is not Dictionary:
			continue
		var r: Dictionary = region as Dictionary
		for sector: Variant in r.get("sectors", []):
			if sector is not Dictionary:
				continue
			var s: Dictionary = sector as Dictionary
			for zone: Variant in s.get("zones", []):
				if zone is not Dictionary:
					continue
				var z: Dictionary = zone as Dictionary
				var zone_data: ZoneData = ZoneData.parse_from_json(r, s, z)
				zones[zone_data.key] = zone_data
