extends GutTest
## Unit tests for BrickConditionEvaluator condition parsing and evaluation.

var _battle: BattleState
var _user: BattleDigimonState
var _target: BattleDigimonState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_user = _battle.get_digimon_at(0, 0)
	_target = _battle.get_digimon_at(1, 0)


# --- Parsing ---


func test_parse_single_condition_with_value() -> void:
	var result: Dictionary = BrickConditionEvaluator.parse_condition("userHpBelow:50")
	assert_eq(result.get("type", ""), "userHpBelow")
	assert_eq(result.get("value", ""), "50")


func test_parse_single_condition_without_value() -> void:
	var result: Dictionary = BrickConditionEvaluator.parse_condition("targetAtFullHp")
	assert_eq(result.get("type", ""), "targetAtFullHp")
	assert_eq(result.get("value", ""), "")


func test_parse_multiple_conditions() -> void:
	var result: Array[Dictionary] = BrickConditionEvaluator.parse_conditions(
		"damageTypeIs:fire|userHpBelow:50"
	)
	assert_eq(result.size(), 2)
	assert_eq(result[0].get("type", ""), "damageTypeIs")
	assert_eq(result[0].get("value", ""), "fire")
	assert_eq(result[1].get("type", ""), "userHpBelow")
	assert_eq(result[1].get("value", ""), "50")


func test_parse_empty_string_returns_empty_array() -> void:
	var result: Array[Dictionary] = BrickConditionEvaluator.parse_conditions("")
	assert_eq(result.size(), 0)


# --- Empty condition ---


func test_empty_condition_returns_true() -> void:
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("", ctx))


# --- HP conditions ---


func test_user_hp_below_true_at_49_percent() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.49)
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("userHpBelow:50", ctx))


func test_user_hp_below_false_at_50_percent() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.50)
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("userHpBelow:50", ctx))


func test_user_hp_below_false_at_51_percent() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.51)
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("userHpBelow:50", ctx))


func test_user_hp_above_true_at_51_percent() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.51)
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("userHpAbove:50", ctx))


func test_user_hp_above_false_at_50_percent() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.50)
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("userHpAbove:50", ctx))


func test_target_hp_below() -> void:
	_target.current_hp = 1
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetHpBelow:50", ctx))


func test_target_hp_above() -> void:
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetHpAbove:50", ctx))


func test_target_at_full_hp_true() -> void:
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetAtFullHp", ctx))


func test_target_at_full_hp_false() -> void:
	_target.current_hp -= 1
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("targetAtFullHp", ctx))


# --- Status conditions ---


func test_user_has_status_true() -> void:
	_user.add_status(&"burned")
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("userHasStatus:burned", ctx))


func test_user_has_status_false() -> void:
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("userHasStatus:burned", ctx))


func test_target_has_status() -> void:
	_target.add_status(&"paralysed")
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetHasStatus:paralysed", ctx))


func test_target_no_status_true() -> void:
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetNoStatus:burned", ctx))


func test_target_no_status_false() -> void:
	_target.add_status(&"burned")
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("targetNoStatus:burned", ctx))


# --- Element/type conditions ---


func test_damage_type_is_matching() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var ctx: Dictionary = {"technique": technique}
	assert_true(BrickConditionEvaluator.evaluate("damageTypeIs:fire", ctx))


func test_damage_type_is_not_matching() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_ice_beam"]
	var ctx: Dictionary = {"technique": technique}
	assert_false(BrickConditionEvaluator.evaluate("damageTypeIs:fire", ctx))


func test_damage_type_case_insensitive() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var ctx: Dictionary = {"technique": technique}
	assert_true(BrickConditionEvaluator.evaluate("damageTypeIs:Fire", ctx))


func test_technique_is_type_same_as_damage_type() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var ctx: Dictionary = {"technique": technique}
	assert_true(BrickConditionEvaluator.evaluate("techniqueIsType:fire", ctx))


func test_user_has_trait_element_matching() -> void:
	# test_agumon has element_traits [&"fire"]
	var ctx: Dictionary = {"user": _user}
	assert_true(BrickConditionEvaluator.evaluate("userHasTrait:element:fire", ctx))


func test_target_has_trait_element_matching() -> void:
	# test_agumon has element_traits [&"fire"]
	var ctx: Dictionary = {"target": _user}  # _user is test_agumon
	assert_true(BrickConditionEvaluator.evaluate("targetHasTrait:element:fire", ctx))


func test_target_has_trait_element_not_matching() -> void:
	var ctx: Dictionary = {"target": _target}  # _target is test_gabumon with ice
	assert_false(BrickConditionEvaluator.evaluate("targetHasTrait:element:fire", ctx))


func test_user_has_trait_movement() -> void:
	# test_agumon has movement_traits [&"terrestrial"]
	var ctx: Dictionary = {"user": _user}
	assert_true(BrickConditionEvaluator.evaluate("userHasTrait:movement:terrestrial", ctx))


func test_user_has_trait_size() -> void:
	# test_agumon has size_trait &"medium"
	var ctx: Dictionary = {"user": _user}
	assert_true(BrickConditionEvaluator.evaluate("userHasTrait:size:medium", ctx))


func test_user_has_trait_type() -> void:
	# test_agumon has type_trait &"dragon"
	var ctx: Dictionary = {"user": _user}
	assert_true(BrickConditionEvaluator.evaluate("userHasTrait:type:dragon", ctx))


func test_user_has_trait_wrong_category() -> void:
	# test_agumon has fire in element, not in type
	var ctx: Dictionary = {"user": _user}
	assert_false(BrickConditionEvaluator.evaluate("userHasTrait:type:fire", ctx))


func test_user_has_trait_invalid_category() -> void:
	var ctx: Dictionary = {"user": _user}
	assert_false(BrickConditionEvaluator.evaluate("userHasTrait:invalid:fire", ctx))


func test_user_has_trait_missing_category() -> void:
	# No colon separator in value — should fail
	var ctx: Dictionary = {"user": _user}
	assert_false(BrickConditionEvaluator.evaluate("userHasTrait:fire", ctx))


# --- Field conditions ---


func test_weather_is_matching() -> void:
	_battle.field.set_weather(&"rain", 5, 0)
	var ctx: Dictionary = {"battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("weatherIs:rain", ctx))


func test_weather_is_not_matching() -> void:
	_battle.field.set_weather(&"sun", 5, 0)
	var ctx: Dictionary = {"battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("weatherIs:rain", ctx))


func test_weather_is_no_weather() -> void:
	var ctx: Dictionary = {"battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("weatherIs:rain", ctx))


func test_terrain_is_matching() -> void:
	_battle.field.set_terrain(&"flooded", 5, 0)
	var ctx: Dictionary = {"battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("terrainIs:flooded", ctx))


func test_terrain_is_not_matching() -> void:
	var ctx: Dictionary = {"battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("terrainIs:flooded", ctx))


# --- Timing conditions ---


func test_is_first_turn_true() -> void:
	_user.volatiles["turns_on_field"] = 1
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("isFirstTurn", ctx))


func test_is_first_turn_false_after_many_turns() -> void:
	_user.volatiles["turns_on_field"] = 3
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("isFirstTurn", ctx))


func test_target_not_acted_true() -> void:
	_target.volatiles["last_technique_key"] = &""
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetNotActed", ctx))


func test_target_not_acted_false() -> void:
	_target.volatiles["last_technique_key"] = &"test_tackle"
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("targetNotActed", ctx))


func test_target_acted_true() -> void:
	_target.volatiles["last_technique_key"] = &"test_tackle"
	var ctx: Dictionary = {"target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetActed", ctx))


# --- Stat comparison ---


func test_user_stat_higher_true() -> void:
	_user.modify_stat_stage(&"attack", 6)
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("userStatHigher:atk", ctx))


func test_user_stat_higher_false_when_equal() -> void:
	# With default stages both at 0, the base stats determine. test_agumon has
	# base_atk=100, test_gabumon has base_atk=55, so agumon is already higher.
	# Lower agumon's stage to make it equal or lower:
	_user.modify_stat_stage(&"attack", -6)
	_target.modify_stat_stage(&"attack", 6)
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	# With extreme stage swings, target should be higher
	assert_false(BrickConditionEvaluator.evaluate("userStatHigher:atk", ctx))


func test_target_stat_higher() -> void:
	_target.modify_stat_stage(&"speed", 6)
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetStatHigher:spe", ctx))


# --- Energy conditions ---


func test_user_ep_below_true() -> void:
	_user.current_energy = 0
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("userEpBelow:50", ctx))


func test_user_ep_below_false() -> void:
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("userEpBelow:50", ctx))


func test_user_ep_above_true() -> void:
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("userEpAbove:50", ctx))


func test_target_ep_below() -> void:
	_target.current_energy = 0
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetEpBelow:50", ctx))


func test_target_ep_above() -> void:
	var ctx: Dictionary = {"user": _user, "target": _target, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("targetEpAbove:50", ctx))


# --- Technique class ---


func test_using_technique_of_class_physical() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var ctx: Dictionary = {"technique": technique}
	assert_true(BrickConditionEvaluator.evaluate("usingTechniqueOfClass:physical", ctx))


func test_using_technique_of_class_mismatch() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var ctx: Dictionary = {"technique": technique}
	assert_false(BrickConditionEvaluator.evaluate("usingTechniqueOfClass:special", ctx))


func test_using_technique_of_class_status() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_status_burn"]
	var ctx: Dictionary = {"technique": technique}
	assert_true(BrickConditionEvaluator.evaluate("usingTechniqueOfClass:status", ctx))


# --- Turn conditions ---


func test_turn_is_less_than_true() -> void:
	_battle.turn_number = 2
	var ctx: Dictionary = {"battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("turnIsLessThan:5", ctx))


func test_turn_is_less_than_false() -> void:
	_battle.turn_number = 10
	var ctx: Dictionary = {"battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("turnIsLessThan:5", ctx))


func test_turn_is_more_than_true() -> void:
	_battle.turn_number = 10
	var ctx: Dictionary = {"battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("turnIsMoreThan:5", ctx))


func test_turn_is_more_than_false() -> void:
	_battle.turn_number = 2
	var ctx: Dictionary = {"battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("turnIsMoreThan:5", ctx))


# --- Ability conditions ---


func test_user_has_ability_true() -> void:
	_user.ability_key = &"test_ability_on_entry"
	var ctx: Dictionary = {"user": _user}
	assert_true(
		BrickConditionEvaluator.evaluate("userHasAbility:test_ability_on_entry", ctx),
	)


func test_user_has_ability_false() -> void:
	_user.ability_key = &"test_ability_on_entry"
	var ctx: Dictionary = {"user": _user}
	assert_false(
		BrickConditionEvaluator.evaluate("userHasAbility:other_ability", ctx),
	)


func test_target_has_ability() -> void:
	_target.ability_key = &"test_ability_on_damage"
	var ctx: Dictionary = {"target": _target}
	assert_true(
		BrickConditionEvaluator.evaluate("targetHasAbility:test_ability_on_damage", ctx),
	)


# --- Effectiveness conditions ---


func test_is_super_effective_true() -> void:
	var ctx: Dictionary = {"effectiveness": &"super_effective"}
	assert_true(BrickConditionEvaluator.evaluate("isSuperEffective", ctx))


func test_is_super_effective_false() -> void:
	var ctx: Dictionary = {"effectiveness": &"neutral"}
	assert_false(BrickConditionEvaluator.evaluate("isSuperEffective", ctx))


func test_is_not_very_effective_true() -> void:
	var ctx: Dictionary = {"effectiveness": &"not_very_effective"}
	assert_true(BrickConditionEvaluator.evaluate("isNotVeryEffective", ctx))


func test_is_not_very_effective_false() -> void:
	var ctx: Dictionary = {"effectiveness": &"super_effective"}
	assert_false(BrickConditionEvaluator.evaluate("isNotVeryEffective", ctx))


# --- Last technique ---


func test_last_technique_was_matching() -> void:
	_user.volatiles["last_technique_key"] = &"test_tackle"
	var ctx: Dictionary = {"user": _user}
	assert_true(BrickConditionEvaluator.evaluate("lastTechniqueWas:test_tackle", ctx))


func test_last_technique_was_not_matching() -> void:
	_user.volatiles["last_technique_key"] = &"test_fire_blast"
	var ctx: Dictionary = {"user": _user}
	assert_false(BrickConditionEvaluator.evaluate("lastTechniqueWas:test_tackle", ctx))


# --- Multiple conditions (AND logic) ---


func test_multiple_conditions_all_true() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.3)
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var ctx: Dictionary = {
		"user": _user, "target": _target,
		"technique": technique, "battle": _battle,
	}
	assert_true(
		BrickConditionEvaluator.evaluate("damageTypeIs:fire|userHpBelow:50", ctx),
	)


func test_multiple_conditions_one_false() -> void:
	# HP is full, so userHpBelow:50 fails
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var ctx: Dictionary = {
		"user": _user, "target": _target,
		"technique": technique, "battle": _battle,
	}
	assert_false(
		BrickConditionEvaluator.evaluate("damageTypeIs:fire|userHpBelow:50", ctx),
	)


func test_multiple_conditions_both_false() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_ice_beam"]
	var ctx: Dictionary = {
		"user": _user, "target": _target,
		"technique": technique, "battle": _battle,
	}
	assert_false(
		BrickConditionEvaluator.evaluate("damageTypeIs:fire|userHpBelow:50", ctx),
	)


# --- Unknown type ---


func test_unknown_type_returns_true() -> void:
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_true(BrickConditionEvaluator.evaluate("totallyUnknownCondition:42", ctx))


# --- Technique flag conditions ---


func test_move_has_flag_true() -> void:
	# test_fire_defrost has DEFROST flag
	var technique: TechniqueData = Atlas.techniques[&"test_fire_defrost"]
	var ctx: Dictionary = {"technique": technique}
	assert_true(BrickConditionEvaluator.evaluate("moveHasFlag:defrost", ctx))


func test_move_has_flag_false() -> void:
	# test_tackle has no flags
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var ctx: Dictionary = {"technique": technique}
	assert_false(BrickConditionEvaluator.evaluate("moveHasFlag:contact", ctx))


func test_move_has_flag_contact_on_flagged_technique() -> void:
	# Create a technique with CONTACT flag for this test
	var technique: TechniqueData = Atlas.techniques[&"test_fire_defrost"]
	# test_fire_defrost only has DEFROST, not CONTACT
	var ctx: Dictionary = {"technique": technique}
	assert_false(BrickConditionEvaluator.evaluate("moveHasFlag:contact", ctx))


func test_move_has_flag_unknown_flag() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_fire_defrost"]
	var ctx: Dictionary = {"technique": technique}
	assert_false(BrickConditionEvaluator.evaluate("moveHasFlag:nonexistent", ctx))


# --- Ally trait conditions ---


func test_ally_has_trait_true_in_doubles() -> void:
	# Create a 2v2 battle so side 0 has test_agumon + test_patamon
	var battle_2v2: BattleState = TestBattleFactory.create_2v2_battle()
	var user: BattleDigimonState = battle_2v2.get_digimon_at(0, 0)  # test_agumon
	var ally: BattleDigimonState = battle_2v2.get_digimon_at(0, 1)  # test_patamon
	# test_patamon has element_traits [&"light"]
	var ctx: Dictionary = {"user": user, "battle": battle_2v2}
	assert_true(BrickConditionEvaluator.evaluate("allyHasTrait:element:light", ctx))


func test_ally_has_trait_false_no_ally_has_it() -> void:
	var battle_2v2: BattleState = TestBattleFactory.create_2v2_battle()
	var user: BattleDigimonState = battle_2v2.get_digimon_at(0, 0)  # test_agumon
	var ctx: Dictionary = {"user": user, "battle": battle_2v2}
	# Neither agumon nor patamon have dark element trait
	assert_false(BrickConditionEvaluator.evaluate("allyHasTrait:element:dark", ctx))


func test_ally_has_trait_false_in_singles() -> void:
	# In 1v1, user has no allies in slots
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("allyHasTrait:element:fire", ctx))


# --- Tier 2 stubs ---


func test_tier2_stub_returns_false() -> void:
	var ctx: Dictionary = {"user": _user, "battle": _battle}
	assert_false(BrickConditionEvaluator.evaluate("userHasItem:potion", ctx))
	assert_false(BrickConditionEvaluator.evaluate("targetGenderIs:male", ctx))
	assert_false(BrickConditionEvaluator.evaluate("allyHasAbility:blaze", ctx))
