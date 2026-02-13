class_name ItemMessageBuilder
extends RefCounted
## Builds descriptive messages for item usage by comparing before/after DigimonState.


## Captures a snapshot of mutable fields before item application.
static func snapshot(digimon: DigimonState) -> Dictionary:
	return {
		"current_hp": digimon.current_hp,
		"current_energy": digimon.current_energy,
		"status_conditions": digimon.status_conditions.duplicate(true),
		"tvs": digimon.tvs.duplicate(),
		"ivs": digimon.ivs.duplicate(),
		"training_points": digimon.training_points,
		"personality_override_key": digimon.personality_override_key,
		"active_ability_slot": digimon.active_ability_slot,
	}


## Compares before snapshot with current state and builds a message.
## Returns "It had no effect on X." if applied is false.
static func build_message(
	digimon_name: String,
	item_name: String,
	before: Dictionary,
	after_state: DigimonState,
	applied: bool,
) -> String:
	if not applied:
		return "It had no effect on %s." % digimon_name

	var header: String = "Used %s on %s!" % [item_name, digimon_name]
	var details: Array[String] = []

	# HP change
	var hp_before: int = before.get("current_hp", 0) as int
	var hp_after: int = after_state.current_hp
	if hp_after > hp_before:
		details.append("HP was restored by %d!" % (hp_after - hp_before))
	elif hp_after < hp_before:
		details.append("HP changed by %d." % (hp_after - hp_before))

	# Energy change
	var energy_before: int = before.get("current_energy", 0) as int
	var energy_after: int = after_state.current_energy
	if energy_after > energy_before:
		details.append("Energy was restored by %d!" % (energy_after - energy_before))
	elif energy_after < energy_before:
		details.append("Energy changed by %d." % (energy_after - energy_before))

	# Status cures
	var old_statuses: Array = before.get("status_conditions", []) as Array
	var new_statuses: Array = []
	for cond: Dictionary in after_state.status_conditions:
		new_statuses.append(str(cond.get("key", "")))

	for old_cond: Dictionary in old_statuses:
		var old_key: String = str(old_cond.get("key", ""))
		if old_key != "" and old_key not in new_statuses:
			details.append("%s was cured!" % old_key.capitalize())

	# TV changes
	var old_tvs: Dictionary = before.get("tvs", {}) as Dictionary
	for stat_key: Variant in after_state.tvs:
		var old_val: int = old_tvs.get(stat_key, 0) as int
		var new_val: int = after_state.tvs[stat_key] as int
		if new_val > old_val:
			details.append("%s TVs increased by %d!" % [
				str(stat_key).capitalize(), new_val - old_val,
			])
		elif new_val < old_val:
			details.append("%s TVs decreased by %d." % [
				str(stat_key).capitalize(), old_val - new_val,
			])

	# IV changes
	var old_ivs: Dictionary = before.get("ivs", {}) as Dictionary
	for stat_key: Variant in after_state.ivs:
		var old_val: int = old_ivs.get(stat_key, 0) as int
		var new_val: int = after_state.ivs[stat_key] as int
		if new_val > old_val:
			details.append("%s IVs increased by %d!" % [
				str(stat_key).capitalize(), new_val - old_val,
			])
		elif new_val < old_val:
			details.append("%s IVs decreased by %d." % [
				str(stat_key).capitalize(), old_val - new_val,
			])

	# Training points
	var tp_before: int = before.get("training_points", 0) as int
	var tp_after: int = after_state.training_points
	if tp_after > tp_before:
		details.append("Gained %d training points!" % (tp_after - tp_before))

	# Personality change
	var pers_before: StringName = before.get(
		"personality_override_key", &"",
	) as StringName
	var pers_after: StringName = after_state.personality_override_key
	if pers_after != pers_before:
		if pers_after != &"":
			details.append("Personality changed to %s!" % str(pers_after).capitalize())
		else:
			details.append("Personality was reset!")

	# Ability slot change
	var slot_before: int = before.get("active_ability_slot", 1) as int
	var slot_after: int = after_state.active_ability_slot
	if slot_after != slot_before:
		details.append("Ability slot changed to %d!" % slot_after)

	if details.is_empty():
		return header

	return header + "\n" + "\n".join(details)
