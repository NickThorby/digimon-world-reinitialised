class_name ZoneData
extends RefCounted
## Zone encounter data parsed from locations.json.
## Describes a single zone within a region/sector with its encounter table.


## Composite key: "region/sector/zone" in snake_case.
var key: StringName = &""
var name: String = ""
var region_name: String = ""
var sector_name: String = ""
var description: String = ""

## Array of encounter entries. Each is:
## { "digimon_key": StringName, "rarity": Registry.Rarity,
##   "min_level": int, "max_level": int }
## min_level/max_level of -1 means "use zone defaults".
var encounter_entries: Array[Dictionary] = []
var default_min_level: int = 1
var default_max_level: int = 5

## Format weights: { int(BattleConfig.FormatPreset) -> int weight }
var format_weights: Dictionary = {}

## Boss encounter entries (same structure as encounter_entries).
var boss_entries: Array[Dictionary] = []
var sos_enabled: bool = false


## Returns the effective level range for an encounter entry, falling back to
## zone defaults when the entry has -1 for min or max.
func get_encounter_level_range(entry: Dictionary) -> Dictionary:
	var min_lvl: int = int(entry.get("min_level", -1))
	var max_lvl: int = int(entry.get("max_level", -1))
	if min_lvl < 0:
		min_lvl = default_min_level
	if max_lvl < 0:
		max_lvl = default_max_level
	return {"min": min_lvl, "max": max_lvl}


## Convert a string to snake_case for composite key building.
static func _to_snake_case(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_")


## Parse a ZoneData from the locations.json structure.
## region, sector, and zone are the raw JSON dictionaries at each level.
static func parse_from_json(
	region: Dictionary, sector: Dictionary, zone: Dictionary
) -> ZoneData:
	var data := ZoneData.new()

	var region_name: String = region.get("name", "")
	var sector_name: String = sector.get("name", "")
	var zone_name: String = zone.get("name", "")

	data.name = zone_name
	data.region_name = region_name
	data.sector_name = sector_name
	data.description = str(zone.get("description", "")) if zone.get("description") != null else ""

	# Build composite key
	data.key = StringName(
		"%s/%s/%s" % [
			_to_snake_case(region_name),
			_to_snake_case(sector_name),
			_to_snake_case(zone_name),
		]
	)

	# Parse encounter entries
	var digimon_list: Array = zone.get("digimon", []) as Array
	for entry: Variant in digimon_list:
		if entry is not Dictionary:
			continue
		var d: Dictionary = entry as Dictionary
		var rarity_str: String = str(d.get("rarity", "Common"))
		var rarity: int = Registry.RARITY_FROM_STRING.get(
			rarity_str, Registry.Rarity.COMMON
		)
		data.encounter_entries.append({
			"digimon_key": StringName(str(d.get("game_id", ""))),
			"rarity": rarity,
			"min_level": int(d.get("min_level", -1)),
			"max_level": int(d.get("max_level", -1)),
		})

	# Parse optional zone-level defaults
	data.default_min_level = int(zone.get("default_min_level", 1))
	data.default_max_level = int(zone.get("default_max_level", 5))

	# Parse optional format weights
	var fw: Variant = zone.get("format_weights")
	if fw is Dictionary:
		data.format_weights = fw as Dictionary

	return data
