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
		"damageModifier":
			# Consumed by damage brick handler; standalone execution is a no-op
			return {"handled": true, "skipped": true}
		"flags", "criticalHit":
			# Consumed at import/calc time; no runtime execution needed
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
## After base damage calculation, collects damageModifier bricks from the
## technique and the user's CONTINUOUS ability, evaluates their conditions,
## and applies passing multipliers/flat bonuses.
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

	# Pre-compute effectiveness for condition context
	var effectiveness: StringName = damage_result.effectiveness

	# Collect applicable damageModifier bricks
	var modifiers: Array[Dictionary] = _collect_damage_modifiers(
		user, target, technique, battle, effectiveness,
	)

	# Apply modifiers to final damage
	var modified_damage: int = damage_result.final_damage
	for modifier: Dictionary in modifiers:
		var multiplier: float = float(modifier.get("multiplier", 1.0))
		var flat_bonus: int = int(modifier.get("flatBonus", 0))
		modified_damage = int(float(modified_damage) * multiplier) + flat_bonus
	modified_damage = maxi(modified_damage, 1)

	var actual_damage: int = target.apply_damage(modified_damage)
	target.counters["times_hit"] = int(target.counters.get("times_hit", 0)) + 1

	return {
		"handled": true,
		"damage": actual_damage,
		"was_critical": damage_result.was_critical,
		"effectiveness": effectiveness,
		"raw_damage": damage_result.raw_damage,
	}


## Handle "statusEffect" brick — apply or remove a status condition.
static func _execute_status_effect(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	# Per-brick condition check
	var condition_str: String = brick.get("condition", "")
	if condition_str != "":
		var ctx: Dictionary = {"user": user, "target": target, "battle": battle}
		if not BrickConditionEvaluator.evaluate(condition_str, ctx):
			return {"handled": true, "condition_failed": true}

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

	# Status override rules (may fully handle the status, e.g. frostbitten upgrade)
	var override_status: StringName = _apply_status_overrides(actual_target, status_key)
	if override_status != &"":
		return {
			"handled": true, "action": "apply", "applied": true,
			"status": override_status,
		}

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
	# Per-brick condition check
	var condition_str: String = brick.get("condition", "")
	if condition_str != "":
		var ctx: Dictionary = {"user": user, "target": target, "battle": battle}
		if not BrickConditionEvaluator.evaluate(condition_str, ctx):
			return {"handled": true, "condition_failed": true}

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


## Collect all applicable damageModifier bricks from technique and CONTINUOUS
## abilities. Evaluates each modifier's condition string and returns only those
## that pass.
static func _collect_damage_modifiers(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	effectiveness: StringName,
) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var context: Dictionary = {
		"user": user,
		"target": target,
		"technique": technique,
		"battle": battle,
		"effectiveness": effectiveness,
	}

	# 1. Collect from technique's own bricks
	if technique != null:
		for tech_brick: Dictionary in technique.bricks:
			if tech_brick.get("brick", "") == "damageModifier":
				var cond: String = tech_brick.get("condition", "")
				if BrickConditionEvaluator.evaluate(cond, context):
					modifiers.append(tech_brick)

	# 2. Collect from user's CONTINUOUS ability bricks
	if user != null and user.ability_key != &"" \
			and not user.has_status(&"nullified"):
		var ability: AbilityData = Atlas.abilities.get(
			user.ability_key,
		) as AbilityData
		if ability != null \
				and ability.trigger == Registry.AbilityTrigger.CONTINUOUS:
			for ability_brick: Dictionary in ability.bricks:
				if ability_brick.get("brick", "") == "damageModifier":
					var cond: String = ability_brick.get("condition", "")
					if BrickConditionEvaluator.evaluate(cond, context):
						modifiers.append(ability_brick)

	return modifiers


## Extract crit stage bonus from a technique's criticalHit brick (if any).
static func _extract_crit_bonus(technique: TechniqueData) -> int:
	if technique == null:
		return 0
	for brick: Dictionary in technique.bricks:
		if brick.get("brick", "") == "criticalHit":
			return int(brick.get("stages", 0))
	return 0


## Apply status override rules (Burned removes Frostbitten/Frozen, etc.).
## Returns the override status key if the status was fully handled (e.g. upgrade),
## or &"" if normal application should proceed.
static func _apply_status_overrides(
	target: BattleDigimonState,
	new_status: StringName,
) -> StringName:
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
				return &"frozen"
	return &""
