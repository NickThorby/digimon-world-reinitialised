class_name EncounterTableData
extends Resource
## Saveable encounter table for the wild battle test screen.
## Can be saved/loaded as .tres files to persist custom encounter configurations.


@export var key: StringName = &""
@export var name: String = ""

## Array of encounter entries. Each is:
## { "digimon_key": StringName, "rarity": int (Registry.Rarity),
##   "min_level": int, "max_level": int }
## min_level/max_level of -1 means "use zone/table defaults".
@export var entries: Array[Dictionary] = []
@export var default_min_level: int = 1
@export var default_max_level: int = 5

## Format preset weights: { int(BattleConfig.FormatPreset) -> int weight }
@export var format_weights: Dictionary = {}

## Boss encounter entries (same structure as entries).
@export var boss_entries: Array[Dictionary] = []
@export var sos_enabled: bool = false


## Convert this resource to a ZoneData for use with WildBattleFactory.
func to_zone_data() -> ZoneData:
	var zone := ZoneData.new()
	zone.key = key
	zone.name = name
	zone.default_min_level = default_min_level
	zone.default_max_level = default_max_level
	zone.format_weights = format_weights.duplicate()
	zone.boss_entries = boss_entries.duplicate(true)
	zone.sos_enabled = sos_enabled

	for entry: Dictionary in entries:
		zone.encounter_entries.append(entry.duplicate())

	return zone
