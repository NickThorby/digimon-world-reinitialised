class_name DigimonState
extends RefCounted
## Mutable runtime state for a single Digimon instance.

var key: StringName = &""
## Visible ID — 8-char hex, shown on summary screens.
var display_id: StringName = &""
## Hidden ID — 8-char hex, combined with display_id for true uniqueness.
var secret_id: StringName = &""
var original_tamer_name: String = ""
var original_tamer_id: StringName = &""
var nickname: String = ""
var level: int = 1
var experience: int = 0
var personality_key: StringName = &""
var personality_override_key: StringName = &""


## Returns the effective personality key, preferring override if set.
func get_effective_personality_key() -> StringName:
	if personality_override_key != &"":
		return personality_override_key
	return personality_key

## Stat key -> value (0-50, rolled at creation, permanent).
var ivs: Dictionary = {}
## Stat key -> value (0-500, earned through training).
var tvs: Dictionary = {}
## Stat key -> value (extra IVs gained from hyper training).
var hyper_trained_ivs: Dictionary = {}


## Returns the final IV for a stat, combining base IV and hyper-trained IV, capped at max_iv.
func get_final_iv(stat_key: StringName) -> int:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_iv: int = balance.max_iv if balance else 50
	var base_iv: int = ivs.get(stat_key, 0) as int
	var hyper_iv: int = hyper_trained_ivs.get(stat_key, 0) as int
	return mini(base_iv + hyper_iv, max_iv)


## Returns the sum of all TV values across all stats.
func get_total_tvs() -> int:
	var total: int = 0
	for value: Variant in tvs.values():
		total += int(value)
	return total


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

## Training points available for stat training.
var training_points: int = 0

## Scan data percentage (0.0-1.0, for wild Digimon scanning progress).
var scan_data: float = 0.0

## Status conditions that persist outside battle. Each: { "key": StringName, ... }
var status_conditions: Array[Dictionary] = []

## Serialised state of Digimon consumed via Jogress evolution, for potential de-evolution.
## DEPRECATED: Use evolution_history entries instead. Retained for backward-compatible loading.
var jogress_partners: Array[Dictionary] = []

## Evolution history — chain of evolutions this Digimon has undergone.
## Each: { "from_key", "to_key", "evolution_type": int, "evolution_item_key", "jogress_partners": Array }
var evolution_history: Array[Dictionary] = []

## Item held due to evolution (spirit/digimental/mode change). Hidden from UI.
var evolution_item_key: StringName = &""

## Accumulated X-Antibody value. Gained via items, checked by evo requirements.
var x_antibody: int = 0

## Combined 16-char hex identifier for internal tracking (display_id + secret_id).
var unique_id: StringName:
	get:
		return StringName(str(display_id) + str(secret_id))


func to_dict() -> Dictionary:
	return {
		"key": key,
		"display_id": display_id,
		"secret_id": secret_id,
		"original_tamer_name": original_tamer_name,
		"original_tamer_id": original_tamer_id,
		"nickname": nickname,
		"level": level,
		"experience": experience,
		"personality_key": personality_key,
		"personality_override_key": personality_override_key,
		"ivs": ivs.duplicate(),
		"tvs": tvs.duplicate(),
		"hyper_trained_ivs": hyper_trained_ivs.duplicate(),
		"current_hp": current_hp,
		"current_energy": current_energy,
		"known_technique_keys": Array(known_technique_keys),
		"equipped_technique_keys": Array(equipped_technique_keys),
		"active_ability_slot": active_ability_slot,
		"equipped_gear_key": equipped_gear_key,
		"equipped_consumable_key": equipped_consumable_key,
		"training_points": training_points,
		"scan_data": scan_data,
		"status_conditions": status_conditions.duplicate(true),
		"jogress_partners": jogress_partners.duplicate(true),
		"evolution_history": evolution_history.duplicate(true),
		"evolution_item_key": evolution_item_key,
		"x_antibody": x_antibody,
	}


static func from_dict(data: Dictionary) -> DigimonState:
	var state := DigimonState.new()
	state.key = StringName(data.get("key", ""))
	var loaded_display: String = data.get("display_id", "")
	var loaded_secret: String = data.get("secret_id", "")
	if loaded_display != "" and loaded_secret != "":
		state.display_id = StringName(loaded_display)
		state.secret_id = StringName(loaded_secret)
	else:
		var ids: Dictionary = IdGenerator.generate_digimon_ids()
		state.display_id = ids["display_id"]
		state.secret_id = ids["secret_id"]
	state.original_tamer_name = data.get("original_tamer_name", "")
	state.original_tamer_id = StringName(data.get("original_tamer_id", ""))
	state.nickname = data.get("nickname", "")
	state.level = data.get("level", 1)
	state.experience = data.get("experience", 0)
	state.personality_key = StringName(data.get("personality_key", ""))
	state.personality_override_key = StringName(data.get("personality_override_key", ""))
	state.ivs = data.get("ivs", {})
	state.tvs = data.get("tvs", {})
	state.hyper_trained_ivs = data.get("hyper_trained_ivs", {})
	state.current_hp = data.get("current_hp", 0)
	state.current_energy = data.get("current_energy", 0)
	state.active_ability_slot = data.get("active_ability_slot", 1)
	state.equipped_gear_key = StringName(data.get("equipped_gear_key", ""))
	state.equipped_consumable_key = StringName(data.get("equipped_consumable_key", ""))
	state.training_points = data.get("training_points", 0)
	state.scan_data = data.get("scan_data", 0.0)

	for technique_key: String in data.get("known_technique_keys", []):
		state.known_technique_keys.append(StringName(technique_key))
	for technique_key: String in data.get("equipped_technique_keys", []):
		state.equipped_technique_keys.append(StringName(technique_key))

	for status_dict: Dictionary in data.get("status_conditions", []):
		state.status_conditions.append(status_dict)

	for partner_dict: Dictionary in data.get("jogress_partners", []):
		state.jogress_partners.append(partner_dict)

	for history_entry: Dictionary in data.get("evolution_history", []):
		state.evolution_history.append(history_entry)

	state.evolution_item_key = StringName(data.get("evolution_item_key", ""))
	state.x_antibody = data.get("x_antibody", 0)

	return state
