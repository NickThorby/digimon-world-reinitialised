class_name BrickExecutor
extends RefCounted
## Dispatches brick dictionaries to handler functions.
## Extensible: add new brick types as match arms + handler methods.


## Execute a single brick. Returns a result dictionary (brick-type-specific).
static func execute_brick(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	var brick_type: String = brick.get("brick", "")
	match brick_type:
		"damage":
			return _execute_damage(brick, user, target, technique, battle)
		"statusEffect":
			return _execute_status_effect(brick, user, target, battle)
		"statModifier":
			return _execute_stat_modifier(brick, user, target, battle)
		"flags":
			# Consumed at import time; no runtime execution needed
			return {"handled": true}
		_:
			push_warning("BrickExecutor: Unimplemented brick type '%s'" % brick_type)
			return {"handled": false, "brick_type": brick_type}


## Execute all bricks in order. Returns array of results.
static func execute_bricks(
	bricks: Array[Dictionary],
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for brick: Dictionary in bricks:
		results.append(execute_brick(brick, user, target, technique, battle))
	return results


## --- Brick Handlers ---


## Handle "damage" brick (standard subtype).
static func _execute_damage(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	var subtype: String = brick.get("type", "standard")
	if subtype != "standard":
		push_warning("BrickExecutor: Unimplemented damage subtype '%s'" % subtype)
		return {"handled": false, "subtype": subtype}

	var crit_bonus: int = _extract_crit_bonus(technique)
	var damage_result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, battle.rng, crit_bonus,
	)

	var actual_damage: int = target.apply_damage(damage_result.final_damage)
	target.counters["times_hit"] = int(target.counters.get("times_hit", 0)) + 1

	return {
		"handled": true,
		"damage": actual_damage,
		"was_critical": damage_result.was_critical,
		"effectiveness": damage_result.effectiveness,
		"raw_damage": damage_result.raw_damage,
	}


## Handle "statusEffect" brick — apply or remove a status condition.
static func _execute_status_effect(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var action: String = brick.get("action", "apply")
	var status_key: StringName = StringName(brick.get("status", ""))
	var chance: float = float(brick.get("chance", 100)) / 100.0

	if status_key == &"":
		return {"handled": false, "reason": "no_status_key"}

	# Resolve target based on brick target field
	var brick_target: String = brick.get("target", "target")
	var actual_target: BattleDigimonState = target
	if brick_target == "self":
		actual_target = user

	if action == "remove":
		actual_target.remove_status(status_key)
		return {"handled": true, "action": "remove", "status": status_key}

	# Apply with chance check
	if battle.rng.randf() > chance:
		return {"handled": true, "action": "apply", "missed": true, "status": status_key}

	# Status override rules
	_apply_status_overrides(actual_target, status_key)

	var duration: int = brick.get("duration", -1)
	var extra: Dictionary = {}
	if brick.has("extra"):
		extra = brick["extra"] as Dictionary

	# Inject seeder info for seeded status
	if status_key == &"seeded":
		extra["seeder_side"] = user.side_index
		extra["seeder_slot"] = user.slot_index

	var applied: bool = actual_target.add_status(status_key, duration, extra)

	return {
		"handled": true,
		"action": "apply",
		"applied": applied,
		"status": status_key,
	}


## Handle "statModifier" brick — modify stat stages on the target.
static func _execute_stat_modifier(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var modifier_type: String = brick.get("modifierType", "stage")
	if modifier_type != "stage":
		push_warning("BrickExecutor: Unimplemented statModifier type '%s'" % modifier_type)
		return {"handled": false, "modifier_type": modifier_type}

	# Chance check
	var chance: float = float(brick.get("chance", 100)) / 100.0
	if chance < 1.0 and battle.rng.randf() > chance:
		return {"handled": true, "missed": true}

	# Resolve target based on brick target field
	var brick_target: String = brick.get("target", "target")
	var actual_target: BattleDigimonState = target
	if brick_target == "self":
		actual_target = user

	var stages: int = int(brick.get("stages", 0))
	var raw_stats: Variant = brick.get("stats", [])

	# Normalise stats to array
	var stat_keys: Array = []
	if raw_stats is String:
		stat_keys = [raw_stats]
	elif raw_stats is Array:
		stat_keys = raw_stats as Array
	else:
		return {"handled": false, "reason": "invalid_stats"}

	var stat_changes: Array[Dictionary] = []
	for abbr: Variant in stat_keys:
		var abbr_str: String = str(abbr)
		var battle_stat: Variant = Registry.BRICK_STAT_MAP.get(abbr_str)
		if battle_stat == null:
			push_warning("BrickExecutor: Unknown stat abbreviation '%s'" % abbr_str)
			continue
		var stage_key: Variant = Registry.BATTLE_STAT_STAGE_KEYS.get(battle_stat)
		if stage_key == null:
			continue
		var stat_key: StringName = stage_key as StringName
		var actual: int = actual_target.modify_stat_stage(stat_key, stages)
		stat_changes.append({
			"target": actual_target,
			"stat_key": stat_key,
			"stages": stages,
			"actual": actual,
		})

	return {
		"handled": true,
		"stat_changes": stat_changes,
	}


## Extract crit stage bonus from a technique's criticalHit brick (if any).
static func _extract_crit_bonus(technique: TechniqueData) -> int:
	if technique == null:
		return 0
	for brick: Dictionary in technique.bricks:
		if brick.get("brick", "") == "criticalHit":
			return int(brick.get("stages", 0))
	return 0


## Apply status override rules (Burned removes Frostbitten/Frozen, etc.).
static func _apply_status_overrides(
	target: BattleDigimonState,
	new_status: StringName,
) -> void:
	match str(new_status).to_lower():
		"burned":
			target.remove_status(&"frostbitten")
			target.remove_status(&"frozen")
		"frostbitten":
			target.remove_status(&"burned")
			# Frostbitten on already Frostbitten -> upgrade to Frozen
			if target.has_status(&"frostbitten"):
				target.remove_status(&"frostbitten")
				target.add_status(&"frozen")
