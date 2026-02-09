class_name DigimonState
extends RefCounted
## Mutable runtime state for a single Digimon instance.

var key: StringName = &""
var nickname: String = ""
var level: int = 1
var experience: int = 0
var personality_key: StringName = &""

## Stat key -> value (0-50, rolled at creation, permanent).
var ivs: Dictionary = {}
## Stat key -> value (0-500, earned through training).
var tvs: Dictionary = {}

var current_hp: int = 0
var current_energy: int = 0

## All techniques this Digimon currently knows.
var known_technique_keys: Array[StringName] = []
## Currently equipped techniques (max from GameBalance).
var equipped_technique_keys: Array[StringName] = []

## Which ability slot is active (1, 2, or 3).
var active_ability_slot: int = 1

## Equipped gear keys.
var equipped_gear_key: StringName = &""
var equipped_consumable_key: StringName = &""

## Scan data percentage (0.0-1.0, for wild Digimon scanning progress).
var scan_data: float = 0.0

## Status conditions that persist outside battle. Each: { "key": StringName, ... }
var status_conditions: Array[Dictionary] = []


func to_dict() -> Dictionary:
	return {
		"key": key,
		"nickname": nickname,
		"level": level,
		"experience": experience,
		"personality_key": personality_key,
		"ivs": ivs.duplicate(),
		"tvs": tvs.duplicate(),
		"current_hp": current_hp,
		"current_energy": current_energy,
		"known_technique_keys": Array(known_technique_keys),
		"equipped_technique_keys": Array(equipped_technique_keys),
		"active_ability_slot": active_ability_slot,
		"equipped_gear_key": equipped_gear_key,
		"equipped_consumable_key": equipped_consumable_key,
		"scan_data": scan_data,
		"status_conditions": status_conditions.duplicate(true),
	}


static func from_dict(data: Dictionary) -> DigimonState:
	var state := DigimonState.new()
	state.key = StringName(data.get("key", ""))
	state.nickname = data.get("nickname", "")
	state.level = data.get("level", 1)
	state.experience = data.get("experience", 0)
	state.personality_key = StringName(data.get("personality_key", ""))
	state.ivs = data.get("ivs", {})
	state.tvs = data.get("tvs", {})
	state.current_hp = data.get("current_hp", 0)
	state.current_energy = data.get("current_energy", 0)
	state.active_ability_slot = data.get("active_ability_slot", 1)
	state.equipped_gear_key = StringName(data.get("equipped_gear_key", ""))
	state.equipped_consumable_key = StringName(data.get("equipped_consumable_key", ""))
	state.scan_data = data.get("scan_data", 0.0)

	for technique_key: String in data.get("known_technique_keys", []):
		state.known_technique_keys.append(StringName(technique_key))
	for technique_key: String in data.get("equipped_technique_keys", []):
		state.equipped_technique_keys.append(StringName(technique_key))

	for status_dict: Dictionary in data.get("status_conditions", []):
		state.status_conditions.append(status_dict)

	return state
