extends GutTest
## Integration tests for protection in full engine context:
## consecutive fail escalation over multiple turns, and protection
## interaction with multi-hit techniques.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Consecutive protection failure escalation ---


func test_consecutive_protection_first_use_always_succeeds() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Use protection on first turn — should always succeed
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"First protection use should always succeed and block damage",
	)


func test_consecutive_protection_streak_tracked() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Turn 1: use protection
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	# After using protection, consecutive count should be tracked
	var streak: int = int(
		target.volatiles.get("consecutive_protection_uses", 0),
	)
	assert_gt(
		streak, 0,
		"Consecutive protection uses should be tracked after first use",
	)


func test_not_using_protection_resets_streak() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Turn 1: use protection
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	# Turn 2: don't use protection
	actions = [
		TestBattleFactory.make_rest_action(1, 0),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	# Turn 3: streak resets at start of this turn (checks turn 2 had
	# no protection use)
	actions = [
		TestBattleFactory.make_rest_action(1, 0),
		TestBattleFactory.make_rest_action(0, 0),
	]
	_engine.execute_turn(actions)

	var streak: int = int(
		target.volatiles.get("consecutive_protection_uses", 0),
	)
	assert_eq(
		streak, 0,
		"Consecutive protection uses should reset when not used",
	)


# --- Protection with multi-hit ---


func test_protection_blocks_all_hits_of_multi_hit() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Target protects, attacker uses multi-hit
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_multi_hit_3", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Protection should block all hits of a multi-hit technique",
	)


# --- Wide protection with multi-target ---


func test_wide_guard_blocks_multi_target_technique() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_wide_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_earthquake", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Wide Guard should block multi-target techniques",
	)


func test_wide_guard_does_not_block_single_target() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_wide_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_lt(
		target.current_hp, hp_before,
		"Wide Guard should NOT block single-target techniques",
	)


# --- Priority guard ---


func test_priority_guard_blocks_priority_technique() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_priority_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_quick_strike", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Priority Guard should block priority techniques",
	)


func test_priority_guard_does_not_block_normal_priority() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_priority_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_lt(
		target.current_hp, hp_before,
		"Priority Guard should NOT block normal priority techniques",
	)
