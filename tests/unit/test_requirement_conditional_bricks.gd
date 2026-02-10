extends GutTest
## Unit tests for requirement, conditional, priorityOverride bricks,
## and pre-scan helper functions.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Requirement brick ---


func test_requirement_blocks_technique_when_condition_met() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var target_hp_before: int = target.current_hp

	# Reduce user HP below 50% to trigger the fail condition
	user.apply_damage(user.max_hp)
	user.restore_hp(user.max_hp / 4)  # 25% HP

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_require_hp", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, target_hp_before,
		"Requirement should block technique when user HP < 50%%",
	)


func test_requirement_allows_technique_when_condition_not_met() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var target_hp_before: int = target.current_hp

	# User is at full HP (100%), condition "userHpBelow:50" is false
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_require_hp", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		target.current_hp, target_hp_before,
		"Requirement should allow technique when user HP >= 50%%",
	)


# --- Conditional: bonusPower ---


func test_conditional_bonus_power_when_condition_met() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var tech: TechniqueData = Atlas.techniques[&"test_conditional_power"]

	# Reset RNG for deterministic comparison — same seed for both calls
	# ensures identical crit/variance rolls, isolating the power difference
	_battle.rng.seed = 99999

	# Target at full HP → condition met → +40 power (effective 100)
	var results_cond: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)
	var dmg_conditional: int = 0
	for r: Dictionary in results_cond:
		dmg_conditional += int(r.get("damage", 0))

	# Set target not at full HP → condition fails → base power (60)
	target.current_hp = target.max_hp - 1

	# Reset RNG to same seed so crit/variance rolls are identical
	_battle.rng.seed = 99999

	var results_normal: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)
	var dmg_normal: int = 0
	for r: Dictionary in results_normal:
		dmg_normal += int(r.get("damage", 0))

	assert_gt(
		dmg_conditional, dmg_normal,
		"Conditional +40 power should deal more damage when target at full HP",
	)


# --- Conditional: damageMultiplier ---


func test_conditional_damage_multiplier() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	var tech: TechniqueData = Atlas.techniques[&"test_conditional_mult"]

	# Without poison — no multiplier
	var results_no_poison: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)
	var dmg_no_poison: int = 0
	for r: Dictionary in results_no_poison:
		dmg_no_poison += int(r.get("damage", 0))

	target.restore_hp(9999)
	target.add_status(&"poisoned")

	# With poison — 2x multiplier
	var results_poisoned: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)
	var dmg_poisoned: int = 0
	for r: Dictionary in results_poisoned:
		dmg_poisoned += int(r.get("damage", 0))

	assert_gt(
		dmg_poisoned, dmg_no_poison,
		"Conditional 2x multiplier should deal more damage vs poisoned target",
	)


# --- Conditional: nested applyBricks ---


func test_conditional_nested_bricks_execute_when_met() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_atk: int = user.stat_stages[&"attack"]

	# Bring target below 50% HP to trigger condition
	target.apply_damage(target.max_hp)
	target.restore_hp(target.max_hp / 4)  # 25% HP

	var tech: TechniqueData = Atlas.techniques[&"test_conditional_nested"]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)

	# Conditional should have executed nested statModifier: ATK +1
	assert_eq(
		user.stat_stages[&"attack"], initial_atk + 1,
		"Conditional nested brick should boost ATK +1 when target HP < 50%%",
	)


func test_conditional_nested_bricks_skip_when_not_met() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_atk: int = user.stat_stages[&"attack"]

	# Target at full HP → condition "targetHpBelow:50" is false
	var tech: TechniqueData = Atlas.techniques[&"test_conditional_nested"]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)

	assert_eq(
		user.stat_stages[&"attack"], initial_atk,
		"Conditional nested brick should NOT execute when condition not met",
	)


# --- PriorityOverride ---


func test_priority_override_changes_action_order() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Make target low HP to trigger priorityOverride
	target.apply_damage(target.max_hp)
	target.restore_hp(target.max_hp / 4)  # 25% HP

	# Side 0 (faster) uses priority override technique
	# Side 1 uses quick_strike (HIGH priority)
	# Without override, quick_strike goes first (HIGH > NORMAL)
	# With override (target HP < 50%), technique becomes HIGH priority too
	var action_override: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_priority_override", 1, 0,
	)
	var action_quick: BattleAction = TestBattleFactory.make_technique_action(
		1, 0, &"test_quick_strike", 0, 0,
	)

	# Just test the sort order
	var actions: Array[BattleAction] = [action_override, action_quick]
	ActionSorter.sort_actions(actions, _battle)

	# Both should be HIGH priority now, so speed decides
	assert_eq(
		int(action_override.priority), int(Registry.Priority.HIGH),
		"PriorityOverride should change technique to HIGH priority",
	)


func test_priority_override_no_change_when_condition_not_met() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Target at full HP → condition "targetHpBelow:50" is false
	var action: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_priority_override", 1, 0,
	)

	ActionSorter.calculate_action_speed(action, _battle)

	assert_eq(
		int(action.priority), int(Registry.Priority.NORMAL),
		"PriorityOverride should NOT change priority when condition not met",
	)


# --- Pre-scan helpers ---


func test_check_requirements_returns_failed() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var technique: TechniqueData = Atlas.techniques[&"test_require_hp"]

	# User at full HP → condition "userHpBelow:50" is false → should pass
	var result_pass: Dictionary = BrickExecutor.check_requirements(
		user, null, technique, _battle,
	)
	assert_false(
		result_pass.get("failed", false),
		"Requirement should pass when condition is not met",
	)

	# Reduce HP below 50%
	user.apply_damage(user.max_hp)
	user.restore_hp(user.max_hp / 4)

	var result_fail: Dictionary = BrickExecutor.check_requirements(
		user, null, technique, _battle,
	)
	assert_true(
		result_fail.get("failed", false),
		"Requirement should fail when condition is met",
	)
	assert_eq(
		result_fail.get("fail_message", ""),
		"Not enough HP to use this technique!",
		"Requirement should return the correct fail message",
	)


func test_evaluate_conditional_bonuses() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Target at full HP → condition "targetAtFullHp" is true
	var technique: TechniqueData = Atlas.techniques[
		&"test_conditional_power"
	]
	var bonuses: Dictionary = BrickExecutor.evaluate_conditional_bonuses(
		user, target, technique, _battle,
	)

	# This method only extracts accuracy bonuses and alwaysHits
	# bonusPower is handled at execute time, not pre-scan
	assert_false(
		bonuses.get("always_hits", false),
		"test_conditional_power has no alwaysHits",
	)


func test_evaluate_priority_override() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Target at full HP → condition "targetHpBelow:50" is false
	var technique: TechniqueData = Atlas.techniques[
		&"test_priority_override"
	]
	var result_no: int = BrickExecutor.evaluate_priority_override(
		user, target, technique, _battle,
	)
	assert_eq(result_no, -1, "No override when condition not met")

	# Bring target below 50%
	target.apply_damage(target.max_hp)
	target.restore_hp(target.max_hp / 4)

	var result_yes: int = BrickExecutor.evaluate_priority_override(
		user, target, technique, _battle,
	)
	assert_eq(
		result_yes, int(Registry.Priority.HIGH),
		"Override should map newPriority=1 to HIGH",
	)
