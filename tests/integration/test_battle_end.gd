extends GutTest
## Integration tests for battle end conditions.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- WIN ---


func test_win_when_all_foes_faint() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.current_hp = 1

	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_true(_battle.is_battle_over, "Battle should be over")
	assert_not_null(_battle.result, "Result should be set")
	assert_eq(
		_battle.result.outcome, BattleResult.Outcome.WIN,
		"Outcome should be WIN",
	)
	assert_signal_emitted(_engine, "battle_ended", "battle_ended should fire")


# --- LOSS ---


func test_loss_when_all_player_faint() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_hp = 1

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	assert_true(_battle.is_battle_over, "Battle should be over")
	assert_eq(
		_battle.result.outcome, BattleResult.Outcome.LOSS,
		"Outcome should be LOSS",
	)


# --- FLED ---


func test_fled_via_run_action() -> void:
	var battle: BattleState = TestBattleFactory.create_wild_battle()
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	watch_signals(engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_run_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)

	assert_true(battle.is_battle_over, "Battle should be over after fleeing")
	assert_eq(
		battle.result.outcome, BattleResult.Outcome.FLED,
		"Outcome should be FLED",
	)
	assert_signal_emitted(engine, "battle_ended", "battle_ended should fire on flee")


func test_cannot_flee_from_trainer_battle() -> void:
	# Default create_1v1_battle is not wild
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_run_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_false(
		_battle.is_battle_over,
		"Should not be able to flee from trainer battle",
	)


# --- battle_ended signal ---


func test_battle_ended_signal_with_correct_result() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.current_hp = 1

	# Use an Array container so the lambda captures by reference, not by value.
	var capture: Array = [null]
	_engine.battle_ended.connect(func(result: BattleResult) -> void:
		capture[0] = result
	)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var received_result: BattleResult = capture[0] as BattleResult
	assert_not_null(received_result, "Should receive BattleResult in signal")
	assert_eq(
		received_result.outcome, BattleResult.Outcome.WIN,
		"Signal result should have WIN outcome",
	)


# --- Battle not over with reserves ---


func test_battle_not_over_with_reserves() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves()
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.current_hp = 1

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)

	# Foe should faint but battle should not be over (reserve exists)
	assert_true(target.is_fainted, "Target should be fainted")
	assert_false(
		battle.is_battle_over,
		"Battle should not be over when foe has reserves",
	)


# --- No actions after battle over ---


func test_no_actions_processed_after_battle_over() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.current_hp = 1

	# First turn: kill the foe
	var actions_1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_1)
	assert_true(_battle.is_battle_over, "Battle should be over")

	# Second turn: try to execute more actions
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var _initial_hp: int = user.current_hp
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
	]
	_engine.execute_turn(actions_2)

	assert_eq(
		_battle.turn_number, 1,
		"Turn should not increment after battle is over",
	)
