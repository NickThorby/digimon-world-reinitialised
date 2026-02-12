extends GutTest
## Integration tests for side effects (barriers, immunities) through the engine.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Physical barrier ---


func test_physical_barrier_halves_physical_damage() -> void:
	# Baseline: damage without barrier
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions_1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_1)
	var no_barrier_damage: int = hp_before - target.current_hp

	# With barrier
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.sides[1].add_side_effect(&"physical_barrier", 5)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)
	var barrier_damage: int = hp_before - target.current_hp

	assert_lt(
		barrier_damage, no_barrier_damage,
		"Physical barrier should reduce physical damage (got %d vs %d)" % [
			barrier_damage, no_barrier_damage,
		],
	)


# --- Special barrier ---


func test_special_barrier_halves_special_damage() -> void:
	# Baseline: without barrier
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions_1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_1)
	var no_barrier_damage: int = hp_before - target.current_hp

	# With barrier
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.sides[1].add_side_effect(&"special_barrier", 5)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)
	var barrier_damage: int = hp_before - target.current_hp

	assert_lt(
		barrier_damage, no_barrier_damage,
		"Special barrier should reduce special damage",
	)


# --- Dual barrier ---


func test_dual_barrier_reduces_both() -> void:
	# Baseline: without barrier
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions_1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_1)
	var no_barrier_damage: int = hp_before - target.current_hp

	# With dual barrier
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.sides[1].add_side_effect(&"dual_barrier", 5)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)
	var dual_barrier_damage: int = hp_before - target.current_hp

	assert_lt(
		dual_barrier_damage, no_barrier_damage,
		"Dual barrier should reduce damage",
	)


# --- Stat drop immunity ---


func test_stat_drop_immunity_blocks_debuffs() -> void:
	_battle.sides[1].add_side_effect(&"stat_drop_immunity", 5)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var speed_before: int = target.stat_stages.get(&"speed", 0)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_debuff_speed", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.stat_stages.get(&"speed", 0), speed_before,
		"Speed should not drop with stat_drop_immunity active",
	)


func test_stat_drop_immunity_allows_boosts() -> void:
	# Self-targeting boost should still work even if the side has immunity
	_battle.sides[0].add_side_effect(&"stat_drop_immunity", 5)
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var atk_before: int = user.stat_stages.get(&"attack", 0)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_boost_attack", 0, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_gt(
		user.stat_stages.get(&"attack", 0), atk_before,
		"Stat boosts should still work with stat_drop_immunity",
	)


# --- Status immunity ---


func test_status_immunity_blocks_status() -> void:
	_battle.sides[1].add_side_effect(&"status_immunity", 5)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_status_burn", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_false(
		target.has_status(&"burned"),
		"Status should be blocked by status_immunity",
	)


# --- Side effect expiry ---


func test_side_effect_expires_after_duration() -> void:
	_battle.sides[0].add_side_effect(&"physical_barrier", 2)
	var rest_actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	# Turn 1: duration 2 -> 1
	_engine.execute_turn(rest_actions)
	assert_true(
		_battle.sides[0].has_side_effect(&"physical_barrier"),
		"Barrier should persist after 1 turn",
	)
	# Turn 2: duration 1 -> 0, expires
	_engine.execute_turn(rest_actions)
	assert_false(
		_battle.sides[0].has_side_effect(&"physical_barrier"),
		"Barrier should expire after 2 turns",
	)


# --- Setting via technique ---


func test_physical_barrier_technique_sets_effect() -> void:
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_physical_barrier", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(
		_battle.sides[0].has_side_effect(&"physical_barrier"),
		"Physical barrier technique should set the side effect",
	)
