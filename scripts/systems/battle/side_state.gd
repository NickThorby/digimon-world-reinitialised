class_name SideState
extends RefCounted
## State for one side in a battle (one tamer's field presence).


## Index of this side in the battle (0-based).
var side_index: int = 0

## Team index — sides with the same team_index are allies.
var team_index: int = 0

## Who controls this side.
var controller: BattleConfig.ControllerType = BattleConfig.ControllerType.PLAYER

## Whether this side represents wild Digimon.
var is_wild: bool = false

## Active slots on the field.
var slots: Array[SlotState] = []

## Reserve party (not currently on field).
var party: Array[DigimonState] = []

## Side-specific effects: [{ "key": StringName, "duration": int }]
var side_effects: Array[Dictionary] = []

## Entry hazards: [{ "key": StringName, "layers": int }]
var hazards: Array[Dictionary] = []


func add_side_effect(key: StringName, duration: int) -> void:
	for effect: Dictionary in side_effects:
		if effect.get("key", &"") == key:
			effect["duration"] = duration
			return
	side_effects.append({"key": key, "duration": duration})


func remove_side_effect(key: StringName) -> void:
	for i: int in range(side_effects.size() - 1, -1, -1):
		if side_effects[i].get("key", &"") == key:
			side_effects.remove_at(i)
			return


func has_side_effect(key: StringName) -> bool:
	for effect: Dictionary in side_effects:
		if effect.get("key", &"") == key:
			return true
	return false


func add_hazard(key: StringName, layers: int = 1) -> void:
	for hazard: Dictionary in hazards:
		if hazard.get("key", &"") == key:
			hazard["layers"] = int(hazard.get("layers", 0)) + layers
			return
	hazards.append({"key": key, "layers": layers})


func remove_hazard(key: StringName) -> void:
	for i: int in range(hazards.size() - 1, -1, -1):
		if hazards[i].get("key", &"") == key:
			hazards.remove_at(i)
			return


func clear_hazards() -> void:
	hazards.clear()


## Tick side effect durations. Returns array of expired effect keys.
func tick_durations() -> Array[StringName]:
	var expired: Array[StringName] = []
	for i: int in range(side_effects.size() - 1, -1, -1):
		side_effects[i]["duration"] = int(side_effects[i].get("duration", 0)) - 1
		if int(side_effects[i].get("duration", 0)) <= 0:
			expired.append(side_effects[i].get("key", &"") as StringName)
			side_effects.remove_at(i)
	return expired


## Count of Digimon still able to battle (active slots + reserve).
func get_remaining_count() -> int:
	var count: int = 0
	for slot: SlotState in slots:
		if slot.digimon != null and not slot.digimon.is_fainted:
			count += 1
	for digimon: DigimonState in party:
		if digimon.current_hp > 0:
			count += 1
	return count


## Whether any active slot has a non-fainted Digimon.
func has_active_digimon() -> bool:
	for slot: SlotState in slots:
		if slot.digimon != null and not slot.digimon.is_fainted:
			return true
	return false
