class_name DigimonData
extends Resource
## Immutable template defining a Digimon species. Mapped from digimon-dex Digimon table.

const _Reg = preload("res://autoload/registry.gd")
const _Settings = preload("res://autoload/settings.gd")

@export var key: StringName = &""
@export var jp_name: String = ""
@export var dub_name: String = ""
@export var custom_name: String = ""

## Size trait key (max 1). Empty if unset.
@export var size_trait: StringName = &""
## Movement trait keys (unlimited).
@export var movement_traits: Array[StringName] = []
## Type trait key (max 1). Empty if unset.
@export var type_trait: StringName = &""
## Element trait keys (unlimited). Used for STAB calculation.
@export var element_traits: Array[StringName] = []

@export var level: int = 1
@export var attribute: _Reg.Attribute = _Reg.Attribute.NONE

# Base stats
@export var base_hp: int = 0
@export var base_energy: int = 0
@export var base_attack: int = 0
@export var base_defence: int = 0
@export var base_special_attack: int = 0
@export var base_special_defence: int = 0
@export var base_speed: int = 0
@export var bst: int = 0

## Element key -> resistance multiplier (0.0 immune, 0.5 resistant, 1.0 neutral, 1.5 weak, 2.0 very weak).
@export var resistances: Dictionary = {}

## Techniques this Digimon can learn, with requirements (OR logic — any met = learnable).
## Each entry: { "key": StringName, "requirements": Array[Dictionary] }
## Requirement types:
##   { "type": "innate" }
##   { "type": "level", "level": int }
##   { "type": "tutor", "text": String }
##   { "type": "item", "text": String }
@export var technique_entries: Array[Dictionary] = []

## Ability slot keys (slot 3 is hidden/secret).
@export var ability_slot_1_key: StringName = &""
@export var ability_slot_2_key: StringName = &""
@export var ability_slot_3_key: StringName = &""

## XP growth rate curve for levelling.
@export var growth_rate: _Reg.GrowthRate = _Reg.GrowthRate.MEDIUM_FAST
## Base XP yield when this species is defeated.
@export var base_xp_yield: int = 50


## Returns keys of techniques with an "innate" requirement.
func get_innate_technique_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for entry: Dictionary in technique_entries:
		var reqs: Array = entry.get("requirements", []) as Array
		for req: Variant in reqs:
			if req is Dictionary and (req as Dictionary).get("type", "") == "innate":
				keys.append(entry.get("key", &"") as StringName)
				break
	return keys


## Returns keys of techniques learnable at or below the given level (innate + level requirements).
func get_technique_keys_at_level(level_threshold: int) -> Array[StringName]:
	var keys: Array[StringName] = []
	for entry: Dictionary in technique_entries:
		var reqs: Array = entry.get("requirements", []) as Array
		for req: Variant in reqs:
			if req is not Dictionary:
				continue
			var r: Dictionary = req as Dictionary
			var req_type: String = r.get("type", "") as String
			if req_type == "innate":
				keys.append(entry.get("key", &"") as StringName)
				break
			if req_type == "level" and int(r.get("level", 0)) <= level_threshold:
				keys.append(entry.get("key", &"") as StringName)
				break
	return keys


## Returns all technique keys regardless of requirement type.
func get_all_technique_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for entry: Dictionary in technique_entries:
		var tech_key: StringName = entry.get("key", &"") as StringName
		if tech_key != &"":
			keys.append(tech_key)
	return keys


## Returns the display name based on player preference settings.
var display_name: String:
	get:
		var settings: Node = Engine.get_singleton(&"Settings")
		if settings and settings.use_game_names and custom_name != "":
			return custom_name
		if settings and settings.display_preference == _Settings.DisplayPreference.JAPANESE:
			return jp_name
		if dub_name != "":
			return dub_name
		return jp_name
