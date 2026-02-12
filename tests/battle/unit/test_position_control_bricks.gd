extends GutTest
## Unit tests for position control bricks: forceSwitch, switchOut, and
## switchOutPassStats (baton pass). Tests cover forced switching with and without
## reserves, voluntary switch-out after damage, and stat stage transfer on switch.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- forceSwitch ---


func test_force_switch_replaces_target_with_reserve() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_tank"],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var original_target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var original_key: StringName = original_target.data.key

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_force_switch", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	assert_ne(
		new_target.data.key, original_key,
		"Target should have been switched to a reserve",
	)


func test_force_switch_no_reserves_fails_gracefully() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var original_target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var original_key: StringName = original_target.data.key

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_force_switch", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var still_same: BattleDigimonState = _battle.get_digimon_at(1, 0)
	assert_eq(
		still_same.data.key, original_key,
		"Target should remain when no reserves exist",
	)


# --- switchOut ---


func test_switch_out_user_switches_after_damage() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_tank"],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var original_user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var original_key: StringName = original_user.data.key
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var target_hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_switch_out_attack", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Target should have taken damage
	assert_lt(
		target.current_hp, target_hp_before,
		"Target should have taken damage",
	)
	# User should have been switched out
	var new_user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_ne(
		new_user.data.key, original_key,
		"User should have switched out to reserve",
	)


# --- switchOutPassStats (Baton Pass) ---


func test_baton_pass_transfers_stat_stages() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_tank"],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Boost user's ATK by +2
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.modify_stat_stage(&"attack", 2)
	assert_eq(user.stat_stages[&"attack"], 2)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_baton_pass", 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Replacement should inherit the +2 ATK
	var replacement: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		replacement.stat_stages[&"attack"], 2,
		"Replacement should inherit +2 ATK from baton pass",
	)
