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

## Non-stage stat modifiers (percent/fixed) — reset on switch-out.
## {stat_key: [{type: "percent"|"fixed", value: float|int}]}
var volatile_stat_modifiers: Dictionary = {}

## Volatile battle state — reset on switch-out.
var volatiles: Dictionary = {
	"turns_on_field": 0,
	"last_technique_key": &"",
	"consecutive_protection_uses": 0,
	"disabled_technique_key": &"",
	"encore_technique_key": &"",
	"semi_invulnerable": &"",
	"charges": {},
	"recharging": false,
	"multi_turn_lock": {},
	"charging": {},
	"element_traits_added": [],
	"element_traits_removed": [],
	"element_traits_replaced": &"",
	"resistance_overrides": {},
	"shields": [],
	"last_technique_hit_by": &"",
	"transform_backup": {},
	"transform_duration": -1,
	"transform_appearance_key": &"",
	"copied_technique_slots": [],
	"ability_backup": &"",
	"ability_manipulation_duration": -1,
}

## Counters that persist through switches within the same battle.
var counters: Dictionary = {
	"allies_fainted": 0,
	"foes_fainted": 0,
	"times_hit": 0,
	"shield_once_per_battle_used": [],
}

## Technique keys.
var equipped_technique_keys: Array[StringName] = []
var known_technique_keys: Array[StringName] = []

## Resolved ability key from active slot.
var ability_key: StringName = &""

## Gear keys.
var equipped_gear_key: StringName = &""
var equipped_consumable_key: StringName = &""

## Ability trigger counters for stack limit enforcement.
var ability_trigger_counts: Dictionary = {
	"per_turn": 0,
	"per_switch": 0,
	"per_battle": 0,
}

## Gear trigger counters for stack limit enforcement (separate from abilities).
var gear_trigger_counts: Dictionary = {
	"equip_per_turn": 0,
	"equip_per_switch": 0,
	"equip_per_battle": 0,
	"consumable_per_turn": 0,
	"consumable_per_switch": 0,
	"consumable_per_battle": 0,
}

## Whether this Digimon has fainted.
var is_fainted: bool = false

## XP accumulated during battle (applied post-battle).
var xp_earned: int = 0

## Which Digimon this one has participated in defeating (for XP splitting).
var participated_against: Array[StringName] = []


## Get a stat value with stages, status modifiers, and volatile modifiers applied.
func get_effective_stat(stat_key: StringName) -> int:
	var base: int = base_stats.get(stat_key, 0)
	var stage: int = stat_stages.get(stat_key, 0)
	var staged: int = StatCalculator.apply_stat_stage(base, stage)
	var after_status: int = _apply_status_stat_modifiers(staged, stat_key)
	return _apply_volatile_stat_modifiers(after_status, stat_key)


## Apply status-based stat reductions (burned halves attack, etc.).
func _apply_status_stat_modifiers(value: int, stat_key: StringName) -> int:
	var result: float = float(value)
	if stat_key == &"attack" and (has_status(&"burned") or has_status(&"badly_burned")):
		result *= 0.5
	if stat_key == &"special_attack" and has_status(&"frostbitten"):
		result *= 0.5
	if stat_key == &"speed" and has_status(&"paralysed"):
		result *= 0.5
	return maxi(floori(result), 1)


## Apply volatile (non-stage) stat modifiers (percent and fixed).
func _apply_volatile_stat_modifiers(value: int, stat_key: StringName) -> int:
	var mods: Variant = volatile_stat_modifiers.get(stat_key)
	if mods == null or not (mods is Array):
		return value
	var result: float = float(value)
	for mod: Dictionary in (mods as Array):
		var mod_type: String = mod.get("type", "")
		match mod_type:
			"percent":
				result *= (1.0 + float(mod.get("value", 0)) / 100.0)
			"fixed":
				result += float(mod.get("value", 0))
	return maxi(floori(result), 1)


## Check whether this Digimon's ability can trigger given its stack limit.
func can_trigger_ability(stack_limit: Registry.StackLimit) -> bool:
	if has_status(&"nullified"):
		return false
	match stack_limit:
		Registry.StackLimit.UNLIMITED:
			return true
		Registry.StackLimit.ONCE_PER_TURN:
			return ability_trigger_counts.get("per_turn", 0) < 1
		Registry.StackLimit.ONCE_PER_SWITCH:
			return ability_trigger_counts.get("per_switch", 0) < 1
		Registry.StackLimit.ONCE_PER_BATTLE:
			return ability_trigger_counts.get("per_battle", 0) < 1
		Registry.StackLimit.FIRST_ONLY:
			return ability_trigger_counts.get("per_battle", 0) < 1 \
				and ability_trigger_counts.get("per_switch", 0) < 1
	return true


## Record that this Digimon's ability triggered.
func record_ability_trigger(stack_limit: Registry.StackLimit) -> void:
	match stack_limit:
		Registry.StackLimit.ONCE_PER_TURN:
			ability_trigger_counts["per_turn"] = \
				int(ability_trigger_counts.get("per_turn", 0)) + 1
		Registry.StackLimit.ONCE_PER_SWITCH:
			ability_trigger_counts["per_switch"] = \
				int(ability_trigger_counts.get("per_switch", 0)) + 1
		Registry.StackLimit.ONCE_PER_BATTLE:
			ability_trigger_counts["per_battle"] = \
				int(ability_trigger_counts.get("per_battle", 0)) + 1
		Registry.StackLimit.FIRST_ONLY:
			ability_trigger_counts["per_battle"] = \
				int(ability_trigger_counts.get("per_battle", 0)) + 1
			ability_trigger_counts["per_switch"] = \
				int(ability_trigger_counts.get("per_switch", 0)) + 1


## Reset the per-turn ability trigger counter (called at turn start).
func reset_turn_trigger_count() -> void:
	ability_trigger_counts["per_turn"] = 0
	gear_trigger_counts["equip_per_turn"] = 0
	gear_trigger_counts["consumable_per_turn"] = 0


## Check whether a gear item can trigger given its stack limit and whether it's consumable.
func can_trigger_gear(stack_limit: Registry.StackLimit, is_consumable: bool) -> bool:
	var prefix: String = "consumable" if is_consumable else "equip"
	match stack_limit:
		Registry.StackLimit.UNLIMITED:
			return true
		Registry.StackLimit.ONCE_PER_TURN:
			return int(gear_trigger_counts.get(prefix + "_per_turn", 0)) < 1
		Registry.StackLimit.ONCE_PER_SWITCH:
			return int(gear_trigger_counts.get(prefix + "_per_switch", 0)) < 1
		Registry.StackLimit.ONCE_PER_BATTLE:
			return int(gear_trigger_counts.get(prefix + "_per_battle", 0)) < 1
		Registry.StackLimit.FIRST_ONLY:
			return int(gear_trigger_counts.get(prefix + "_per_battle", 0)) < 1 \
				and int(gear_trigger_counts.get(prefix + "_per_switch", 0)) < 1
	return true


## Record that a gear item triggered.
func record_gear_trigger(stack_limit: Registry.StackLimit, is_consumable: bool) -> void:
	var prefix: String = "consumable" if is_consumable else "equip"
	match stack_limit:
		Registry.StackLimit.ONCE_PER_TURN:
			gear_trigger_counts[prefix + "_per_turn"] = \
				int(gear_trigger_counts.get(prefix + "_per_turn", 0)) + 1
		Registry.StackLimit.ONCE_PER_SWITCH:
			gear_trigger_counts[prefix + "_per_switch"] = \
				int(gear_trigger_counts.get(prefix + "_per_switch", 0)) + 1
		Registry.StackLimit.ONCE_PER_BATTLE:
			gear_trigger_counts[prefix + "_per_battle"] = \
				int(gear_trigger_counts.get(prefix + "_per_battle", 0)) + 1
		Registry.StackLimit.FIRST_ONLY:
			gear_trigger_counts[prefix + "_per_battle"] = \
				int(gear_trigger_counts.get(prefix + "_per_battle", 0)) + 1
			gear_trigger_counts[prefix + "_per_switch"] = \
				int(gear_trigger_counts.get(prefix + "_per_switch", 0)) + 1


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
	# Restore any temporary transformations, copied techniques, or ability changes
	restore_transform()
	restore_copied_techniques()
	restore_ability()

	volatiles = {
		"turns_on_field": 0,
		"last_technique_key": &"",
		"consecutive_protection_uses": 0,
		"disabled_technique_key": &"",
		"encore_technique_key": &"",
		"semi_invulnerable": &"",
		"charges": volatiles.get("charges", {}),  # Charges persist through switches
		"recharging": false,
		"multi_turn_lock": {},
		"charging": {},
		"element_traits_added": [],
		"element_traits_removed": [],
		"element_traits_replaced": &"",
		"resistance_overrides": {},
		"shields": [],
		"last_technique_hit_by": &"",
		"transform_backup": {},
		"transform_duration": -1,
		"transform_appearance_key": &"",
		"copied_technique_slots": [],
		"ability_backup": &"",
		"ability_manipulation_duration": -1,
	}
	# Reset stat stages
	for key: StringName in stat_stages:
		stat_stages[key] = 0
	# Reset volatile stat modifiers (percent/fixed)
	volatile_stat_modifiers = {}
	# Reset per-switch ability trigger counter
	ability_trigger_counts["per_switch"] = 0
	gear_trigger_counts["equip_per_switch"] = 0
	gear_trigger_counts["consumable_per_switch"] = 0


## Reset escalation counters for badly_burned / badly_poisoned on switch-out.
func reset_status_counters() -> void:
	for status: Dictionary in status_conditions:
		var key: StringName = status.get("key", &"") as StringName
		if key == &"badly_burned" or key == &"badly_poisoned":
			status["escalation_turn"] = 0


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


## Get effective element traits with volatile add/remove/replace applied.
func get_effective_element_traits() -> Array[StringName]:
	var replaced: StringName = volatiles.get(
		"element_traits_replaced", &"",
	) as StringName
	if replaced != &"":
		return [replaced] as Array[StringName]

	var result: Array[StringName] = []
	if data != null:
		result = data.element_traits.duplicate()

	var added: Variant = volatiles.get("element_traits_added", [])
	if added is Array:
		for elem: Variant in (added as Array):
			var key: StringName = elem as StringName
			if key not in result:
				result.append(key)

	var removed: Variant = volatiles.get("element_traits_removed", [])
	if removed is Array:
		for elem: Variant in (removed as Array):
			result.erase(elem as StringName)

	return result


## Get effective resistance for an element, using override if present.
func get_effective_resistance(element_key: StringName) -> float:
	var overrides: Variant = volatiles.get("resistance_overrides", {})
	if overrides is Dictionary and (overrides as Dictionary).has(element_key):
		return float((overrides as Dictionary)[element_key])
	if data != null:
		return float(data.resistances.get(element_key, 1.0))
	return 1.0


## Get all elements the Digimon is weak to (effective resistance >= 1.5).
func get_weaknesses() -> Array[StringName]:
	var result: Array[StringName] = []
	if data == null:
		return result
	# Check base resistances
	for element_key: StringName in data.resistances:
		if get_effective_resistance(element_key) >= 1.5:
			result.append(element_key)
	# Check overrides for any new weaknesses not in base
	var overrides: Variant = volatiles.get("resistance_overrides", {})
	if overrides is Dictionary:
		for element_key: StringName in (overrides as Dictionary):
			if element_key not in result \
					and float((overrides as Dictionary)[element_key]) >= 1.5:
				result.append(element_key)
	return result


## Add a shield entry to active shields.
func add_shield(shield_data: Dictionary) -> void:
	var shields: Variant = volatiles.get("shields", [])
	if shields is Array:
		(shields as Array).append(shield_data)
	else:
		volatiles["shields"] = [shield_data]


## Check if a shield type has already been used (once-per-battle).
func has_used_shield_once(shield_type: StringName) -> bool:
	var used: Variant = counters.get("shield_once_per_battle_used", [])
	if used is Array:
		return shield_type in (used as Array)
	return false


## Record that a once-per-battle shield has been used.
func record_shield_once_used(shield_type: StringName) -> void:
	var used: Variant = counters.get("shield_once_per_battle_used", [])
	if used is Array:
		if shield_type not in (used as Array):
			(used as Array).append(shield_type)
	else:
		counters["shield_once_per_battle_used"] = [shield_type]


## Store pre-transform state for later restoration.
func store_transform_backup() -> void:
	volatiles["transform_backup"] = {
		"base_stats": base_stats.duplicate(),
		"equipped_technique_keys": equipped_technique_keys.duplicate(),
		"known_technique_keys": known_technique_keys.duplicate(),
		"ability_key": ability_key,
		"element_traits_added": (volatiles.get("element_traits_added", []) as Array).duplicate(),
		"element_traits_removed": (volatiles.get("element_traits_removed", []) as Array).duplicate(),
		"element_traits_replaced": volatiles.get("element_traits_replaced", &""),
		"resistance_overrides": (volatiles.get("resistance_overrides", {}) as Dictionary).duplicate(),
	}


## Restore from transform backup, clearing the transform.
func restore_transform() -> void:
	var backup: Variant = volatiles.get("transform_backup", {})
	if not (backup is Dictionary) or (backup as Dictionary).is_empty():
		return
	var b: Dictionary = backup as Dictionary
	base_stats = (b.get("base_stats", {}) as Dictionary).duplicate()
	equipped_technique_keys = []
	for k: Variant in b.get("equipped_technique_keys", []):
		equipped_technique_keys.append(k as StringName)
	known_technique_keys = []
	for k: Variant in b.get("known_technique_keys", []):
		known_technique_keys.append(k as StringName)
	ability_key = b.get("ability_key", &"") as StringName
	volatiles["element_traits_added"] = (b.get("element_traits_added", []) as Array).duplicate()
	volatiles["element_traits_removed"] = (b.get("element_traits_removed", []) as Array).duplicate()
	volatiles["element_traits_replaced"] = b.get("element_traits_replaced", &"")
	volatiles["resistance_overrides"] = (b.get("resistance_overrides", {}) as Dictionary).duplicate()
	# Recalculate HP/energy caps from restored base stats
	var _old_max_hp: int = max_hp
	max_hp = base_stats.get(&"hp", max_hp)
	current_hp = mini(current_hp, max_hp)
	max_energy = base_stats.get(&"energy", max_energy)
	current_energy = mini(current_energy, max_energy)
	volatiles["transform_backup"] = {}
	volatiles["transform_appearance_key"] = &""


## Restore original technique keys from copied_technique_slots.
func restore_copied_techniques() -> void:
	var slots: Variant = volatiles.get("copied_technique_slots", [])
	if not (slots is Array):
		return
	for entry: Variant in (slots as Array):
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry as Dictionary
		var slot: int = int(e.get("slot", -1))
		var original_key: StringName = e.get("original_key", &"") as StringName
		if slot >= 0 and slot < equipped_technique_keys.size():
			equipped_technique_keys[slot] = original_key
	volatiles["copied_technique_slots"] = []


## Restore ability from ability_backup.
func restore_ability() -> void:
	var backup: StringName = volatiles.get("ability_backup", &"") as StringName
	if backup == &"":
		return
	ability_key = backup
	volatiles["ability_backup"] = &""


## Write persistent changes back to the source DigimonState.
func write_back() -> void:
	if source_state == null:
		return

	source_state.current_hp = current_hp
	source_state.current_energy = current_energy
	source_state.experience += xp_earned
	source_state.equipped_consumable_key = equipped_consumable_key

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
