class_name BrickExecutor
extends RefCounted
## Dispatches brick dictionaries to handler functions.
## Extensible: add new brick types as match arms + handler methods.


static var _balance: GameBalance = null


static func _get_balance() -> GameBalance:
	if _balance == null:
		_balance = load("res://data/config/game_balance.tres") as GameBalance
	return _balance


## Execute a single brick. Returns a result dictionary (brick-type-specific).
## execution_context tracks accumulated state across bricks in a technique
## (e.g. damage_dealt for recoil/drain, technique_missed for crash recoil).
static func execute_brick(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary = {},
) -> Dictionary:
	var brick_type: String = brick.get("brick", "")
	match brick_type:
		"damage":
			return _execute_damage(
				brick, user, target, technique, battle, execution_context,
			)
		"recoil":
			return _execute_recoil(
				brick, user, target, battle, execution_context,
			)
		"statusEffect":
			return _execute_status_effect(brick, user, target, battle)
		"statModifier":
			return _execute_stat_modifier(brick, user, target, battle)
		"healing":
			return _execute_healing(
				brick, user, target, technique, battle, execution_context,
			)
		"fieldEffect":
			return _execute_field_effect(brick, user, target, battle)
		"sideEffect":
			return _execute_side_effect(brick, user, target, battle)
		"hazard":
			return _execute_hazard(brick, user, target, battle)
		"protection":
			return _execute_protection(brick, user, target, battle)
		"statProtection":
			return _execute_stat_protection(brick, user, target, battle)
		"statusInteraction":
			return _execute_status_interaction(
				brick, user, target, battle, execution_context,
			)
		"conditional":
			return _execute_conditional(
				brick, user, target, technique, battle, execution_context,
			)
		"damageModifier":
			# Consumed by damage brick handler; standalone execution is a no-op
			return {"handled": true, "skipped": true}
		"criticalHit":
			# Consumed at calc time; no runtime execution needed
			return {"handled": true}
		"requirement":
			# Consumed by battle_engine pre-scan; no runtime execution needed
			return {"handled": true}
		"priorityOverride":
			# Consumed by action_sorter pre-scan; no runtime execution needed
			return {"handled": true}
		"turnEconomy":
			# Consumed by battle_engine pre-scan; no runtime execution needed
			return {"handled": true}
		"chargeRequirement":
			# Consumed by battle_engine pre-scan; no runtime execution needed
			return {"handled": true}
		"positionControl":
			return _execute_position_control(
				brick, user, target, battle,
			)
		"elementModifier":
			return _execute_element_modifier(
				brick, user, target, technique, battle, execution_context,
			)
		"resource":
			return _execute_resource(brick, user, target, battle)
		"shield":
			return _execute_shield(brick, user, battle)
		"synergy":
			return _execute_synergy(
				brick, user, target, technique, battle, execution_context,
			)
		"useRandomTechnique":
			return _execute_use_random_technique(
				brick, user, target, technique, battle, execution_context,
			)
		"transform":
			return _execute_transform(brick, user, target, battle)
		"copyTechnique":
			return _execute_copy_technique(brick, user, target, battle)
		"abilityManipulation":
			return _execute_ability_manipulation(
				brick, user, target, battle,
			)
		"turnOrder":
			return _execute_turn_order(
				brick, user, target, execution_context,
			)
		_:
			push_warning(
				"BrickExecutor: Unimplemented brick type '%s'" % brick_type,
			)
			return {"handled": false, "brick_type": brick_type}


## Execute all bricks in order. Returns array of results.
## Threads an execution_context dict through all bricks for cross-brick state.
static func execute_bricks(
	bricks: Array[Dictionary],
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var context: Dictionary = {
		"damage_dealt": 0,
		"technique_missed": false,
	}
	for brick: Dictionary in bricks:
		var result: Dictionary = execute_brick(
			brick, user, target, technique, battle, context,
		)
		# Accumulate damage dealt for recoil/drain
		if result.get("damage", 0) > 0:
			context["damage_dealt"] = int(context.get("damage_dealt", 0)) \
				+ int(result["damage"])
		results.append(result)
	return results


## --- Brick Handlers ---


## Handle "damage" brick — dispatches to subtype handlers.
## After base damage calculation, collects damageModifier bricks from the
## technique and the user's CONTINUOUS ability, evaluates their conditions,
## and applies passing multipliers/flat bonuses.
static func _execute_damage(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary = {},
) -> Dictionary:
	var subtype: String = brick.get("type", "standard")

	match subtype:
		"standard":
			return _execute_damage_standard(
				brick, user, target, technique, battle, execution_context,
			)
		"fixed":
			return _execute_damage_fixed(brick, target, execution_context)
		"percentage":
			return _execute_damage_percentage(
				brick, user, target, execution_context,
			)
		"scaling":
			return _execute_damage_scaling(
				brick, user, target, technique, battle, execution_context,
			)
		"level":
			return _execute_damage_level(
				brick, user, target, execution_context,
			)
		"returnDamage":
			return _execute_damage_return(
				brick, target, execution_context,
			)
		"counterScaling":
			return _execute_damage_counter_scaling(
				brick, user, target, technique, battle, execution_context,
			)
		_:
			push_warning(
				"BrickExecutor: Unknown damage subtype '%s'" % subtype,
			)
			return {"handled": false, "subtype": subtype}


## Standard damage: full formula with ATK/DEF, type, crit, modifiers.
static func _execute_damage_standard(
	_brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	# Collect damageModifier flags before calculating
	var flags: Dictionary = _collect_damage_modifier_flags(
		user, target, technique, battle,
	)

	var crit_info: Dictionary = _extract_crit_info(technique)
	var crit_bonus: int = int(crit_info.get("stages", 0))
	var always_crit: bool = crit_info.get("always_crit", false)
	var never_crit: bool = crit_info.get("never_crit", false)

	# Apply conditional bonuses from execution_context
	crit_bonus += int(execution_context.get("bonus_crit", 0))
	if execution_context.get("always_crit", false):
		always_crit = true

	# Pass bonus power from conditionals directly to DamageCalculator
	var bonus_power: int = int(execution_context.get("bonus_power", 0))

	# Element override from elementModifier brick
	var element_override: StringName = execution_context.get(
		"element_override", &"",
	) as StringName

	var damage_result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, battle, crit_bonus,
		always_crit, never_crit, flags, bonus_power, element_override,
	)

	# Crit immunity: if target's side has crit_immunity, undo the crit
	if damage_result.was_critical and battle != null \
			and target.side_index < battle.sides.size() \
			and battle.sides[target.side_index].has_side_effect(
				&"crit_immunity",
			):
		var balance: GameBalance = _get_balance()
		var crit_mult: float = balance.crit_damage_multiplier \
			if balance else 1.5
		damage_result.final_damage = maxi(
			roundi(float(damage_result.final_damage) / crit_mult), 1,
		)
		damage_result.raw_damage = damage_result.final_damage
		damage_result.was_critical = false

	# Pre-compute effectiveness for condition context
	var effectiveness: StringName = damage_result.effectiveness

	# Collect applicable damageModifier bricks
	var ignore_barriers: bool = flags.get("ignore_barriers", false)
	var modifiers: Array[Dictionary] = _collect_damage_modifiers(
		user, target, technique, battle, effectiveness, ignore_barriers,
	)

	# Apply modifiers to final damage
	var modified_damage: int = damage_result.final_damage
	for modifier: Dictionary in modifiers:
		var multiplier: float = float(modifier.get("multiplier", 1.0))
		var flat_bonus: int = int(modifier.get("flatBonus", 0))
		modified_damage = int(float(modified_damage) * multiplier) + flat_bonus

	# Apply conditional damage multiplier
	var cond_mult: float = float(
		execution_context.get("damage_multiplier", 1.0),
	)
	if not is_equal_approx(cond_mult, 1.0):
		modified_damage = roundi(float(modified_damage) * cond_mult)

	modified_damage = maxi(modified_damage, 1)

	var shield_result: Dictionary = _apply_shielded_damage(
		target, modified_damage, technique,
	)
	var actual_damage: int = int(shield_result.get("actual_damage", 0))
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	# Track last hit for returnDamage brick
	_track_last_hit(target, actual_damage, technique)

	var result: Dictionary = {
		"handled": true,
		"damage": actual_damage,
		"was_critical": damage_result.was_critical,
		"effectiveness": effectiveness,
		"raw_damage": damage_result.raw_damage,
	}
	if shield_result.get("shielded", false):
		result["shielded"] = true
		result["shield_type"] = shield_result.get("shield_type", "")
	if shield_result.get("endured", false):
		result["endured"] = true
	return result


## Fixed damage: flat amount, ignores stats and type.
static func _execute_damage_fixed(
	brick: Dictionary,
	target: BattleDigimonState,
	_execution_context: Dictionary,
) -> Dictionary:
	var amount: int = int(brick.get("amount", 0))
	if amount <= 0:
		return {"handled": true, "damage": 0}

	var actual: int = target.apply_damage(amount)
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	return {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": &"neutral",
		"raw_damage": amount,
	}


## Percentage damage: % of a HP source pool (user/target max/current HP).
static func _execute_damage_percentage(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_execution_context: Dictionary,
) -> Dictionary:
	var percent: float = float(brick.get("percent", 0))
	var source: String = brick.get("source", "targetMaxHp")

	var pool: int = 0
	match source:
		"userMaxHp":
			pool = user.max_hp
		"userCurrentHp":
			pool = user.current_hp
		"targetMaxHp":
			pool = target.max_hp
		"targetCurrentHp":
			pool = target.current_hp
		_:
			pool = target.max_hp

	var amount: int = maxi(floori(float(pool) * percent / 100.0), 1)
	var actual: int = target.apply_damage(amount)
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	return {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": &"neutral",
		"raw_damage": amount,
	}


## Scaling damage: uses a specific stat with power instead of technique class.
static func _execute_damage_scaling(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	var stat_abbr: String = brick.get("stat", "atk")
	var power: int = int(brick.get("power", technique.power if technique else 0))
	var battle_stat: Variant = Registry.BRICK_STAT_MAP.get(stat_abbr)
	if battle_stat == null:
		return {"handled": false, "reason": "unknown_stat"}

	var stage_key: Variant = Registry.BATTLE_STAT_STAGE_KEYS.get(battle_stat)
	var atk: float = float(user.base_stats.get(
		stage_key if stage_key else &"attack", 0,
	))
	if stage_key != null:
		var stage: int = user.stat_stages.get(stage_key as StringName, 0)
		atk = float(StatCalculator.apply_stat_stage(int(atk), stage))

	var def: float = float(target.get_effective_stat(&"defence"))
	if def <= 0.0:
		def = 1.0

	var level: float = float(
		user.source_state.level if user.source_state else 50,
	)
	var base_damage: float = 7.0 + (level / 200.0) * float(power) * (atk / def)

	# Element override from elementModifier brick
	var element_override: StringName = execution_context.get(
		"element_override", &"",
	) as StringName
	var effective_element: StringName = element_override \
		if element_override != &"" \
		else (technique.element_key if technique != null else &"")

	# Element multiplier
	var elem_mult: float = 1.0
	if effective_element != &"":
		elem_mult = DamageCalculator.calculate_element_multiplier(
			effective_element, target, battle,
		)

	var balance: GameBalance = _get_balance()
	var rng: RandomNumberGenerator = battle.rng if battle else \
		RandomNumberGenerator.new()
	var variance: float = DamageCalculator.roll_variance(rng, balance)

	var final_dmg: int = maxi(roundi(base_damage * elem_mult * variance), 1)
	var shield_result: Dictionary = _apply_shielded_damage(
		target, final_dmg, technique,
	)
	var actual: int = int(shield_result.get("actual_damage", 0))
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	_track_last_hit(target, actual, technique)

	var effectiveness: StringName = &"neutral"
	if elem_mult <= 0.0:
		effectiveness = &"immune"
	elif elem_mult >= 1.5:
		effectiveness = &"super_effective"
	elif elem_mult < 0.75:
		effectiveness = &"not_very_effective"

	var result: Dictionary = {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": effectiveness,
		"raw_damage": final_dmg,
	}
	if shield_result.get("shielded", false):
		result["shielded"] = true
		result["shield_type"] = shield_result.get("shield_type", "")
	if shield_result.get("endured", false):
		result["endured"] = true
	return result


## Level damage: damage equals user's level.
static func _execute_damage_level(
	_brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_execution_context: Dictionary,
) -> Dictionary:
	var amount: int = user.source_state.level if user.source_state else 50
	var actual: int = target.apply_damage(amount)
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	return {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": &"neutral",
		"raw_damage": amount,
	}


## Return damage: reflects a portion of the last hit taken by target.
static func _execute_damage_return(
	brick: Dictionary,
	target: BattleDigimonState,
	_execution_context: Dictionary,
) -> Dictionary:
	var source: String = brick.get("damageSource", "lastHit")
	var multiplier: float = float(brick.get("returnMultiplier", 1.0))

	var volatile_key: String = "last_hit"
	match source:
		"lastPhysicalHit":
			volatile_key = "last_physical_hit"
		"lastSpecialHit":
			volatile_key = "last_special_hit"
		"lastHit":
			volatile_key = "last_hit"

	var last_amount: int = int(target.volatiles.get(volatile_key, 0))
	if last_amount <= 0:
		return {"handled": true, "damage": 0}

	var amount: int = maxi(roundi(float(last_amount) * multiplier), 1)
	var actual: int = target.apply_damage(amount)
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	return {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": &"neutral",
		"raw_damage": amount,
	}


## Counter-scaling damage: basePower + counter * scalingPerCount (capped).
static func _execute_damage_counter_scaling(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	var base_power: int = int(brick.get("basePower", 0))
	var counter_name: String = brick.get("scalesWithCounter", "")
	var scaling_per_count: float = float(brick.get("scalingPerCount", 0))
	var scaling_cap: int = int(brick.get("scalingCap", 999))

	# Resolve counter value
	var count: int = _resolve_counter(counter_name, user, target)
	var bonus: int = mini(
		roundi(float(count) * scaling_per_count), scaling_cap,
	)
	var effective_power: int = base_power + bonus

	# Use standard damage formula with the effective power
	var level: float = float(
		user.source_state.level if user.source_state else 50,
	)
	var atk: float
	var def_val: float
	if technique != null \
			and technique.technique_class == Registry.TechniqueClass.PHYSICAL:
		atk = float(user.get_effective_stat(&"attack"))
		def_val = float(target.get_effective_stat(&"defence"))
	else:
		atk = float(user.get_effective_stat(&"special_attack"))
		def_val = float(target.get_effective_stat(&"special_defence"))
	if def_val <= 0.0:
		def_val = 1.0

	var base_damage: float = 7.0 + (level / 200.0) \
		* float(effective_power) * (atk / def_val)

	# Element override from elementModifier brick
	var element_override: StringName = execution_context.get(
		"element_override", &"",
	) as StringName
	var effective_element: StringName = element_override \
		if element_override != &"" \
		else (technique.element_key if technique != null else &"")

	var elem_mult: float = 1.0
	if effective_element != &"":
		elem_mult = DamageCalculator.calculate_element_multiplier(
			effective_element, target, battle,
		)

	var balance: GameBalance = _get_balance()
	var rng: RandomNumberGenerator = battle.rng if battle else \
		RandomNumberGenerator.new()
	var variance: float = DamageCalculator.roll_variance(rng, balance)

	var final_dmg: int = maxi(roundi(base_damage * elem_mult * variance), 1)
	var shield_result: Dictionary = _apply_shielded_damage(
		target, final_dmg, technique,
	)
	var actual: int = int(shield_result.get("actual_damage", 0))
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	_track_last_hit(target, actual, technique)

	var effectiveness: StringName = &"neutral"
	if elem_mult <= 0.0:
		effectiveness = &"immune"
	elif elem_mult >= 1.5:
		effectiveness = &"super_effective"
	elif elem_mult < 0.75:
		effectiveness = &"not_very_effective"

	var result: Dictionary = {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": effectiveness,
		"raw_damage": final_dmg,
	}
	if shield_result.get("shielded", false):
		result["shielded"] = true
		result["shield_type"] = shield_result.get("shield_type", "")
	if shield_result.get("endured", false):
		result["endured"] = true
	return result


## Track last hit amounts in target's volatiles for returnDamage brick.
static func _track_last_hit(
	target: BattleDigimonState,
	amount: int,
	technique: TechniqueData,
) -> void:
	target.volatiles["last_hit"] = amount
	if technique != null:
		if technique.technique_class == Registry.TechniqueClass.PHYSICAL:
			target.volatiles["last_physical_hit"] = amount
		elif technique.technique_class == Registry.TechniqueClass.SPECIAL:
			target.volatiles["last_special_hit"] = amount
		target.volatiles["last_technique_hit_by"] = technique.key


## Resolve a BattleCounter name to its current value.
static func _resolve_counter(
	counter_name: String, user: BattleDigimonState,
	target: BattleDigimonState,
) -> int:
	match counter_name:
		"timesHitThisBattle":
			return int(target.counters.get("times_hit", 0))
		"alliesFaintedThisBattle":
			return int(user.counters.get("allies_fainted", 0))
		"foesFaintedThisBattle":
			return int(user.counters.get("foes_fainted", 0))
		"turnsOnField":
			return int(user.volatiles.get("turns_on_field", 0))
		"userStatStagesTotal":
			var total: int = 0
			for key: StringName in user.stat_stages:
				total += maxi(int(user.stat_stages[key]), 0)
			return total
		"targetStatStagesTotal":
			var total: int = 0
			for key: StringName in target.stat_stages:
				total += maxi(int(target.stat_stages[key]), 0)
			return total
		"consecutiveUses":
			return int(user.volatiles.get("consecutive_protection_uses", 0))
	return 0


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

	# Status immunity check (side effect)
	if battle != null and actual_target.side_index < battle.sides.size() \
			and battle.sides[actual_target.side_index].has_side_effect(
				&"status_immunity",
			):
		return {"handled": true, "blocked": true, "reason": "side_immunity"}

	# Shield blocks_status check: if target has any shield with blocks_status
	var target_shields: Variant = actual_target.volatiles.get("shields", [])
	if target_shields is Array:
		for shield_entry: Variant in (target_shields as Array):
			if shield_entry is Dictionary \
					and (shield_entry as Dictionary).get(
						"blocks_status", false,
					):
				return {
					"handled": true, "blocked": true,
					"reason": "shield_blocks_status",
				}

	# Resistance-based immunity check
	var immune_element: StringName = Registry.STATUS_RESISTANCE_IMMUNITIES.get(
		status_key, &"",
	)
	if immune_element != &"":
		if actual_target.get_effective_resistance(immune_element) <= 0.5:
			return {"handled": true, "blocked": true, "reason": "resistance_immunity"}

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
## Supports subtypes: stage (default), percent, fixed, setToMax, swapWithTarget,
## scalesWithCounter.
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

	# Chance check
	var chance: float = float(brick.get("chance", 100)) / 100.0
	if chance < 1.0 and battle.rng.randf() > chance:
		return {"handled": true, "missed": true}

	# Resolve target based on brick target field
	var brick_target: String = brick.get("target", "target")
	var actual_target: BattleDigimonState = target
	if brick_target == "self":
		actual_target = user

	# --- swapWithTarget: swap all stat stages between user and target ---
	if brick.get("swapWithTarget", false):
		var stat_changes: Array[Dictionary] = []
		for key: StringName in user.stat_stages:
			var user_stage: int = user.stat_stages[key]
			var target_stage: int = actual_target.stat_stages[key]
			user.stat_stages[key] = target_stage
			actual_target.stat_stages[key] = user_stage
			stat_changes.append({
				"target": user, "stat_key": key,
				"stages": target_stage - user_stage,
				"actual": target_stage - user_stage,
			})
			stat_changes.append({
				"target": actual_target, "stat_key": key,
				"stages": user_stage - target_stage,
				"actual": user_stage - target_stage,
			})
		return {"handled": true, "stat_changes": stat_changes}

	var modifier_type: String = brick.get("modifierType", "stage")

	# --- percent / fixed: volatile non-stage modifiers ---
	if modifier_type == "percent" or modifier_type == "fixed":
		var raw_stats: Variant = brick.get("stats", [])
		var stat_keys: Array = _normalise_stat_keys(raw_stats)
		if stat_keys.is_empty():
			return {"handled": false, "reason": "invalid_stats"}

		var mod_value: Variant
		if modifier_type == "percent":
			mod_value = float(brick.get("percent", 0))
		else:
			mod_value = int(brick.get("value", 0))

		var stat_changes: Array[Dictionary] = []
		for abbr: Variant in stat_keys:
			var resolved: Dictionary = _resolve_stat_key(str(abbr))
			if resolved.is_empty():
				continue
			var stat_key: StringName = resolved["stat_key"] as StringName
			if not actual_target.volatile_stat_modifiers.has(stat_key):
				actual_target.volatile_stat_modifiers[stat_key] = []
			(actual_target.volatile_stat_modifiers[stat_key] as Array).append({
				"type": modifier_type, "value": mod_value,
			})
			stat_changes.append({
				"target": actual_target, "stat_key": stat_key,
				"type": modifier_type,
			})
		return {"handled": true, "stat_changes": stat_changes}

	# --- stage-based modifiers (default) ---
	var stages: int = int(brick.get("stages", 0))

	# --- setToMax: set all listed stats to +6 ---
	if brick.get("setToMax", false):
		var raw_stats: Variant = brick.get("stats", [])
		var stat_keys: Array = _normalise_stat_keys(raw_stats)
		var stat_changes: Array[Dictionary] = []
		for abbr: Variant in stat_keys:
			var resolved: Dictionary = _resolve_stat_key(str(abbr))
			if resolved.is_empty():
				continue
			var stat_key: StringName = resolved["stat_key"] as StringName
			var current: int = actual_target.stat_stages.get(stat_key, 0)
			var needed: int = 6 - current
			var actual: int = actual_target.modify_stat_stage(stat_key, needed)
			stat_changes.append({
				"target": actual_target, "stat_key": stat_key,
				"stages": needed, "actual": actual,
			})
		return {"handled": true, "stat_changes": stat_changes}

	# --- scalesWithCounter: stages derived from counter ---
	if brick.has("scalesWithCounter"):
		var counter_name: String = brick.get("scalesWithCounter", "")
		var count: int = _resolve_counter(counter_name, user, target)
		var scaling: float = float(brick.get("scalingPerCount", 0))
		var cap: int = int(brick.get("scalingCap", 999))
		stages = mini(roundi(float(count) * scaling), cap)

	# Stat drop immunity check
	if stages < 0 and battle != null \
			and actual_target.side_index < battle.sides.size() \
			and battle.sides[actual_target.side_index].has_side_effect(
				&"stat_drop_immunity",
			):
		return {"handled": true, "blocked": true}

	var raw_stats: Variant = brick.get("stats", [])
	var stat_keys: Array = _normalise_stat_keys(raw_stats)
	if stat_keys.is_empty() and not (raw_stats is String or raw_stats is Array):
		return {"handled": false, "reason": "invalid_stats"}

	var stat_changes: Array[Dictionary] = []
	for abbr: Variant in stat_keys:
		var resolved: Dictionary = _resolve_stat_key(str(abbr))
		if resolved.is_empty():
			continue
		var stat_key: StringName = resolved["stat_key"] as StringName

		# Stat protection check
		if _is_stat_change_blocked(actual_target, stat_key, stages):
			stat_changes.append({
				"target": actual_target, "stat_key": stat_key,
				"stages": stages, "actual": 0, "blocked": true,
				"reason": "stat_protection",
			})
			continue

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


## Normalise a stats field (String or Array) to an Array of abbreviation strings.
static func _normalise_stat_keys(raw_stats: Variant) -> Array:
	if raw_stats is String:
		return [raw_stats]
	elif raw_stats is Array:
		return raw_stats as Array
	return []


## Resolve a stat abbreviation to its stage key.
## Returns {"stat_key": StringName} or {} if unknown.
static func _resolve_stat_key(abbr_str: String) -> Dictionary:
	var battle_stat: Variant = Registry.BRICK_STAT_MAP.get(abbr_str)
	if battle_stat == null:
		push_warning(
			"BrickExecutor: Unknown stat abbreviation '%s'" % abbr_str,
		)
		return {}
	var stage_key: Variant = Registry.BATTLE_STAT_STAGE_KEYS.get(battle_stat)
	if stage_key == null:
		return {}
	return {"stat_key": stage_key as StringName}


## Check whether a stat change is blocked by stat protection volatiles.
static func _is_stat_change_blocked(
	digimon: BattleDigimonState,
	stat_key: StringName,
	stages: int,
) -> bool:
	var protections: Variant = digimon.volatiles.get("stat_protections")
	if protections == null or not (protections is Array):
		return false
	for prot: Dictionary in (protections as Array):
		var protected_stats: Variant = prot.get("stats")
		var covers: bool = false
		if protected_stats is String and (protected_stats as String) == "all":
			covers = true
		elif protected_stats is Array:
			covers = stat_key in (protected_stats as Array)
		if not covers:
			continue
		if stages < 0 and prot.get("prevent_lowering", false):
			return true
		if stages > 0 and prot.get("prevent_raising", false):
			return true
	return false


## Handle "recoil" brick — self-damage based on damage dealt or user HP.
static func _execute_recoil(
	brick: Dictionary,
	user: BattleDigimonState,
	_target: BattleDigimonState,
	_battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	var subtype: String = brick.get("type", "damagePercent")
	var amount: int = 0

	match subtype:
		"damagePercent":
			var percent: float = float(brick.get("percent", 0))
			var dealt: int = int(execution_context.get("damage_dealt", 0))
			amount = maxi(roundi(float(dealt) * percent / 100.0), 1)
		"hpPercent":
			var percent: float = float(brick.get("percent", 0))
			amount = maxi(roundi(float(user.max_hp) * percent / 100.0), 1)
		"fixed":
			amount = int(brick.get("amount", 0))
		"crash":
			# Crash recoil only applies if the technique missed
			if not execution_context.get("technique_missed", false):
				return {"handled": true, "recoil": 0}
			var percent: float = float(brick.get("percent", 50))
			amount = maxi(roundi(float(user.max_hp) * percent / 100.0), 1)
		_:
			push_warning(
				"BrickExecutor: Unknown recoil type '%s'" % subtype,
			)
			return {"handled": false, "subtype": subtype}

	if amount <= 0:
		return {"handled": true, "recoil": 0}

	var actual: int = user.apply_damage(amount)
	return {
		"handled": true,
		"recoil": actual,
		"recoil_target_side": user.side_index,
		"recoil_target_slot": user.slot_index,
	}


## Handle "healing" brick — restore HP, energy, or cure statuses.
## Subtypes: "fixed", "percentage", "energy_fixed", "energy_percentage", "drain".
static func _execute_healing(
	brick: Dictionary,
	_user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	_battle: BattleState,
	execution_context: Dictionary = {},
) -> Dictionary:
	if target == null:
		return {"handled": false, "reason": "no_target"}

	var subtype: String = brick.get("type", "fixed")
	var result: Dictionary = {"handled": true}

	match subtype:
		"fixed":
			var amount: int = int(brick.get("amount", 0))
			var healed: int = target.restore_hp(amount)
			result["healing"] = healed

		"percentage":
			var percent: float = float(brick.get("percent", 0))
			var amount: int = maxi(floori(float(target.max_hp) * percent / 100.0), 1)
			var healed: int = target.restore_hp(amount)
			result["healing"] = healed

		"energy_fixed":
			var amount: int = int(brick.get("amount", 0))
			target.restore_energy(amount)
			result["energy_restored"] = amount

		"energy_percentage":
			var percent: float = float(brick.get("percent", 0))
			var amount: int = maxi(
				floori(float(target.max_energy) * percent / 100.0), 1,
			)
			target.restore_energy(amount)
			result["energy_restored"] = amount

		"drain":
			# Heal % of damage dealt this technique execution
			var percent: float = float(brick.get("percent", 50))
			var dealt: int = int(execution_context.get("damage_dealt", 0))
			if dealt <= 0:
				result["healing"] = 0
			else:
				var heal_amount: int = maxi(
					roundi(float(dealt) * percent / 100.0), 1,
				)
				# Drain heals the user, not the target
				var healed: int = _user.restore_hp(heal_amount)
				result["healing"] = healed
				result["drain_target_side"] = _user.side_index
				result["drain_target_slot"] = _user.slot_index

		"weather":
			var balance: GameBalance = _get_balance()
			var heal_percent: float = balance.weather_healing_default \
				if balance else 0.5
			if _battle != null and _battle.field.has_weather():
				var weather_key: StringName = _battle.field.weather.get(
					"key", &"",
				) as StringName
				var config: Dictionary = Registry.WEATHER_CONFIG.get(
					weather_key, {},
				)
				var tech_element: StringName = technique.element_key \
					if technique != null else &""
				if tech_element in config.get(
					"healing_boost_elements", [],
				):
					heal_percent = balance.weather_healing_boost \
						if balance else 0.667
				elif tech_element in config.get(
					"healing_nerf_elements", [],
				):
					heal_percent = balance.weather_healing_nerf \
						if balance else 0.25
			var amount: int = maxi(
				floori(float(target.max_hp) * heal_percent), 1,
			)
			var healed: int = target.restore_hp(amount)
			result["healing"] = healed

		"status":
			# Heal + cure status
			var amount: int = 0
			if brick.has("amount"):
				amount = int(brick["amount"])
			elif brick.has("percent"):
				var pct: float = float(brick["percent"])
				amount = maxi(
					floori(float(target.max_hp) * pct / 100.0), 1,
				)
			if amount > 0:
				var healed: int = target.restore_hp(amount)
				result["healing"] = healed
			else:
				result["healing"] = 0

		_:
			push_warning(
				"BrickExecutor: Unimplemented healing subtype '%s'" % subtype,
			)
			return {"handled": false, "subtype": subtype}

	# Cure statuses if specified
	var cure_status: Variant = brick.get("cureStatus")
	if cure_status is String:
		target.remove_status(StringName(cure_status))
		result["statuses_cured"] = [cure_status]
	elif cure_status is Array:
		var cured: Array[String] = []
		for status_key: Variant in (cure_status as Array):
			target.remove_status(StringName(str(status_key)))
			cured.append(str(status_key))
		result["statuses_cured"] = cured

	return result


## Collect all applicable damageModifier bricks from technique and CONTINUOUS
## abilities/gear. Evaluates each modifier's condition string and returns only
## those that pass. If ignore_barriers is true, skips barrier modifiers.
static func _collect_damage_modifiers(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	effectiveness: StringName,
	ignore_barriers: bool = false,
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

	# 3. Collect from user's CONTINUOUS equipable gear bricks
	if user != null and not _is_gear_suppressed(user, battle):
		_collect_gear_damage_modifiers(user.equipped_gear_key, context, modifiers)
		_collect_gear_damage_modifiers(user.equipped_consumable_key, context, modifiers)

	# 4. Collect from target's CONTINUOUS gear (defensive modifiers)
	if target != null and not _is_gear_suppressed(target, battle):
		var def_context: Dictionary = context.duplicate()
		def_context["user"] = target  # Gear owner is the "user" for condition eval
		_collect_gear_damage_modifiers(
			target.equipped_gear_key, def_context, modifiers,
		)
		_collect_gear_damage_modifiers(
			target.equipped_consumable_key, def_context, modifiers,
		)

	# 5. Weather modifiers
	if battle != null and technique != null:
		var weather_mod: Dictionary = _get_weather_modifier(
			battle, technique,
		)
		if not weather_mod.is_empty():
			modifiers.append(weather_mod)

	# 6. Terrain modifiers (aerial users get no boost)
	if battle != null and technique != null and user != null:
		var terrain_mod: Dictionary = _get_terrain_modifier(
			battle, technique, user,
		)
		if not terrain_mod.is_empty():
			modifiers.append(terrain_mod)

	# 7. Barrier modifiers (side effects) — skipped if ignoreBarriers
	if not ignore_barriers \
			and battle != null and target != null and technique != null:
		var barrier_mod: Dictionary = _get_barrier_modifier(
			battle, target, technique,
		)
		if not barrier_mod.is_empty():
			modifiers.append(barrier_mod)

	return modifiers


## Collect damageModifier bricks from a single gear item.
static func _collect_gear_damage_modifiers(
	gear_key: StringName,
	context: Dictionary,
	modifiers: Array[Dictionary],
) -> void:
	if gear_key == &"":
		return
	var gear: Variant = Atlas.items.get(gear_key)
	if gear is not GearData:
		return
	var gear_data: GearData = gear as GearData
	if gear_data.trigger != Registry.AbilityTrigger.CONTINUOUS:
		return
	for gear_brick: Dictionary in gear_data.bricks:
		if gear_brick.get("brick", "") == "damageModifier":
			var cond: String = gear_brick.get("condition", "")
			if BrickConditionEvaluator.evaluate(cond, context):
				modifiers.append(gear_brick)


## Get weather damage modifier for the technique's element.
static func _get_weather_modifier(
	battle: BattleState, technique: TechniqueData,
) -> Dictionary:
	if not battle.field.has_weather():
		return {}
	var weather_key: StringName = battle.field.weather.get(
		"key", &"",
	) as StringName
	var config: Dictionary = Registry.WEATHER_CONFIG.get(weather_key, {})
	var element: StringName = technique.element_key
	var mods: Dictionary = config.get("element_modifiers", {})
	if element in mods:
		return {"multiplier": 1.0 + float(mods[element])}
	return {}


## Get terrain damage modifier for the technique's element.
## Aerial users are immune to terrain element boosts.
static func _get_terrain_modifier(
	battle: BattleState, technique: TechniqueData,
	user: BattleDigimonState,
) -> Dictionary:
	if not battle.field.has_terrain():
		return {}
	if DamageCalculator.is_aerial_on_terrain(user, battle):
		return {}
	var terrain_key: StringName = battle.field.terrain.get(
		"key", &"",
	) as StringName
	var config: Dictionary = Registry.TERRAIN_CONFIG.get(terrain_key, {})
	var element: StringName = technique.element_key
	var mods: Dictionary = config.get("element_modifiers", {})
	if element in mods:
		return {"multiplier": 1.0 + float(mods[element])}
	return {}


## Get barrier damage modifier from target's side effects.
static func _get_barrier_modifier(
	battle: BattleState,
	target: BattleDigimonState,
	technique: TechniqueData,
) -> Dictionary:
	var balance: GameBalance = _get_balance()
	var side: SideState = battle.sides[target.side_index]
	var tc: Registry.TechniqueClass = technique.technique_class
	for key: StringName in Registry.SIDE_EFFECT_CONFIG:
		var config: Dictionary = Registry.SIDE_EFFECT_CONFIG[key]
		if not config.get("barrier", false):
			continue
		if not side.has_side_effect(key):
			continue
		# dual_barrier has no technique_class filter (applies to both)
		if config.has("technique_class") and config["technique_class"] != tc:
			continue
		var mult_key: String = config.get("multiplier_key", "")
		if mult_key != "" and balance != null:
			return {"multiplier": balance.get(mult_key)}
	return {}


## Check if a Digimon's gear effects are suppressed.
static func _is_gear_suppressed(
	digimon: BattleDigimonState, battle: BattleState,
) -> bool:
	if digimon.has_status(&"dazed"):
		return true
	if battle != null and battle.field.has_global_effect(&"gear_suppression"):
		return true
	return false


## Extract crit info from a technique's criticalHit brick (if any).
## Returns {stages, always_crit, never_crit}.
static func _extract_crit_info(technique: TechniqueData) -> Dictionary:
	var info: Dictionary = {
		"stages": 0, "always_crit": false, "never_crit": false,
	}
	if technique == null:
		return info
	for brick: Dictionary in technique.bricks:
		if brick.get("brick", "") == "criticalHit":
			info["stages"] = int(brick.get("stages", 0))
			info["always_crit"] = brick.get("alwaysCrit", false)
			info["never_crit"] = brick.get("neverCrit", false)
			break
	return info


## Collect boolean flags from damageModifier bricks on the technique and
## CONTINUOUS abilities/gear. Returns a flags dictionary.
static func _collect_damage_modifier_flags(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	var flags: Dictionary = {
		"ignore_defence": false,
		"ignore_evasion": false,
		"ignore_ability": false,
		"bypass_protection": false,
		"ignore_type_immunity": false,
		"ignore_barriers": false,
		"ignore_stat_boosts": false,
	}
	var context: Dictionary = {
		"user": user, "target": target,
		"technique": technique, "battle": battle,
	}

	var sources: Array[Array] = []

	# Technique's own damageModifier bricks
	if technique != null:
		for brick: Dictionary in technique.bricks:
			if brick.get("brick", "") == "damageModifier":
				sources.append([brick])

	# User's CONTINUOUS ability
	if user != null and user.ability_key != &"" \
			and not user.has_status(&"nullified"):
		var ability: AbilityData = Atlas.abilities.get(
			user.ability_key,
		) as AbilityData
		if ability != null \
				and ability.trigger == Registry.AbilityTrigger.CONTINUOUS:
			for brick: Dictionary in ability.bricks:
				if brick.get("brick", "") == "damageModifier":
					sources.append([brick])

	# Scan all sources for boolean flags
	for source: Array in sources:
		var brick: Dictionary = source[0]
		var cond: String = brick.get("condition", "")
		if not BrickConditionEvaluator.evaluate(cond, context):
			continue
		if brick.get("ignoreDefense", false):
			flags["ignore_defence"] = true
		if brick.get("ignoreEvasion", false):
			flags["ignore_evasion"] = true
		if brick.get("ignoreAbility", false):
			flags["ignore_ability"] = true
		if brick.get("bypassProtection", false):
			flags["bypass_protection"] = true
		if brick.get("ignoreTypeImmunity", false):
			flags["ignore_type_immunity"] = true
		if brick.get("ignoreBarriers", false):
			flags["ignore_barriers"] = true
		if brick.get("ignoreStatBoosts", false):
			flags["ignore_stat_boosts"] = true

	return flags


## Public accessor for technique damageModifier flags. Called by BattleEngine
## before the accuracy check to respect ignoreEvasion/bypassProtection.
static func get_technique_flags(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	return _collect_damage_modifier_flags(user, target, technique, battle)


## Handle "fieldEffect" brick — set or remove weather, terrain, or global effects.
static func _execute_field_effect(
	brick: Dictionary,
	user: BattleDigimonState,
	_target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var effect_type: String = brick.get("type", "")
	var remove: bool = brick.get("remove", false)
	var balance: GameBalance = _get_balance()

	match effect_type:
		"weather":
			var key: StringName = StringName(brick.get("weather", ""))
			if key == &"":
				return {"handled": false, "reason": "no_weather_key"}
			if remove:
				battle.field.clear_weather()
				return {"handled": true, "weather": key, "action": "remove"}
			var w_permanent: bool = brick.get("permanent", false)
			var w_duration: int = -1 if w_permanent else int(brick.get(
				"duration", balance.default_weather_duration,
			))
			battle.field.set_weather(key, w_duration, user.side_index)
			return {"handled": true, "weather": key, "action": "set"}

		"terrain":
			var key: StringName = StringName(brick.get("terrain", ""))
			if key == &"":
				return {"handled": false, "reason": "no_terrain_key"}
			if remove:
				battle.field.clear_terrain()
				return {"handled": true, "terrain": key, "action": "remove"}
			var t_permanent: bool = brick.get("permanent", false)
			var t_duration: int = -1 if t_permanent else int(brick.get(
				"duration", balance.default_terrain_duration,
			))
			battle.field.set_terrain(key, t_duration, user.side_index)
			return {"handled": true, "terrain": key, "action": "set"}

		"global":
			var key: StringName = StringName(brick.get("effect", ""))
			if key == &"":
				return {"handled": false, "reason": "no_global_effect_key"}
			if remove:
				battle.field.remove_global_effect(key)
				return {"handled": true, "global": key, "action": "remove"}
			var g_permanent: bool = brick.get("permanent", false)
			var g_duration: int = -1 if g_permanent else int(brick.get(
				"duration", balance.default_global_effect_duration,
			))
			battle.field.add_global_effect(key, g_duration)
			return {"handled": true, "global": key, "action": "set"}

		_:
			push_warning(
				"BrickExecutor: Unknown fieldEffect type '%s'" % effect_type,
			)
			return {"handled": false, "type": effect_type}


## Handle "sideEffect" brick — add or remove side effects (barriers, immunities).
static func _execute_side_effect(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var effect_key: StringName = StringName(brick.get("effect", ""))
	if effect_key == &"":
		return {"handled": false, "reason": "no_effect_key"}

	var remove: bool = brick.get("remove", false)
	var balance: GameBalance = _get_balance()
	var se_permanent: bool = brick.get("permanent", false)
	var duration: int = -1 if se_permanent else int(brick.get(
		"duration", balance.default_side_effect_duration,
	))
	var side_target: String = brick.get("side", "user")

	var sides: Array[SideState] = _resolve_side_targets(
		side_target, user, target, battle,
	)

	for side: SideState in sides:
		if remove:
			side.remove_side_effect(effect_key)
		else:
			side.add_side_effect(effect_key, duration)

	var action: String = "remove" if remove else "set"
	return {"handled": true, "effect": effect_key, "action": action}


## Handle "hazard" brick — lay, remove, or clear hazards on a side.
static func _execute_hazard(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var side_target: String = brick.get("side", "target")
	var sides: Array[SideState] = _resolve_side_targets(
		side_target, user, target, battle,
	)

	# Remove all hazards from target sides
	if brick.get("removeAll", false):
		var cleared_side_indices: Array = []
		for side: SideState in sides:
			side.clear_hazards()
			cleared_side_indices.append(side.side_index)
		return {
			"handled": true, "hazard": &"all", "action": "removeAll",
			"removed_sides": cleared_side_indices,
		}

	# Remove a specific hazard
	var remove_key: StringName = StringName(brick.get("remove", ""))
	if remove_key != &"":
		var removed_side_indices: Array = []
		for side: SideState in sides:
			side.remove_hazard(remove_key)
			removed_side_indices.append(side.side_index)
		return {
			"handled": true, "hazard": remove_key, "action": "remove",
			"removed_sides": removed_side_indices,
		}

	# Lay a hazard
	var hazard_type: StringName = StringName(brick.get("hazardType", ""))
	if hazard_type == &"":
		return {"handled": false, "reason": "no_hazard_type"}

	var max_layers: int = int(brick.get("maxLayers", 1))
	var extra: Dictionary = {}
	if brick.has("damagePercent"):
		extra["damagePercent"] = float(brick["damagePercent"])
	if brick.has("element"):
		extra["element"] = StringName(brick["element"])
	if brick.has("stat"):
		extra["stat"] = String(brick["stat"])
	if brick.has("stages"):
		extra["stages"] = int(brick["stages"])
	if brick.has("aerialIsImmune"):
		extra["aerial_is_immune"] = bool(brick["aerialIsImmune"])
	extra["maxLayers"] = max_layers

	for side: SideState in sides:
		var current: int = side.get_hazard_layers(hazard_type)
		if current >= max_layers:
			continue
		side.add_hazard(hazard_type, 1, extra)

	return {"handled": true, "hazard": hazard_type, "action": "set"}


## Resolve side targets from a brick's "side" field.
## Returns an array of SideState references.
static func _resolve_side_targets(
	side_target: String,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Array[SideState]:
	var result: Array[SideState] = []
	match side_target:
		"user":
			if user != null and user.side_index < battle.sides.size():
				result.append(battle.sides[user.side_index])
		"target":
			if target != null and target.side_index < battle.sides.size():
				result.append(battle.sides[target.side_index])
		"allFoes":
			if user != null:
				for side: SideState in battle.sides:
					if battle.are_foes(user.side_index, side.side_index):
						result.append(side)
		"both":
			for side: SideState in battle.sides:
				result.append(side)
	return result


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
			# Burned on already burned -> upgrade to badly_burned
			if target.has_status(&"burned"):
				target.remove_status(&"burned")
				target.add_status(
					&"badly_burned", -1, {"escalation_turn": 0},
				)
				return &"badly_burned"
		"frostbitten":
			target.remove_status(&"burned")
			target.remove_status(&"badly_burned")
			# Frostbitten on already Frostbitten -> upgrade to Frozen
			if target.has_status(&"frostbitten"):
				target.remove_status(&"frostbitten")
				target.add_status(&"frozen")
				return &"frozen"
		"poisoned":
			# Poisoned on already poisoned -> upgrade to badly_poisoned
			if target.has_status(&"poisoned"):
				target.remove_status(&"poisoned")
				target.add_status(
					&"badly_poisoned", -1, {"escalation_turn": 0},
				)
				return &"badly_poisoned"
		"asleep":
			# Asleep on exhausted -> remove exhausted, apply asleep
			if target.has_status(&"exhausted"):
				target.remove_status(&"exhausted")
	return &""


## --- Protection ---


## Handle "protection" brick — set up protection for the current turn.
## Stored in user's volatiles for battle_engine to check when attacked.
static func _execute_protection(
	brick: Dictionary,
	user: BattleDigimonState,
	_target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var protection_type: String = brick.get("type", "all")

	# Fail chance escalation from consecutive uses
	var consecutive: int = int(
		user.volatiles.get("consecutive_protection_uses", 0),
	)
	if consecutive > 0:
		var success_rate: float = pow(1.0 / 3.0, consecutive)
		var rng: RandomNumberGenerator = battle.rng if battle else \
			RandomNumberGenerator.new()
		if rng.randf() >= success_rate:
			user.volatiles["consecutive_protection_uses"] = 0
			return {"handled": true, "protection_failed": true}

	# Store protection info in volatiles
	user.volatiles["protection"] = {
		"type": protection_type,
		"damage_reduction": float(brick.get("damageReduction", 0)),
		"counter_damage": float(brick.get("counterDamage", 0)),
		"reflect_status": brick.get("reflectStatus", false),
	}
	user.volatiles["consecutive_protection_uses"] = consecutive + 1
	user.volatiles["used_protection_this_turn"] = true

	return {
		"handled": true,
		"protected": true,
		"protection_type": protection_type,
	}


## --- Stat Protection ---


## Handle "statProtection" brick — prevent stat stage changes for a duration.
static func _execute_stat_protection(
	brick: Dictionary,
	user: BattleDigimonState,
	_target: BattleDigimonState,
	_battle: BattleState,
) -> Dictionary:
	# Resolve target
	var brick_target: String = brick.get("target", "self")
	var actual_target: BattleDigimonState = _target
	if brick_target == "self":
		actual_target = user

	var raw_stats: Variant = brick.get("stats", "all")
	var protected_stats: Variant
	if raw_stats is String and (raw_stats as String) == "all":
		protected_stats = "all"
	else:
		var normalised: Array = _normalise_stat_keys(raw_stats)
		var resolved: Array[StringName] = []
		for abbr: Variant in normalised:
			var r: Dictionary = _resolve_stat_key(str(abbr))
			if not r.is_empty():
				resolved.append(r["stat_key"] as StringName)
		protected_stats = resolved

	var prevent_lowering: bool = brick.get("preventLowering", false)
	var prevent_raising: bool = brick.get("preventRaising", false)
	var duration: int = int(brick.get("duration", -1))

	var entry: Dictionary = {
		"stats": protected_stats,
		"prevent_lowering": prevent_lowering,
		"prevent_raising": prevent_raising,
		"remaining_turns": duration,
	}

	if not actual_target.volatiles.has("stat_protections"):
		actual_target.volatiles["stat_protections"] = []
	(actual_target.volatiles["stat_protections"] as Array).append(entry)

	return {"handled": true, "stat_protection_applied": true}


## --- Status Interaction ---


## Handle "statusInteraction" brick — cure, transfer, or apply bonuses based
## on the user's or target's status conditions.
static func _execute_status_interaction(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	# Determine which condition to check and who has it
	var check_user: bool = brick.has("ifUserHas")
	var check_target: bool = brick.has("ifTargetHas")
	var status_key: StringName = &""
	var status_owner: BattleDigimonState = null

	if check_user:
		status_key = StringName(brick.get("ifUserHas", ""))
		status_owner = user
		if not user.has_status(status_key):
			return {"handled": true, "condition_failed": true}
	elif check_target:
		status_key = StringName(brick.get("ifTargetHas", ""))
		status_owner = target
		if not target.has_status(status_key):
			return {"handled": true, "condition_failed": true}
	else:
		return {"handled": false, "reason": "no_status_condition"}

	var result: Dictionary = {"handled": true, "interaction_applied": true}

	# Cure: remove the status from whoever has it
	if brick.get("cure", false):
		status_owner.remove_status(status_key)
		result["cured"] = str(status_key)
		result["cured_side"] = status_owner.side_index
		result["cured_slot"] = status_owner.slot_index

	# Transfer: remove from source, add to opponent
	if brick.get("transfer", false):
		status_owner.remove_status(status_key)
		var recipient: BattleDigimonState = target if check_user else user
		recipient.add_status(status_key)
		result["transferred"] = str(status_key)
		result["transferred_to_side"] = recipient.side_index
		result["transferred_to_slot"] = recipient.slot_index

	# Bonus damage multiplier
	if brick.has("bonusDamage"):
		var mult: float = float(brick["bonusDamage"])
		execution_context["damage_multiplier"] = float(
			execution_context.get("damage_multiplier", 1.0),
		) * mult
		result["bonus_damage"] = mult

	# Bonus effect
	if brick.has("bonusEffect"):
		execution_context["bonus_effect"] = brick["bonusEffect"]
		result["bonus_effect"] = brick["bonusEffect"]

	return result


## --- Conditional ---


## Handle "conditional" brick — evaluate a condition and store bonuses in
## execution_context for subsequent bricks. Execute applyBricks if present.
static func _execute_conditional(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	var condition: String = brick.get("condition", "")
	var context: Dictionary = {
		"user": user, "target": target,
		"technique": technique, "battle": battle,
	}

	if not BrickConditionEvaluator.evaluate(condition, context):
		return {"handled": true, "condition_met": false}

	# Store bonuses in execution_context for damage/crit handlers
	if brick.has("bonusPower"):
		execution_context["bonus_power"] = int(
			execution_context.get("bonus_power", 0),
		) + int(brick["bonusPower"])
	if brick.has("damageMultiplier"):
		execution_context["damage_multiplier"] = float(
			execution_context.get("damage_multiplier", 1.0),
		) * float(brick["damageMultiplier"])
	if brick.has("bonusCrit"):
		execution_context["bonus_crit"] = int(
			execution_context.get("bonus_crit", 0),
		) + int(brick["bonusCrit"])
	if brick.get("alwaysCrit", false):
		execution_context["always_crit"] = true
	if brick.get("alwaysHits", false):
		execution_context["always_hits"] = true

	# Execute nested applyBricks
	var nested_results: Array[Dictionary] = []
	var apply_bricks: Variant = brick.get("applyBricks")
	if apply_bricks is Array:
		for nested_brick: Variant in (apply_bricks as Array):
			if nested_brick is Dictionary:
				var r: Dictionary = execute_brick(
					nested_brick as Dictionary, user, target,
					technique, battle, execution_context,
				)
				nested_results.append(r)

	return {
		"handled": true,
		"condition_met": true,
		"nested_results": nested_results,
	}


## --- Pre-scan helpers ---


## Pre-scan technique bricks for requirement bricks. Returns a Dictionary
## with {failed: bool, fail_message: String} if a requirement fails.
static func check_requirements(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	if technique == null:
		return {"failed": false}

	var context: Dictionary = {
		"user": user, "target": target,
		"technique": technique, "battle": battle,
	}

	for brick: Dictionary in technique.bricks:
		if brick.get("brick", "") != "requirement":
			continue
		var timing: String = brick.get("checkTiming", "beforeExecution")
		if timing != "beforeExecution":
			continue
		var fail_condition: String = brick.get("failCondition", "")
		if fail_condition == "" :
			continue
		if BrickConditionEvaluator.evaluate(fail_condition, context):
			return {
				"failed": true,
				"fail_message": brick.get("failMessage", ""),
			}

	return {"failed": false}


## Pre-scan technique bricks for conditional bonuses that affect accuracy.
## Returns {bonus_accuracy: int, always_hits: bool} for pre-target-loop use.
static func evaluate_conditional_bonuses(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	var bonuses: Dictionary = {
		"bonus_accuracy": 0,
		"always_hits": false,
	}
	if technique == null:
		return bonuses

	var context: Dictionary = {
		"user": user, "target": target,
		"technique": technique, "battle": battle,
	}

	for brick: Dictionary in technique.bricks:
		if brick.get("brick", "") != "conditional":
			continue
		var condition: String = brick.get("condition", "")
		if not BrickConditionEvaluator.evaluate(condition, context):
			continue
		if brick.has("bonusAccuracy"):
			bonuses["bonus_accuracy"] = int(bonuses["bonus_accuracy"]) \
				+ int(brick["bonusAccuracy"])
		if brick.get("alwaysHits", false):
			bonuses["always_hits"] = true

	return bonuses


## Pre-scan technique bricks for priorityOverride. Returns the overridden
## priority (as Registry.Priority) or -1 if no override applies.
static func evaluate_priority_override(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> int:
	if technique == null:
		return -1

	var context: Dictionary = {
		"user": user, "target": target,
		"technique": technique, "battle": battle,
	}

	for brick: Dictionary in technique.bricks:
		if brick.get("brick", "") != "priorityOverride":
			continue
		var condition: String = brick.get("condition", "")
		if not BrickConditionEvaluator.evaluate(condition, context):
			continue
		# Map dex priority value (-4 to 4) to Registry.Priority
		var new_priority: int = int(brick.get("newPriority", 0))
		return _map_dex_priority(new_priority)

	return -1


## Map a dex priority integer (-4..4) to a Registry.Priority enum value.
static func _map_dex_priority(dex_priority: int) -> int:
	# DEX values: -4=MINIMUM, -3=NEGATIVE, -2=VERY_LOW, -1=LOW,
	# 0=NORMAL, 1=HIGH, 2=VERY_HIGH, 3=INSTANT, 4=MAXIMUM
	var clamped: int = clampi(dex_priority, -4, 4)
	# Registry.Priority enum: MINIMUM=0, NEGATIVE=1, ..., MAXIMUM=8
	return clamped + 4  # offset so -4 → 0 (MINIMUM), 0 → 4 (NORMAL)


## --- Turn Economy / Charge Requirement Pre-scan ---


## Pre-scan technique bricks for turnEconomy and chargeRequirement data.
## Returns a flat Dictionary with extracted turn economy fields.
static func evaluate_turn_economy(technique: TechniqueData) -> Dictionary:
	var result: Dictionary = {}
	if technique == null:
		return result

	for brick: Dictionary in technique.bricks:
		var brick_type: String = brick.get("brick", "")

		if brick_type == "turnEconomy":
			if brick.get("recharge", false):
				result["recharge"] = true
			var semi_inv: String = brick.get("semiInvulnerable", "")
			if semi_inv != "":
				result["semi_invulnerable"] = semi_inv
			if brick.has("multiTurn"):
				var mt: Dictionary = brick["multiTurn"] as Dictionary
				result["multi_turn"] = {
					"min_hits": int(mt.get("min", 2)),
					"max_hits": int(mt.get("max", 2)),
					"locked_in": mt.get("lockedIn", false),
				}
			if brick.has("multiHit"):
				var mh: Dictionary = brick["multiHit"] as Dictionary
				result["multi_hit"] = {
					"min_hits": int(mh.get("min", 2)),
					"max_hits": int(mh.get("max", 5)),
					"fixed_hits": int(mh.get("fixedHits", 0)),
				}
			if brick.has("delayedAttack"):
				var da: Dictionary = brick["delayedAttack"] as Dictionary
				result["delayed_attack"] = {
					"delay": int(da.get("delay", 2)),
					"targets_slot": da.get("targetsSlot", true),
					"bypass_protection": da.get("bypassProtection", false),
				}
			if brick.has("delayedHealing"):
				var dh: Dictionary = brick["delayedHealing"] as Dictionary
				result["delayed_healing"] = {
					"delay": int(dh.get("delay", 1)),
					"percent": float(dh.get("percent", 50)),
					"target": dh.get("target", "self"),
				}

		elif brick_type == "chargeRequirement":
			result["charge_requirement"] = {
				"turns_to_charge": int(brick.get("turnsToCharge", 1)),
				"semi_invulnerable": brick.get("semiInvulnerable", ""),
				"skip_in_weather": brick.get("skipInWeather", ""),
				"skip_in_terrain": brick.get("skipInTerrain", ""),
			}

	return result


## --- Position Control ---


## Handle "positionControl" brick — force switches and position swaps.
static func _execute_position_control(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var subtype: String = brick.get("type", "")

	match subtype:
		"forceSwitch":
			return _position_force_switch(brick, target, battle)
		"switchOut":
			return _position_switch_out(brick, user, battle)
		"switchOutPassStats":
			return _position_switch_out_pass_stats(brick, user, battle)
		"swapPositions":
			return _position_swap(brick, user, battle)
		_:
			push_warning(
				"BrickExecutor: Unknown positionControl type '%s'" % subtype,
			)
			return {"handled": false, "subtype": subtype}


## forceSwitch: force the target to switch out.
static func _position_force_switch(
	brick: Dictionary,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	if target == null or battle == null:
		return {"handled": true, "position_control_failed": true, "reason": "no_target"}

	var target_side: SideState = battle.sides[target.side_index]
	# Check reserves
	var has_reserves: bool = false
	for reserve: DigimonState in target_side.party:
		if reserve.current_hp > 0:
			has_reserves = true
			break

	if not has_reserves:
		return {
			"handled": true,
			"position_control_failed": true,
			"reason": "no_reserves",
		}

	return {
		"handled": true,
		"force_switch": true,
		"target_side": target.side_index,
		"target_slot": target.slot_index,
		"bypass_protection": brick.get("bypassProtection", false),
	}


## switchOut: user switches out after attacking.
static func _position_switch_out(
	brick: Dictionary,
	user: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	if user == null or battle == null:
		return {"handled": true, "position_control_failed": true, "reason": "no_user"}

	var user_side: SideState = battle.sides[user.side_index]
	var has_reserves: bool = false
	for reserve: DigimonState in user_side.party:
		if reserve.current_hp > 0:
			has_reserves = true
			break

	if not has_reserves:
		return {
			"handled": true,
			"position_control_failed": true,
			"reason": "no_reserves",
		}

	return {
		"handled": true,
		"switch_out": true,
		"switch_side": user.side_index,
		"switch_slot": user.slot_index,
	}


## switchOutPassStats: user switches out and passes stat stages to replacement.
static func _position_switch_out_pass_stats(
	_brick: Dictionary,
	user: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	if user == null or battle == null:
		return {"handled": true, "position_control_failed": true, "reason": "no_user"}

	var user_side: SideState = battle.sides[user.side_index]
	var has_reserves: bool = false
	for reserve: DigimonState in user_side.party:
		if reserve.current_hp > 0:
			has_reserves = true
			break

	if not has_reserves:
		return {
			"handled": true,
			"position_control_failed": true,
			"reason": "no_reserves",
		}

	return {
		"handled": true,
		"switch_out_pass_stats": true,
		"switch_side": user.side_index,
		"switch_slot": user.slot_index,
		"stat_stages": user.stat_stages.duplicate(),
		"volatile_stat_modifiers": user.volatile_stat_modifiers.duplicate(true),
	}


## swapPositions: swap two slots on the same side (doubles).
static func _position_swap(
	brick: Dictionary,
	user: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	if user == null or battle == null:
		return {"handled": true, "position_control_failed": true, "reason": "no_user"}

	var side: SideState = battle.sides[user.side_index]
	if side.slots.size() < 2:
		return {
			"handled": true,
			"position_control_failed": true,
			"reason": "single_slot_side",
		}

	var slot_a: int = user.slot_index
	var slot_b: int = int(brick.get("targetSlot", 1 - slot_a))

	return {
		"handled": true,
		"swap_positions": true,
		"side": user.side_index,
		"slot_a": slot_a,
		"slot_b": slot_b,
	}


## --- Element Modifier ---


## Handle "elementModifier" brick — modify element traits, technique element,
## or resistance profiles.
static func _execute_element_modifier(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_technique: TechniqueData,
	_battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	var subtype: String = brick.get("type", "")
	var element: StringName = StringName(brick.get("element", ""))

	# Resolve actual target for trait operations
	var brick_target: String = brick.get("target", "target")
	var actual_target: BattleDigimonState = target
	if brick_target == "self":
		actual_target = user

	match subtype:
		"addElement":
			var added: Variant = actual_target.volatiles.get(
				"element_traits_added", [],
			)
			if added is Array and element not in (added as Array):
				(added as Array).append(element)
			return {"handled": true, "element_added": str(element)}

		"removeElement":
			var removed: Variant = actual_target.volatiles.get(
				"element_traits_removed", [],
			)
			if removed is Array and element not in (removed as Array):
				(removed as Array).append(element)
			return {"handled": true, "element_removed": str(element)}

		"replaceElements":
			actual_target.volatiles["element_traits_replaced"] = element
			return {"handled": true, "elements_replaced": str(element)}

		"changeTechniqueElement":
			execution_context["element_override"] = element
			return {
				"handled": true,
				"technique_element_changed": str(element),
			}

		"matchTargetWeakness":
			var weaknesses: Array[StringName] = target.get_weaknesses()
			if weaknesses.is_empty():
				return {"handled": true, "no_weakness_found": true}
			execution_context["element_override"] = weaknesses[0]
			return {
				"handled": true,
				"matched_weakness": str(weaknesses[0]),
			}

		"changeUserResistanceProfile":
			var value: float = float(brick.get("value", 1.0))
			user.volatiles["resistance_overrides"][element] = value
			return {
				"handled": true,
				"user_resistance_changed": str(element),
				"new_value": value,
			}

		"changeTargetResistanceProfile":
			var value: float = float(brick.get("value", 1.0))
			actual_target.volatiles["resistance_overrides"][element] = \
				value
			return {
				"handled": true,
				"target_resistance_changed": str(element),
				"new_value": value,
			}

		_:
			push_warning(
				"BrickExecutor: Unknown elementModifier type '%s'" \
					% subtype,
			)
			return {"handled": false, "subtype": subtype}


## --- Resource ---


## Handle "resource" brick — gear manipulation.
static func _execute_resource(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_battle: BattleState,
) -> Dictionary:
	if brick.get("consumeItem", false):
		# Consume target's gear or consumable
		if target.equipped_gear_key != &"":
			var consumed: StringName = target.equipped_gear_key
			target.equipped_gear_key = &""
			return {
				"handled": true, "consumed": str(consumed),
				"resource_action": "consumeItem",
			}
		elif target.equipped_consumable_key != &"":
			var consumed: StringName = target.equipped_consumable_key
			target.equipped_consumable_key = &""
			return {
				"handled": true, "consumed": str(consumed),
				"resource_action": "consumeItem",
			}
		return {
			"handled": true, "resource_failed": true,
			"reason": "target_has_no_item",
		}

	if brick.get("stealItem", false):
		# Steal target's gear to user
		if target.equipped_gear_key == &"":
			return {
				"handled": true, "resource_failed": true,
				"reason": "target_has_no_item",
			}
		if user.equipped_gear_key != &"":
			return {
				"handled": true, "resource_failed": true,
				"reason": "user_already_has_gear",
			}
		var stolen: StringName = target.equipped_gear_key
		user.equipped_gear_key = stolen
		target.equipped_gear_key = &""
		return {
			"handled": true, "stolen": str(stolen),
			"resource_action": "stealItem",
		}

	if brick.get("swapItems", false):
		var user_gear: StringName = user.equipped_gear_key
		var target_gear: StringName = target.equipped_gear_key
		user.equipped_gear_key = target_gear
		target.equipped_gear_key = user_gear
		return {
			"handled": true, "resource_action": "swapItems",
			"user_got": str(target_gear),
			"target_got": str(user_gear),
		}

	if brick.get("removeItem", false):
		if target.equipped_gear_key != &"":
			var removed: StringName = target.equipped_gear_key
			target.equipped_gear_key = &""
			return {
				"handled": true, "removed": str(removed),
				"resource_action": "removeItem",
			}
		return {
			"handled": true, "resource_failed": true,
			"reason": "target_has_no_item",
		}

	var give_key: Variant = brick.get("giveItem")
	if give_key is String and str(give_key) != "":
		var item_key: StringName = StringName(str(give_key))
		var gear: Variant = Atlas.items.get(item_key)
		if gear is GearData:
			var gear_data: GearData = gear as GearData
			if gear_data.gear_slot == Registry.GearSlot.CONSUMABLE:
				if target.equipped_consumable_key != &"":
					return {
						"handled": true, "resource_failed": true,
						"reason": "target_consumable_slot_occupied",
					}
				target.equipped_consumable_key = item_key
			else:
				if target.equipped_gear_key != &"":
					return {
						"handled": true, "resource_failed": true,
						"reason": "target_gear_slot_occupied",
					}
				target.equipped_gear_key = item_key
			return {
				"handled": true, "given": str(item_key),
				"resource_action": "giveItem",
			}
		return {
			"handled": true, "resource_failed": true,
			"reason": "invalid_item_key",
		}

	return {"handled": false, "reason": "no_resource_action"}


## --- Shield ---


## Handle "shield" brick — set up protective shields on the user.
static func _execute_shield(
	brick: Dictionary,
	user: BattleDigimonState,
	_battle: BattleState,
) -> Dictionary:
	var shield_type: String = brick.get("type", "")
	var once_per_battle: bool = brick.get("oncePerBattle", false)

	# Once-per-battle check
	if once_per_battle:
		if user.has_used_shield_once(StringName(shield_type)):
			return {
				"handled": true, "shield_failed": true,
				"reason": "once_per_battle_used",
			}

	# HP cost deduction
	var hp_cost: float = float(brick.get("hpCost", 0))
	if hp_cost > 0.0:
		var cost: int = roundi(float(user.max_hp) * hp_cost)
		if cost >= user.current_hp:
			return {
				"handled": true, "shield_failed": true,
				"reason": "not_enough_hp",
			}
		user.apply_damage(cost)

	# Build shield entry
	var shield_entry: Dictionary = {"type": shield_type}

	match shield_type:
		"hpDecoy":
			var decoy_hp: int = roundi(
				float(user.max_hp) * float(brick.get("hpCost", 0.25)),
			)
			shield_entry["decoy_hp"] = decoy_hp
		"intactFormGuard":
			if brick.has("hpThreshold"):
				shield_entry["hp_threshold"] = float(
					brick["hpThreshold"],
				)
		"negateOneMoveClass":
			shield_entry["move_class"] = brick.get(
				"moveClass", "physical",
			)
		"lastStand":
			shield_entry["hp_threshold"] = float(
				brick.get("hpThreshold", 0.25),
			)

	shield_entry["break_on_hit"] = brick.get("breakOnHit", false)
	shield_entry["once_per_battle"] = once_per_battle
	if brick.get("blocksStatus", false):
		shield_entry["blocks_status"] = true

	user.add_shield(shield_entry)

	# Record once-per-battle usage
	if once_per_battle:
		user.record_shield_once_used(StringName(shield_type))

	return {
		"handled": true, "shield_applied": true,
		"shield_type": shield_type,
	}


## --- Synergy ---


## Handle "synergy" brick — check partner technique conditions and apply
## bonus power for combos/follow-ups.
static func _execute_synergy(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_technique: TechniqueData,
	_battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	var synergy_type: String = brick.get("synergyType", "")
	var partner_techniques: Variant = brick.get("partnerTechniques", [])
	var bonus_power: int = int(brick.get("bonusPower", 0))

	if partner_techniques is not Array:
		return {"handled": false, "reason": "invalid_partner_techniques"}

	var partners: Array = partner_techniques as Array
	var synergy_met: bool = false

	match synergy_type:
		"followUp":
			var last_key: StringName = user.volatiles.get(
				"last_technique_key", &"",
			) as StringName
			if str(last_key) in partners:
				synergy_met = true

		"combo":
			# Check user's last technique
			var user_last: StringName = user.volatiles.get(
				"last_technique_key", &"",
			) as StringName
			if str(user_last) in partners:
				synergy_met = true
			# Also check target's last technique hit by
			if not synergy_met and target != null:
				var target_hit: StringName = target.volatiles.get(
					"last_technique_hit_by", &"",
				) as StringName
				if str(target_hit) in partners:
					synergy_met = true

		_:
			push_warning(
				"BrickExecutor: Unknown synergy type '%s'" % synergy_type,
			)
			return {"handled": false, "synergy_type": synergy_type}

	if synergy_met and bonus_power > 0:
		execution_context["bonus_power"] = int(
			execution_context.get("bonus_power", 0),
		) + bonus_power

	return {
		"handled": true,
		"synergy_met": synergy_met,
		"synergy_type": synergy_type,
	}


## --- Session 7 Brick Handlers ---


## Handle "useRandomTechnique" brick — redirect technique to a random one.
static func _execute_use_random_technique(
	brick: Dictionary,
	user: BattleDigimonState,
	_target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary,
) -> Dictionary:
	var source: String = brick.get("source", "allTechniques")
	var exclude_list: Variant = brick.get("excludeTechniques", [])
	var only_damaging: bool = brick.get("onlyDamaging", false)
	var only_status: bool = brick.get("onlyStatus", false)
	var limit_to_flags: Variant = brick.get("limitToFlags", [])

	# Build candidate list based on source
	var candidates: Array[StringName] = []
	match source:
		"allTechniques":
			for key: StringName in Atlas.techniques:
				candidates.append(key)
		"userKnown":
			candidates = user.equipped_technique_keys.duplicate()
		"userKnownExceptThis":
			for key: StringName in user.equipped_technique_keys:
				if key != technique.key:
					candidates.append(key)
		"targetKnown":
			if _target != null:
				candidates = _target.equipped_technique_keys.duplicate()

	# Apply filters
	var filtered: Array[StringName] = []
	for key: StringName in candidates:
		# Exclude list
		if exclude_list is Array:
			var skip: bool = false
			for excl: Variant in (exclude_list as Array):
				if str(excl) == str(key):
					skip = true
					break
			if skip:
				continue

		# Class and flag filters
		var tech: TechniqueData = Atlas.techniques.get(key) as TechniqueData
		if only_damaging or only_status:
			if tech == null:
				continue
			if only_damaging \
					and tech.technique_class == Registry.TechniqueClass.STATUS:
				continue
			if only_status \
					and tech.technique_class != Registry.TechniqueClass.STATUS:
				continue

		# Flag filter — candidate must have at least one of the required flags
		if limit_to_flags is Array and not (limit_to_flags as Array).is_empty():
			if tech == null:
				tech = Atlas.techniques.get(key) as TechniqueData
			if tech == null:
				continue
			var has_flag: bool = false
			for flag_name: Variant in (limit_to_flags as Array):
				var flag_val: Variant = Registry.TechniqueFlag.get(
					str(flag_name).to_upper(), null,
				)
				if flag_val != null and (flag_val as Registry.TechniqueFlag) in tech.flags:
					has_flag = true
					break
			if not has_flag:
				continue

		filtered.append(key)

	if filtered.is_empty():
		return {
			"handled": true, "redirect_failed": true,
			"reason": "no_candidates",
		}

	# Pick randomly
	var chosen_idx: int = battle.rng.randi() % filtered.size()
	var chosen_key: StringName = filtered[chosen_idx]
	execution_context["redirect_technique"] = chosen_key

	return {"handled": true, "redirect_technique": str(chosen_key)}


## Handle "transform" brick — copy aspects of target onto user.
static func _execute_transform(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_battle: BattleState,
) -> Dictionary:
	if target == null:
		return {"handled": false, "reason": "no_target"}

	# Block double-transform
	var existing_backup: Variant = user.volatiles.get("transform_backup", {})
	if existing_backup is Dictionary and not (existing_backup as Dictionary).is_empty():
		return {"handled": true, "already_transformed": true}

	# Store backup
	user.store_transform_backup()

	# Duration
	var duration: int = int(brick.get("duration", -1))
	user.volatiles["transform_duration"] = duration

	var copied_aspects: Array[String] = []

	# copyStats — now an Array[String] of stat abbreviations
	var copy_stats: Variant = brick.get("copyStats", false)
	if copy_stats is Array:
		for stat_abbr: Variant in (copy_stats as Array):
			var abbr: String = str(stat_abbr)
			var battle_stat: Variant = Registry.BRICK_STAT_MAP.get(abbr)
			if battle_stat == null:
				continue
			var stat_enum: Registry.BattleStat = battle_stat as Registry.BattleStat
			# Map BattleStat enum to base_stats key
			var base_key: StringName = _battle_stat_to_base_key(stat_enum)
			if base_key != &"" and target.base_stats.has(base_key):
				user.base_stats[base_key] = target.base_stats[base_key]
			if abbr == "hp" and target.base_stats.has(&"hp"):
				user.max_hp = target.base_stats.get(&"hp", user.max_hp)
				user.current_hp = mini(user.current_hp, user.max_hp)
		# Recalculate energy cap if energy was copied
		if "energy" in str(copy_stats):
			user.max_energy = target.base_stats.get(
				&"energy", user.max_energy,
			)
			user.current_energy = mini(user.current_energy, user.max_energy)
		copied_aspects.append("stats")
	elif copy_stats == true:
		# Legacy bool support: copy all base stats
		user.base_stats = target.base_stats.duplicate()
		user.max_hp = target.base_stats.get(&"hp", user.max_hp)
		user.current_hp = mini(user.current_hp, user.max_hp)
		user.max_energy = target.base_stats.get(&"energy", user.max_energy)
		user.current_energy = mini(user.current_energy, user.max_energy)
		copied_aspects.append("stats")

	# copyTechniques
	if brick.get("copyTechniques", false):
		user.equipped_technique_keys = target.equipped_technique_keys.duplicate()
		user.known_technique_keys = target.known_technique_keys.duplicate()
		copied_aspects.append("techniques")

	# copyAbility
	if brick.get("copyAbility", false):
		user.ability_key = target.ability_key
		copied_aspects.append("ability")

	# copyResistances
	if brick.get("copyResistances", false):
		if target.data != null:
			user.volatiles["resistance_overrides"] = \
				target.data.resistances.duplicate()
		copied_aspects.append("resistances")

	# copyElementTraits
	if brick.get("copyElementTraits", false):
		if target.data != null and target.data.element_traits.size() > 0:
			user.volatiles["element_traits_replaced"] = \
				target.data.element_traits[0]
			if target.data.element_traits.size() > 1:
				var added: Array = []
				for i: int in range(1, target.data.element_traits.size()):
					added.append(target.data.element_traits[i])
				user.volatiles["element_traits_added"] = added
		copied_aspects.append("element_traits")

	# copyAppearance
	if brick.get("copyAppearance", false):
		user.volatiles["transform_appearance_key"] = target.data.key \
			if target.data != null else &""
		copied_aspects.append("appearance")

	return {
		"handled": true, "transformed": true,
		"copied_aspects": copied_aspects,
	}


## Map BattleStat enum to base_stats dictionary key.
static func _battle_stat_to_base_key(stat: Registry.BattleStat) -> StringName:
	match stat:
		Registry.BattleStat.HP:
			return &"hp"
		Registry.BattleStat.ATTACK:
			return &"attack"
		Registry.BattleStat.DEFENCE:
			return &"defence"
		Registry.BattleStat.SPECIAL_ATTACK:
			return &"special_attack"
		Registry.BattleStat.SPECIAL_DEFENCE:
			return &"special_defence"
		Registry.BattleStat.SPEED:
			return &"speed"
		Registry.BattleStat.ENERGY:
			return &"energy"
	return &""


## Handle "copyTechnique" brick — copy a technique into user's moveset.
static func _execute_copy_technique(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var source: String = brick.get("source", "")
	var copy_key: StringName = &""

	match source:
		"lastUsedByTarget":
			if target != null:
				copy_key = target.volatiles.get(
					"last_technique_key", &"",
				) as StringName
		"lastUsedByAny":
			copy_key = battle.last_technique_used_key
		"lastUsedOnUser":
			copy_key = user.volatiles.get(
				"last_technique_hit_by", &"",
			) as StringName
		"randomFromTarget":
			if target != null \
					and target.equipped_technique_keys.size() > 0:
				var idx: int = battle.rng.randi() \
					% target.equipped_technique_keys.size()
				copy_key = target.equipped_technique_keys[idx]

	if copy_key == &"":
		return {"handled": true, "copy_failed": true, "reason": "no_technique"}

	var tech: TechniqueData = Atlas.techniques.get(copy_key) as TechniqueData
	if tech == null:
		return {"handled": true, "copy_failed": true, "reason": "invalid_technique"}

	# Determine slot
	var replace_slot: int = int(brick.get("replaceSlot", -1))
	if replace_slot < 0 or replace_slot >= user.equipped_technique_keys.size():
		replace_slot = user.equipped_technique_keys.size() - 1
	if replace_slot < 0:
		return {"handled": true, "copy_failed": true, "reason": "no_slots"}

	var is_permanent: bool = brick.get("permanent", false)

	# Store original for restoration (unless permanent)
	if not is_permanent:
		var original_key: StringName = user.equipped_technique_keys[replace_slot]
		var duration: int = int(brick.get("duration", -1))
		var slots: Variant = user.volatiles.get("copied_technique_slots", [])
		if slots is Array:
			(slots as Array).append({
				"slot": replace_slot,
				"original_key": original_key,
				"duration": duration,
			})

	# Apply the copy
	user.equipped_technique_keys[replace_slot] = copy_key
	if copy_key not in user.known_technique_keys:
		user.known_technique_keys.append(copy_key)

	return {
		"handled": true, "technique_copied": str(copy_key),
		"replaced_slot": replace_slot,
	}


## Handle "abilityManipulation" brick — copy/swap/suppress/replace/give/nullify.
static func _execute_ability_manipulation(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	_battle: BattleState,
) -> Dictionary:
	var manipulation_type: String = brick.get("type", "")
	var duration: int = int(brick.get("duration", -1))

	match manipulation_type:
		"copy":
			if target == null:
				return {"handled": false, "reason": "no_target"}
			# Backup user's original ability (first manipulation only)
			if (user.volatiles.get("ability_backup", &"") as StringName) == &"":
				user.volatiles["ability_backup"] = user.ability_key
			user.volatiles["ability_manipulation_duration"] = duration
			user.ability_key = target.ability_key
			return {
				"handled": true, "ability_action": "copy",
				"new_ability": str(target.ability_key),
			}

		"swap":
			if target == null:
				return {"handled": false, "reason": "no_target"}
			if (user.volatiles.get("ability_backup", &"") as StringName) == &"":
				user.volatiles["ability_backup"] = user.ability_key
			if (target.volatiles.get("ability_backup", &"") as StringName) == &"":
				target.volatiles["ability_backup"] = target.ability_key
			user.volatiles["ability_manipulation_duration"] = duration
			target.volatiles["ability_manipulation_duration"] = duration
			var temp: StringName = user.ability_key
			user.ability_key = target.ability_key
			target.ability_key = temp
			return {
				"handled": true, "ability_action": "swap",
				"user_ability": str(user.ability_key),
				"target_ability": str(target.ability_key),
			}

		"suppress":
			if target == null:
				return {"handled": false, "reason": "no_target"}
			if (target.volatiles.get("ability_backup", &"") as StringName) == &"":
				target.volatiles["ability_backup"] = target.ability_key
			target.volatiles["ability_manipulation_duration"] = duration
			target.ability_key = &""
			return {"handled": true, "ability_action": "suppress"}

		"replace":
			if target == null:
				return {"handled": false, "reason": "no_target"}
			var new_ability: StringName = StringName(
				brick.get("abilityName", ""),
			)
			if (target.volatiles.get("ability_backup", &"") as StringName) == &"":
				target.volatiles["ability_backup"] = target.ability_key
			target.volatiles["ability_manipulation_duration"] = duration
			target.ability_key = new_ability
			return {
				"handled": true, "ability_action": "replace",
				"new_ability": str(new_ability),
			}

		"give":
			if target == null:
				return {"handled": false, "reason": "no_target"}
			if (target.volatiles.get("ability_backup", &"") as StringName) == &"":
				target.volatiles["ability_backup"] = target.ability_key
			target.volatiles["ability_manipulation_duration"] = duration
			target.ability_key = user.ability_key
			return {
				"handled": true, "ability_action": "give",
				"given_ability": str(user.ability_key),
			}

		"nullify":
			if target == null:
				return {"handled": false, "reason": "no_target"}
			if (target.volatiles.get("ability_backup", &"") as StringName) == &"":
				target.volatiles["ability_backup"] = target.ability_key
			target.volatiles["ability_manipulation_duration"] = duration
			target.ability_key = &""
			return {"handled": true, "ability_action": "nullify"}

	return {"handled": false, "reason": "unknown_type"}


## Handle "turnOrder" brick — manipulate action queue ordering.
static func _execute_turn_order(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	execution_context: Dictionary,
) -> Dictionary:
	var order_type: String = brick.get("type", "")
	var brick_target: String = brick.get("target", "target")

	# Resolve target Digimon
	var resolved: BattleDigimonState = target
	if brick_target == "self":
		resolved = user

	if resolved == null:
		return {"handled": false, "reason": "no_target"}

	match order_type:
		"makeTargetMoveNext":
			execution_context["turn_order_move_next"] = {
				"side": resolved.side_index,
				"slot": resolved.slot_index,
			}
			return {
				"handled": true, "turn_order_action": "moveNext",
				"target_side": resolved.side_index,
				"target_slot": resolved.slot_index,
			}
		"makeTargetMoveLast":
			execution_context["turn_order_move_last"] = {
				"side": resolved.side_index,
				"slot": resolved.slot_index,
			}
			return {
				"handled": true, "turn_order_action": "moveLast",
				"target_side": resolved.side_index,
				"target_slot": resolved.slot_index,
			}
		"repeatTargetMove":
			var last_key: StringName = resolved.volatiles.get(
				"last_technique_key", &"",
			) as StringName
			execution_context["turn_order_repeat"] = {
				"side": resolved.side_index,
				"slot": resolved.slot_index,
				"technique_key": last_key,
			}
			return {
				"handled": true, "turn_order_action": "repeat",
				"target_side": resolved.side_index,
				"target_slot": resolved.slot_index,
				"technique_key": str(last_key),
			}

	return {"handled": false, "reason": "unknown_order_type"}


## --- Shielded Damage ---


## Apply damage through shield checks. Returns a dictionary with:
## actual_damage, shielded, shield_type, endured.
static func _apply_shielded_damage(
	target: BattleDigimonState,
	damage: int,
	technique: TechniqueData,
) -> Dictionary:
	var remaining: int = damage
	var result: Dictionary = {
		"actual_damage": 0, "shielded": false,
		"shield_type": "", "endured": false,
	}

	var shields: Variant = target.volatiles.get("shields", [])
	if shields is not Array:
		result["actual_damage"] = target.apply_damage(remaining)
		return result

	var shields_arr: Array = shields as Array
	var shields_to_remove: Array[int] = []

	for i: int in range(shields_arr.size()):
		var shield: Variant = shields_arr[i]
		if shield is not Dictionary:
			continue
		var s: Dictionary = shield as Dictionary
		var stype: String = s.get("type", "")

		match stype:
			"hpDecoy":
				# Absorb damage from decoy HP
				var decoy_hp: int = int(s.get("decoy_hp", 0))
				if decoy_hp > 0:
					if remaining <= decoy_hp:
						s["decoy_hp"] = decoy_hp - remaining
						result["actual_damage"] = 0
						result["shielded"] = true
						result["shield_type"] = "hpDecoy"
						return result
					else:
						remaining -= decoy_hp
						s["decoy_hp"] = 0
						shields_to_remove.append(i)
						result["shielded"] = true
						result["shield_type"] = "hpDecoy"

			"intactFormGuard":
				# Only blocks technique hits (not hazard etc.)
				if technique != null:
					var threshold: float = float(
						s.get("hp_threshold", -1.0),
					)
					var triggers: bool = false
					if threshold < 0.0:
						# No threshold — always triggers (Disguise)
						triggers = true
					else:
						var hp_pct: float = float(target.current_hp) \
							/ float(maxi(target.max_hp, 1))
						triggers = hp_pct >= threshold
					if triggers:
						if s.get("break_on_hit", false):
							shields_to_remove.append(i)
						result["actual_damage"] = 0
						result["shielded"] = true
						result["shield_type"] = "intactFormGuard"
						_remove_shields(shields_arr, shields_to_remove)
						return result

			"negateOneMoveClass":
				if technique != null:
					var move_class: String = s.get(
						"move_class", "physical",
					)
					var matches: bool = false
					if move_class == "physical" and technique.technique_class \
							== Registry.TechniqueClass.PHYSICAL:
						matches = true
					elif move_class == "special" \
							and technique.technique_class \
							== Registry.TechniqueClass.SPECIAL:
						matches = true
					if matches:
						shields_to_remove.append(i)
						result["actual_damage"] = 0
						result["shielded"] = true
						result["shield_type"] = "negateOneMoveClass"
						_remove_shields(shields_arr, shields_to_remove)
						return result

			"lastStand":
				var threshold: float = float(
					s.get("hp_threshold", 0.25),
				)
				var hp_pct: float = float(target.current_hp) \
					/ float(maxi(target.max_hp, 1))
				if hp_pct <= threshold:
					remaining = maxi(roundi(float(remaining) * 0.5), 1)

			"endure":
				# Handled after damage application below
				pass

	_remove_shields(shields_arr, shields_to_remove)

	# Check endure: if damage would faint, survive with 1 HP
	if remaining >= target.current_hp:
		for i: int in range(shields_arr.size()):
			var shield: Variant = shields_arr[i]
			if shield is not Dictionary:
				continue
			var s: Dictionary = shield as Dictionary
			if s.get("type", "") == "endure":
				remaining = target.current_hp - 1
				if remaining < 0:
					remaining = 0
				result["endured"] = true
				if s.get("break_on_hit", false):
					shields_arr.erase(s)
				break

	result["actual_damage"] = target.apply_damage(remaining)
	return result


## Remove shields by index (in reverse order to preserve indices).
static func _remove_shields(
	shields: Array, indices: Array[int],
) -> void:
	indices.sort()
	for i: int in range(indices.size() - 1, -1, -1):
		if indices[i] < shields.size():
			shields.remove_at(indices[i])
