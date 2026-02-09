class_name BrickConditionEvaluator
extends RefCounted
## Parses and evaluates brick condition strings against battle state.
## Condition format: "condType:value" or "cond1|cond2" (AND logic).


## Parse a single "condType:value" into {type: String, value: String}.
static func parse_condition(condition: String) -> Dictionary:
	var parts: PackedStringArray = condition.split(":", true, 1)
	var cond_type: String = parts[0].strip_edges()
	var cond_value: String = parts[1].strip_edges() if parts.size() > 1 else ""
	return {"type": cond_type, "value": cond_value}


## Parse "cond1|cond2|cond3" into an array of parsed conditions.
static func parse_conditions(condition_string: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if condition_string.strip_edges() == "":
		return result
	var parts: PackedStringArray = condition_string.split("|")
	for part: String in parts:
		var stripped: String = part.strip_edges()
		if stripped != "":
			result.append(parse_condition(stripped))
	return result


## Evaluate a full condition string. Returns true if ALL conditions pass.
## Empty string always returns true.
static func evaluate(condition_string: String, context: Dictionary) -> bool:
	if condition_string.strip_edges() == "":
		return true
	var conditions: Array[Dictionary] = parse_conditions(condition_string)
	for cond: Dictionary in conditions:
		if not evaluate_single(cond.get("type", ""), cond.get("value", ""), context):
			return false
	return true


## Evaluate a single parsed condition against context.
static func evaluate_single(
	cond_type: String, cond_value: String, context: Dictionary,
) -> bool:
	match cond_type:
		# --- HP thresholds ---
		"userHpBelow":
			return _check_hp_below(_get_user(context), cond_value)
		"userHpAbove":
			return _check_hp_above(_get_user(context), cond_value)
		"targetHpBelow":
			return _check_hp_below(_get_target(context), cond_value)
		"targetHpAbove":
			return _check_hp_above(_get_target(context), cond_value)
		"targetAtFullHp":
			return _check_at_full_hp(_get_target(context))

		# --- Status ---
		"userHasStatus":
			return _check_has_status(_get_user(context), cond_value)
		"targetHasStatus":
			return _check_has_status(_get_target(context), cond_value)
		"targetNoStatus":
			return _check_no_status(_get_target(context), cond_value)

		# --- Element/type ---
		"damageTypeIs":
			return _check_damage_type(context, cond_value)
		"techniqueIsType":
			return _check_technique_type(context, cond_value)
		"targetIsType":
			return _check_digimon_element(_get_target(context), cond_value)
		"userIsType":
			return _check_digimon_element(_get_user(context), cond_value)

		# --- Field ---
		"weatherIs":
			return _check_weather(context, cond_value)
		"terrainIs":
			return _check_terrain(context, cond_value)

		# --- Timing ---
		"isFirstTurn":
			return _check_first_turn(context)
		"targetNotActed":
			return _check_target_not_acted(context)
		"targetActed":
			return _check_target_acted(context)

		# --- Stats ---
		"userStatHigher":
			return _check_stat_higher(_get_user(context), _get_target(context), cond_value)
		"targetStatHigher":
			return _check_stat_higher(_get_target(context), _get_user(context), cond_value)

		# --- Energy ---
		"userEpBelow":
			return _check_ep_below(_get_user(context), cond_value)
		"userEpAbove":
			return _check_ep_above(_get_user(context), cond_value)
		"targetEpBelow":
			return _check_ep_below(_get_target(context), cond_value)
		"targetEpAbove":
			return _check_ep_above(_get_target(context), cond_value)

		# --- Technique class ---
		"usingTechniqueOfClass":
			return _check_technique_class(context, cond_value)

		# --- Turn ---
		"turnIsLessThan":
			return _check_turn_less(context, cond_value)
		"turnIsMoreThan":
			return _check_turn_more(context, cond_value)

		# --- Ability ---
		"userHasAbility":
			return _check_has_ability(_get_user(context), cond_value)
		"targetHasAbility":
			return _check_has_ability(_get_target(context), cond_value)

		# --- Effectiveness ---
		"isSuperEffective":
			return _check_effectiveness(context, &"super_effective")
		"isNotVeryEffective":
			return _check_effectiveness(context, &"not_very_effective")

		# --- Last technique ---
		"lastTechniqueWas":
			return _check_last_technique(_get_user(context), cond_value)

		# --- Item conditions ---
		"userHasItem":
			return _check_has_item(_get_user(context), cond_value)
		"userHasNoItem":
			return not _check_has_item(_get_user(context), cond_value)
		"targetHasItem":
			return _check_has_item(_get_target(context), cond_value)
		"targetHasNoItem":
			return not _check_has_item(_get_target(context), cond_value)

		# --- Tier 2 stubs (return false until systems exist) ---
		"hasNoEffect", "isDoubleEffective", \
		"targetGenderIs", "sameGender", "oppositeGender", \
		"allyHasAbility":
			return false

		# --- Unknown ---
		_:
			push_warning(
				"BrickConditionEvaluator: Unknown condition type '%s'" % cond_type
			)
			return true


# --- Context helpers ---


static func _get_user(context: Dictionary) -> BattleDigimonState:
	return context.get("user") as BattleDigimonState


static func _get_target(context: Dictionary) -> BattleDigimonState:
	return context.get("target") as BattleDigimonState


static func _get_technique(context: Dictionary) -> TechniqueData:
	return context.get("technique") as TechniqueData


static func _get_battle(context: Dictionary) -> BattleState:
	return context.get("battle") as BattleState


# --- HP conditions ---


static func _check_hp_below(
	digimon: BattleDigimonState, threshold_str: String,
) -> bool:
	if digimon == null:
		return false
	var threshold: float = float(threshold_str) / 100.0
	var hp_ratio: float = float(digimon.current_hp) / float(maxi(digimon.max_hp, 1))
	return hp_ratio < threshold


static func _check_hp_above(
	digimon: BattleDigimonState, threshold_str: String,
) -> bool:
	if digimon == null:
		return false
	var threshold: float = float(threshold_str) / 100.0
	var hp_ratio: float = float(digimon.current_hp) / float(maxi(digimon.max_hp, 1))
	return hp_ratio > threshold


static func _check_at_full_hp(digimon: BattleDigimonState) -> bool:
	if digimon == null:
		return false
	return digimon.current_hp >= digimon.max_hp


# --- Status conditions ---


static func _check_has_status(
	digimon: BattleDigimonState, status_key: String,
) -> bool:
	if digimon == null:
		return false
	return digimon.has_status(StringName(status_key.to_lower()))


static func _check_no_status(
	digimon: BattleDigimonState, status_key: String,
) -> bool:
	if digimon == null:
		return false
	return not digimon.has_status(StringName(status_key.to_lower()))


# --- Element/type conditions ---


static func _check_damage_type(context: Dictionary, element_name: String) -> bool:
	var technique: TechniqueData = _get_technique(context)
	if technique == null:
		return false
	return str(technique.element_key).to_lower() == element_name.to_lower()


static func _check_technique_type(context: Dictionary, element_name: String) -> bool:
	return _check_damage_type(context, element_name)


static func _check_digimon_element(
	digimon: BattleDigimonState, element_name: String,
) -> bool:
	if digimon == null or digimon.data == null:
		return false
	var lower_name: String = element_name.to_lower()
	for elem_trait: StringName in digimon.data.element_traits:
		if str(elem_trait).to_lower() == lower_name:
			return true
	return false


# --- Field conditions ---


static func _check_weather(context: Dictionary, weather_key: String) -> bool:
	var battle: BattleState = _get_battle(context)
	if battle == null:
		return false
	return battle.field.has_weather(StringName(weather_key.to_lower()))


static func _check_terrain(context: Dictionary, terrain_key: String) -> bool:
	var battle: BattleState = _get_battle(context)
	if battle == null:
		return false
	return battle.field.has_terrain(StringName(terrain_key.to_lower()))


# --- Timing conditions ---


static func _check_first_turn(context: Dictionary) -> bool:
	var digimon: BattleDigimonState = _get_user(context)
	if digimon == null:
		return false
	return int(digimon.volatiles.get("turns_on_field", 0)) <= 1


static func _check_target_not_acted(context: Dictionary) -> bool:
	var target: BattleDigimonState = _get_target(context)
	if target == null:
		return false
	return target.volatiles.get("last_technique_key", &"") == &""


static func _check_target_acted(context: Dictionary) -> bool:
	var target: BattleDigimonState = _get_target(context)
	if target == null:
		return false
	return target.volatiles.get("last_technique_key", &"") != &""


# --- Stat comparison conditions ---


static func _check_stat_higher(
	subject: BattleDigimonState,
	other: BattleDigimonState,
	stat_abbr: String,
) -> bool:
	if subject == null or other == null:
		return false
	var battle_stat: Variant = Registry.BRICK_STAT_MAP.get(stat_abbr.to_lower())
	if battle_stat == null:
		return false
	var stage_key: Variant = Registry.BATTLE_STAT_STAGE_KEYS.get(battle_stat)
	if stage_key == null:
		return false
	var stat_key: StringName = stage_key as StringName
	return subject.get_effective_stat(stat_key) > other.get_effective_stat(stat_key)


# --- Energy conditions ---


static func _check_ep_below(
	digimon: BattleDigimonState, threshold_str: String,
) -> bool:
	if digimon == null:
		return false
	var threshold: float = float(threshold_str) / 100.0
	var ep_ratio: float = float(digimon.current_energy) / float(maxi(digimon.max_energy, 1))
	return ep_ratio < threshold


static func _check_ep_above(
	digimon: BattleDigimonState, threshold_str: String,
) -> bool:
	if digimon == null:
		return false
	var threshold: float = float(threshold_str) / 100.0
	var ep_ratio: float = float(digimon.current_energy) / float(maxi(digimon.max_energy, 1))
	return ep_ratio > threshold


# --- Technique class condition ---


static func _check_technique_class(context: Dictionary, class_name_str: String) -> bool:
	var technique: TechniqueData = _get_technique(context)
	if technique == null:
		return false
	var lower: String = class_name_str.to_lower()
	match lower:
		"physical":
			return technique.technique_class == Registry.TechniqueClass.PHYSICAL
		"special":
			return technique.technique_class == Registry.TechniqueClass.SPECIAL
		"status":
			return technique.technique_class == Registry.TechniqueClass.STATUS
	return false


# --- Turn conditions ---


static func _check_turn_less(context: Dictionary, turn_str: String) -> bool:
	var battle: BattleState = _get_battle(context)
	if battle == null:
		return false
	return battle.turn_number < int(turn_str)


static func _check_turn_more(context: Dictionary, turn_str: String) -> bool:
	var battle: BattleState = _get_battle(context)
	if battle == null:
		return false
	return battle.turn_number > int(turn_str)


# --- Ability conditions ---


static func _check_has_ability(
	digimon: BattleDigimonState, ability_key_str: String,
) -> bool:
	if digimon == null:
		return false
	return str(digimon.ability_key) == ability_key_str


# --- Effectiveness conditions ---


static func _check_effectiveness(
	context: Dictionary, expected: StringName,
) -> bool:
	var eff: Variant = context.get("effectiveness")
	if eff == null:
		return false
	return StringName(str(eff)) == expected


# --- Last technique condition ---


static func _check_last_technique(
	digimon: BattleDigimonState, technique_key_str: String,
) -> bool:
	if digimon == null:
		return false
	var last_key: StringName = digimon.volatiles.get(
		"last_technique_key", &"",
	) as StringName
	return str(last_key) == technique_key_str


# --- Item conditions ---


static func _check_has_item(
	digimon: BattleDigimonState, item_key_str: String,
) -> bool:
	if digimon == null:
		return false
	var key: StringName = StringName(item_key_str)
	return digimon.equipped_gear_key == key or digimon.equipped_consumable_key == key
