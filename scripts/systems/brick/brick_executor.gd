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
		"healing":
			return _execute_healing(brick, user, target, battle)
		"fieldEffect":
			return _execute_field_effect(brick, user, target, battle)
		"sideEffect":
			return _execute_side_effect(brick, user, target, battle)
		"hazard":
			return _execute_hazard(brick, user, target, battle)
		"damageModifier":
			# Consumed by damage brick handler; standalone execution is a no-op
			return {"handled": true, "skipped": true}
		"criticalHit":
			# Consumed at calc time; no runtime execution needed
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
		user, target, technique, battle, crit_bonus,
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


## Handle "healing" brick — restore HP, energy, or cure statuses.
## Subtypes: "fixed", "percentage", "energy_fixed", "energy_percentage".
static func _execute_healing(
	brick: Dictionary,
	_user: BattleDigimonState,
	target: BattleDigimonState,
	_battle: BattleState,
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
			var amount: int = maxi(floori(float(target.max_energy) * percent / 100.0), 1)
			target.restore_energy(amount)
			result["energy_restored"] = amount

		_:
			push_warning("BrickExecutor: Unimplemented healing subtype '%s'" % subtype)
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
## those that pass.
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

	# 6. Barrier modifiers (side effects)
	if battle != null and target != null and technique != null:
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


## Extract crit stage bonus from a technique's criticalHit brick (if any).
static func _extract_crit_bonus(technique: TechniqueData) -> int:
	if technique == null:
		return 0
	for brick: Dictionary in technique.bricks:
		if brick.get("brick", "") == "criticalHit":
			return int(brick.get("stages", 0))
	return 0


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
