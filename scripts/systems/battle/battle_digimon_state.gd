class_name BattleDigimonState
extends RefCounted
## Battle-specific wrapper around DigimonState. Holds stat stages, volatiles,
## and battle-only data. Persistent changes write back to source_state post-battle.


## Reference to the persistent DigimonState (for write-back).
var source_state: DigimonState = null

## DigimonData template (looked up from Atlas).
var data: DigimonData = null

## Pre-calculated base stats (with personality applied, before stages).
var base_stats: Dictionary = {}

## Current HP and energy.
var current_hp: int = 0
var current_energy: int = 0
var max_hp: int = 0
var max_energy: int = 0

## Position on the field.
var side_index: int = 0
var slot_index: int = 0

## Stat stages: BattleStat key (StringName) -> int (-6 to +6).
var stat_stages: Dictionary = {
	&"attack": 0,
	&"defence": 0,
	&"special_attack": 0,
	&"special_defence": 0,
	&"speed": 0,
	&"accuracy": 0,
	&"evasion": 0,
}

## Status conditions active in battle: [{ "key": StringName, "duration": int, ... }]
var status_conditions: Array[Dictionary] = []

## Volatile battle state — reset on switch-out.
var volatiles: Dictionary = {
	"turns_on_field": 0,
	"last_technique_key": &"",
	"consecutive_protection_uses": 0,
	"disabled_technique_key": &"",
	"encore_technique_key": &"",
	"semi_invulnerable": &"",
	"charges": {},
}

## Counters that persist through switches within the same battle.
var counters: Dictionary = {
	"allies_fainted": 0,
	"foes_fainted": 0,
	"times_hit": 0,
}

## Technique keys.
var equipped_technique_keys: Array[StringName] = []
var known_technique_keys: Array[StringName] = []

## Resolved ability key from active slot.
var ability_key: StringName = &""

## Gear keys.
var equipped_gear_key: StringName = &""
var equipped_consumable_key: StringName = &""

## Whether this Digimon has fainted.
var is_fainted: bool = false

## XP accumulated during battle (applied post-battle).
var xp_earned: int = 0

## Which Digimon this one has participated in defeating (for XP splitting).
var participated_against: Array[StringName] = []


## Get a stat value with stages applied.
func get_effective_stat(stat_key: StringName) -> int:
	var base: int = base_stats.get(stat_key, 0)
	var stage: int = stat_stages.get(stat_key, 0)
	return StatCalculator.apply_stat_stage(base, stage)


## Get effective speed considering priority tier.
func get_effective_speed(priority: Registry.Priority) -> float:
	var speed: int = get_effective_stat(&"speed")
	return StatCalculator.calculate_effective_speed(speed, priority)


## Apply damage. Returns actual damage dealt (after clamping to HP).
func apply_damage(amount: int) -> int:
	var actual: int = mini(amount, current_hp)
	current_hp = maxi(current_hp - actual, 0)
	if current_hp == 0:
		is_fainted = true
	return actual


## Restore HP. Returns actual amount restored.
func restore_hp(amount: int) -> int:
	var actual: int = mini(amount, max_hp - current_hp)
	current_hp += actual
	return actual


## Spend energy. Returns false if overexerting (still spends what's available).
func spend_energy(amount: int) -> bool:
	if amount <= current_energy:
		current_energy -= amount
		return true
	current_energy = 0
	return false


## Restore energy.
func restore_energy(amount: int) -> void:
	current_energy = mini(current_energy + amount, max_energy)


## Modify a stat stage. Returns actual change after clamping.
func modify_stat_stage(stat_key: StringName, stages: int) -> int:
	var current: int = stat_stages.get(stat_key, 0)
	var new_value: int = clampi(current + stages, -6, 6)
	var actual_change: int = new_value - current
	stat_stages[stat_key] = new_value
	return actual_change


## Reset volatile state (called on switch-out).
func reset_volatiles() -> void:
	volatiles = {
		"turns_on_field": 0,
		"last_technique_key": &"",
		"consecutive_protection_uses": 0,
		"disabled_technique_key": &"",
		"encore_technique_key": &"",
		"semi_invulnerable": &"",
		"charges": volatiles.get("charges", {}),  # Charges persist through switches
	}
	# Reset stat stages
	for key: StringName in stat_stages:
		stat_stages[key] = 0


## Add a status condition. Returns true if successfully applied.
func add_status(key: StringName, duration: int = -1, extra: Dictionary = {}) -> bool:
	# Check for duplicates
	if has_status(key):
		return false

	var status: Dictionary = {"key": key, "duration": duration}
	status.merge(extra)
	status_conditions.append(status)
	return true


## Remove a status condition by key.
func remove_status(key: StringName) -> void:
	for i: int in range(status_conditions.size() - 1, -1, -1):
		if status_conditions[i].get("key", &"") == key:
			status_conditions.remove_at(i)
			return


## Check if a status condition is active.
func has_status(key: StringName) -> bool:
	for status: Dictionary in status_conditions:
		if status.get("key", &"") == key:
			return true
	return false


## Check if this Digimon has fainted (HP <= 0).
func check_faint() -> bool:
	if current_hp <= 0:
		is_fainted = true
	return is_fainted


## Write persistent changes back to the source DigimonState.
func write_back() -> void:
	if source_state == null:
		return

	source_state.current_hp = current_hp
	source_state.current_energy = current_energy
	source_state.experience += xp_earned

	# Write back persistent status conditions only
	source_state.status_conditions.clear()
	for status: Dictionary in status_conditions:
		var key: StringName = status.get("key", &"") as StringName
		var is_persistent: bool = false
		for persistent_status: Registry.StatusCondition in Registry.PERSISTENT_STATUSES:
			if Registry.status_condition_labels.get(persistent_status, "") != "" and \
					_status_key_matches(key, persistent_status):
				is_persistent = true
				break
		if is_persistent:
			source_state.status_conditions.append(status.duplicate())


## Helper to check if a StringName key matches a StatusCondition enum value.
func _status_key_matches(key: StringName, condition: Registry.StatusCondition) -> bool:
	# Status keys are stored as lowercase StringNames matching the enum name
	var condition_name: String = Registry.StatusCondition.keys()[condition].to_lower()
	return str(key).to_lower() == condition_name
