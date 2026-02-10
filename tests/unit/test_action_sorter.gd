extends GutTest
## Unit tests for ActionSorter priority and speed ordering.

var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()


# --- Priority ordering ---


func test_switch_before_technique() -> void:
	var switch_action: BattleAction = TestBattleFactory.make_switch_action(0, 0, 0)
	var tech_action: BattleAction = TestBattleFactory.make_technique_action(
		1, 0, &"test_tackle", 0, 0,
	)
	var actions: Array[BattleAction] = [tech_action, switch_action]
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)
	assert_eq(
		sorted[0].action_type, BattleAction.ActionType.SWITCH,
		"Switch (MAXIMUM priority) should go before technique",
	)


func test_rest_uses_normal_priority() -> void:
	# test_agumon (spe=80) uses a technique, test_gabumon (spe=60) rests.
	# Both at NORMAL priority, so faster Digimon (agumon) should go first.
	var tech_action: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_tackle", 1, 0,
	)
	var rest_action: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	var actions: Array[BattleAction] = [rest_action, tech_action]
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)
	assert_eq(
		sorted[0].action_type, BattleAction.ActionType.TECHNIQUE,
		"Faster Digimon's technique (NORMAL) should go before slower rest (NORMAL)",
	)
	assert_eq(
		sorted[0].user_side, 0,
		"Faster Digimon (side 0, spe=80) should act before slower rester (side 1, spe=60)",
	)


func test_high_priority_before_normal() -> void:
	# test_quick_strike has HIGH priority, test_tackle has NORMAL
	var high_action: BattleAction = TestBattleFactory.make_technique_action(
		1, 0, &"test_quick_strike", 0, 0,
	)
	var normal_action: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_tackle", 1, 0,
	)
	var actions: Array[BattleAction] = [normal_action, high_action]
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)
	assert_eq(
		sorted[0].technique_key, &"test_quick_strike",
		"HIGH priority technique should go before NORMAL",
	)


# --- Speed tiebreak ---


func test_faster_digimon_goes_first_at_same_priority() -> void:
	# test_agumon (spe=80) vs test_gabumon (spe=60), both NORMAL priority
	var fast_action: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_tackle", 1, 0,
	)
	var slow_action: BattleAction = TestBattleFactory.make_technique_action(
		1, 0, &"test_tackle", 0, 0,
	)
	var actions: Array[BattleAction] = [slow_action, fast_action]
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)
	assert_eq(sorted[0].user_side, 0, "Faster Digimon (side 0, spe=80) should go first")


func test_speed_tie_uses_random_tiebreaker() -> void:
	# Create a battle with two identical Digimon (same speed)
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon", 12345,
	)
	var action_a: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_tackle", 1, 0,
	)
	var action_b: BattleAction = TestBattleFactory.make_technique_action(
		1, 0, &"test_tackle", 0, 0,
	)
	var actions: Array[BattleAction] = [action_a, action_b]
	ActionSorter.sort_actions(actions, battle)
	# Both have tiebreakers set — just check they were assigned
	assert_true(
		actions[0].speed_tiebreaker > 0.0 or actions[1].speed_tiebreaker > 0.0,
		"Tiebreakers should be assigned for speed ties",
	)


# --- Run action priority ---


func test_run_has_maximum_priority() -> void:
	var run_action: BattleAction = TestBattleFactory.make_run_action(0, 0)
	var tech_action: BattleAction = TestBattleFactory.make_technique_action(
		1, 0, &"test_quick_strike", 0, 0,
	)
	var actions: Array[BattleAction] = [tech_action, run_action]
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)
	assert_eq(
		sorted[0].action_type, BattleAction.ActionType.RUN,
		"Run (MAXIMUM priority) should go before any technique",
	)
