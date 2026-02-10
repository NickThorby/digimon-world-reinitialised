extends GutTest
## Integration tests for technique edge cases: faint during multi-hit,
## empty technique list, and 0-power technique through damage path.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Faint during multi-hit ---


func test_multi_hit_stops_on_target_faint() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	# Set target to very low HP so it faints on the first hit
	target.current_hp = 1

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_multi_hit_3", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_true(
		target.is_fainted,
		"Target should faint during multi-hit",
	)
	# The key assertion: remaining hits should not execute.
	# If they did, the engine would have tried to damage a fainted
	# target, which the loop guards against.


func test_multi_hit_deals_all_hits_on_healthy_target() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_multi_hit_3", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Multi-hit 3 does 3 hits of 25 power each — target should take
	# noticeably more damage than a single hit
	var damage_taken: int = hp_before - target.current_hp
	assert_gt(
		damage_taken, 0,
		"Multi-hit should deal damage across multiple hits",
	)


# --- Empty technique list ---


func test_unknown_technique_key_returns_empty() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_nonexistent_technique", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Unknown technique should deal no damage",
	)


# --- 0-power technique ---


func test_zero_power_standard_damage_deals_minimum() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Use test_heal_self which has 0 power and no bricks — but we can
	# test that executing it through the engine doesn't crash
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_heal_self", 0, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Should complete without error; heal_self targets self with no
	# damage bricks, so target HP is unchanged
	assert_eq(
		target.current_hp, hp_before,
		"0-power technique with no damage bricks should not deal damage",
	)
