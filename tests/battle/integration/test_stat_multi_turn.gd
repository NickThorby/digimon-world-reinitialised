extends GutTest
## Integration tests for stat stage accumulation over multiple turns
## and stat stage cap enforcement.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Accumulation over multiple turns ---


func test_stat_stages_accumulate_over_3_turns() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# test_boost_attack gives +2 ATK per use

	# Turn 1: +2
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_boost_attack", 0, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		int(user.stat_stages.get(&"attack", 0)), 2,
		"After turn 1: ATK should be at +2",
	)

	# Turn 2: +4
	actions = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_boost_attack", 0, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		int(user.stat_stages.get(&"attack", 0)), 4,
		"After turn 2: ATK should be at +4",
	)

	# Turn 3: +6 (capped)
	actions = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_boost_attack", 0, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		int(user.stat_stages.get(&"attack", 0)), 6,
		"After turn 3: ATK should be capped at +6",
	)


func test_stat_stage_caps_at_positive_6() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	# Use boost 4 times (+2 each = +8 requested, capped to +6)
	for _i: int in range(4):
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_technique_action(
				0, 0, &"test_boost_attack", 0, 0,
			),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

	assert_eq(
		int(user.stat_stages.get(&"attack", 0)), 6,
		"ATK stage should cap at +6 even after 4 uses of +2",
	)


func test_stat_stage_caps_at_negative_6() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Use debuff_speed 7 times (-1 each = -7 requested, capped to -6)
	for _i: int in range(7):
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_technique_action(
				0, 0, &"test_debuff_speed", 1, 0,
			),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

	assert_eq(
		int(target.stat_stages.get(&"speed", 0)), -6,
		"Speed stage should cap at -6 even after 7 uses of -1",
	)


func test_positive_and_negative_stages_cancel_out() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	# Boost ATK +2
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_boost_attack", 0, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		int(user.stat_stages.get(&"attack", 0)), 2,
		"ATK should be at +2 after one boost",
	)

	# Foe debuffs our ATK with a stat modifier (we simulate by directly
	# calling modify_stat_stage since no test technique debuffs ATK on foe)
	user.modify_stat_stage(&"attack", -3)
	assert_eq(
		int(user.stat_stages.get(&"attack", 0)), -1,
		"ATK should be at -1 after +2 then -3",
	)
