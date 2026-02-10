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
				brick, user, target, battle, execution_context,
			)
		"fieldEffect":
			return _execute_field_effect(brick, user, target, battle)
		"sideEffect":
			return _execute_side_effect(brick, user, target, battle)
		"hazard":
			return _execute_hazard(brick, user, target, battle)
		"protection":
			return _execute_protection(brick, user, target, battle)
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

	var damage_result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, battle, crit_bonus,
		always_crit, never_crit, flags, bonus_power,
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

	var actual_damage: int = target.apply_damage(modified_damage)
	target.counters["times_hit"] = int(
		target.counters.get("times_hit", 0),
	) + 1

	# Track last hit for returnDamage brick
	_track_last_hit(target, actual_damage, technique)

	return {
		"handled": true,
		"damage": actual_damage,
		"was_critical": damage_result.was_critical,
		"effectiveness": effectiveness,
		"raw_damage": damage_result.raw_damage,
	}


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
	_execution_context: Dictionary,
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

	# Element multiplier
	var elem_mult: float = 1.0
	if technique != null:
		elem_mult = DamageCalculator.calculate_element_multiplier(
			technique.element_key, target,
		)

	var balance: GameBalance = _get_balance()
	var rng: RandomNumberGenerator = battle.rng if battle else \
		RandomNumberGenerator.new()
	var variance: float = DamageCalculator.roll_variance(rng, balance)

	var final_dmg: int = maxi(roundi(base_damage * elem_mult * variance), 1)
	var actual: int = target.apply_damage(final_dmg)
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

	return {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": effectiveness,
		"raw_damage": final_dmg,
	}


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
	_execution_context: Dictionary,
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

	var elem_mult: float = 1.0
	if technique != null:
		elem_mult = DamageCalculator.calculate_element_multiplier(
			technique.element_key, target,
		)

	var balance: GameBalance = _get_balance()
	var rng: RandomNumberGenerator = battle.rng if battle else \
		RandomNumberGenerator.new()
	var variance: float = DamageCalculator.roll_variance(rng, balance)

	var final_dmg: int = maxi(roundi(base_damage * elem_mult * variance), 1)
	var actual: int = target.apply_damage(final_dmg)
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

	return {
		"handled": true,
		"damage": actual,
		"was_critical": false,
		"effectiveness": effectiveness,
		"raw_damage": final_dmg,
	}


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

	# Element-trait immunity check
	var immune_element: StringName = Registry.STATUS_ELEMENT_IMMUNITIES.get(
		status_key, &"",
	)
	if immune_element != &"" and actual_target.data != null:
		if immune_element in actual_target.data.element_traits:
			return {"handled": true, "blocked": true, "reason": "element_immunity"}

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

	# Stat drop immunity check
	if stages < 0 and battle != null \
			and actual_target.side_index < battle.sides.size() \
			and battle.sides[actual_target.side_index].has_side_effect(
				&"stat_drop_immunity",
			):
		return {"handled": true, "blocked": true}

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

	# 6. Barrier modifiers (side effects) — skipped if ignoreBarriers
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
	var balance: GameBalance = _get_balance()
	var weather_key: StringName = battle.field.weather.get(
		"key", &"",
	) as StringName
	var element: StringName = technique.element_key

	match str(weather_key):
		"sun":
			if element == &"fire":
				return {"multiplier": balance.weather_damage_boost}
			elif element == &"water":
				return {"multiplier": balance.weather_damage_nerf}
		"rain":
			if element == &"water":
				return {"multiplier": balance.weather_damage_boost}
			elif element == &"fire":
				return {"multiplier": balance.weather_damage_nerf}
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

	if side.has_side_effect(&"dual_barrier"):
		return {"multiplier": balance.dual_barrier_multiplier}
	if tc == Registry.TechniqueClass.PHYSICAL \
			and side.has_side_effect(&"physical_barrier"):
		return {"multiplier": balance.physical_barrier_multiplier}
	if tc == Registry.TechniqueClass.SPECIAL \
			and side.has_side_effect(&"special_barrier"):
		return {"multiplier": balance.special_barrier_multiplier}
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
			var duration: int = int(brick.get(
				"duration", balance.default_weather_duration,
			))
			battle.field.set_weather(key, duration, user.side_index)
			return {"handled": true, "weather": key, "action": "set"}

		"terrain":
			var key: StringName = StringName(brick.get("terrain", ""))
			if key == &"":
				return {"handled": false, "reason": "no_terrain_key"}
			if remove:
				battle.field.clear_terrain()
				return {"handled": true, "terrain": key, "action": "remove"}
			var duration: int = int(brick.get(
				"duration", balance.default_terrain_duration,
			))
			battle.field.set_terrain(key, duration, user.side_index)
			return {"handled": true, "terrain": key, "action": "set"}

		"global":
			var key: StringName = StringName(brick.get("effect", ""))
			if key == &"":
				return {"handled": false, "reason": "no_global_effect_key"}
			if remove:
				battle.field.remove_global_effect(key)
				return {"handled": true, "global": key, "action": "remove"}
			var duration: int = int(brick.get(
				"duration", balance.default_global_effect_duration,
			))
			battle.field.add_global_effect(key, duration)
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
	var duration: int = int(brick.get(
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
		for side: SideState in sides:
			side.clear_hazards()
		return {"handled": true, "hazard": &"all", "action": "removeAll"}

	# Remove a specific hazard
	var remove_key: StringName = StringName(brick.get("remove", ""))
	if remove_key != &"":
		for side: SideState in sides:
			side.remove_hazard(remove_key)
		return {"handled": true, "hazard": remove_key, "action": "remove"}

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
