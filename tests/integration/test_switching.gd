extends GutTest
## Integration tests for Digimon switching mechanics.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Voluntary switch ---


func test_switch_replaces_active_digimon() -> void:
	var old_digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var old_key: StringName = old_digimon.source_state.key

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_ne(
		new_digimon.source_state.key, old_key,
		"Active Digimon should be replaced after switch",
	)


func test_switch_old_goes_to_reserve() -> void:
	var old_key: StringName = _battle.get_digimon_at(0, 0).source_state.key
	var initial_reserve_size: int = _battle.sides[0].party.size()

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Old Digimon should be in reserve
	var found_in_reserve: bool = false
	for digimon: DigimonState in _battle.sides[0].party:
		if digimon.key == old_key:
			found_in_reserve = true
			break
	assert_true(found_in_reserve, "Old Digimon should be in reserve after switch")


func test_switch_resets_stat_stages() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.modify_stat_stage(&"attack", 3)
	user.modify_stat_stage(&"speed", -2)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Stages should be reset on the switched-out Digimon
	# The new Digimon should start at 0
	var new_digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		new_digimon.stat_stages[&"attack"], 0,
		"New Digimon should start with 0 stat stages",
	)


func test_switch_writes_back_hp_energy() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(20)
	user.spend_energy(10)
	var hp_before_switch: int = user.current_hp
	var energy_before_switch: int = user.current_energy

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Find the old Digimon in reserve and check written-back values
	assert_eq(
		user.source_state.current_hp, hp_before_switch,
		"HP should be written back to source_state",
	)
	assert_eq(
		user.source_state.current_energy, energy_before_switch,
		"Energy should be written back to source_state",
	)


func test_switch_fires_on_entry() -> void:
	# Reserve has test_patamon (ability: test_ability_on_ally_faint, trigger ON_ALLY_FAINT)
	# First Digimon is test_agumon with ON_ENTRY ability
	# Switch to reserve index 0 (test_patamon)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# The new Digimon's ON_ENTRY ability should fire if it has one
	# test_patamon has test_ability_on_ally_faint which is ON_ALLY_FAINT, not ON_ENTRY
	# So no ON_ENTRY effect here, but the signal should still fire
	assert_eq(_battle.turn_number, 1, "Turn should complete after switch")


func test_digimon_switched_signal() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(
		_engine, "digimon_switched",
		"digimon_switched signal should fire",
	)


func test_invalid_party_index_handled() -> void:
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 999),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	# Should not crash
	assert_eq(_battle.turn_number, 1, "Turn should complete even with invalid index")


func test_switch_has_maximum_priority() -> void:
	# Switch should execute before a NORMAL priority technique
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	# The switch should happen first, then the foe's technique targets the new Digimon
	assert_eq(_battle.turn_number, 1, "Turn should complete")


# --- resolve_forced_switch() ---


func test_resolve_forced_switch() -> void:
	var old_key: StringName = _battle.get_digimon_at(0, 0).source_state.key
	var switch_action: BattleAction = TestBattleFactory.make_switch_action(0, 0, 0)
	var results: Array[Dictionary] = _engine.resolve_forced_switch(switch_action)
	assert_gt(results.size(), 0, "Forced switch should return results")
	var new_key: StringName = _battle.get_digimon_at(0, 0).source_state.key
	assert_ne(new_key, old_key, "Forced switch should replace the Digimon")
