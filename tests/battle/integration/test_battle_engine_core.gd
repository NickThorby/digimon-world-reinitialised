extends GutTest
## Integration tests for BattleEngine core turn loop.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- initialise() ---


func test_initialise_sets_battle() -> void:
	assert_not_null(_engine._battle, "Engine should have a battle state")
	assert_not_null(_engine._balance, "Engine should load game balance")


# --- start_battle() ---


func test_start_battle_fires_on_entry_abilities() -> void:
	# test_agumon has test_ability_on_entry (ON_ENTRY, atk+1)
	_engine.start_battle()
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		user.stat_stages[&"attack"], 1,
		"ON_ENTRY ability should boost attack by +1",
	)


# --- execute_turn() ---


func test_execute_turn_increments_turn_number() -> void:
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(_battle.turn_number, 1, "Turn number should be 1 after first turn")


func test_execute_turn_emits_turn_started() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(_engine, "turn_started", "turn_started signal should fire")


func test_execute_turn_emits_turn_ended() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(_engine, "turn_ended", "turn_ended signal should fire")


func test_execute_turn_emits_action_resolved() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emit_count(
		_engine, "action_resolved", 2,
		"action_resolved should fire once per action",
	)


func test_skips_cancelled_actions() -> void:
	var action: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_tackle", 1, 0,
	)
	action.is_cancelled = true
	var actions: Array[BattleAction] = [
		action,
		TestBattleFactory.make_rest_action(1, 0),
	]
	watch_signals(_engine)
	_engine.execute_turn(actions)
	# Only 1 action_resolved (the rest), the cancelled one is skipped
	assert_signal_emit_count(
		_engine, "action_resolved", 1,
		"Cancelled actions should not emit action_resolved",
	)


func test_skips_fainted_actors() -> void:
	# Faint side 0's Digimon before the turn
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(user.current_hp)
	user.is_fainted = true

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	watch_signals(_engine)
	_engine.execute_turn(actions)
	# The fainted actor's action should be skipped
	assert_signal_emit_count(
		_engine, "action_resolved", 1,
		"Fainted actor's action should be skipped",
	)


func test_retargets_if_original_target_fainted() -> void:
	# Create a 2v2 where one foe is fainted
	var battle: BattleState = TestBattleFactory.create_2v2_battle()
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	# Faint the target at (1, 0)
	var fainted_target: BattleDigimonState = battle.get_digimon_at(1, 0)
	fainted_target.apply_damage(fainted_target.current_hp)
	fainted_target.is_fainted = true

	# Target the fainted slot
	var action: BattleAction = TestBattleFactory.make_technique_action(
		0, 0, &"test_tackle", 1, 0,
	)
	var remaining_foe: BattleDigimonState = battle.get_digimon_at(1, 1)
	var initial_hp: int = remaining_foe.current_hp

	var actions: Array[BattleAction] = [
		action,
		TestBattleFactory.make_rest_action(0, 1),
		TestBattleFactory.make_rest_action(1, 1),
	]
	engine.execute_turn(actions)

	# The attack should have been retargeted to the remaining foe
	assert_lt(
		remaining_foe.current_hp, initial_hp,
		"Attack should retarget to remaining foe",
	)


func test_does_not_execute_after_battle_over() -> void:
	_battle.is_battle_over = true
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(_battle.turn_number, 0, "Turn should not increment when battle is over")
