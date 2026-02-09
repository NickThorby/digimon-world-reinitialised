extends GutTest
## Integration tests for the energy system (spend, regen, rest, overexertion).

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Technique spends energy ---


func test_technique_spends_energy() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var initial_energy: int = user.current_energy
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	# test_tackle costs 5. End-of-turn regen adds back 5% of max_energy.
	# So net = initial - 5 + regen
	var regen: int = maxi(floori(float(user.max_energy) * 0.05), 1)
	var expected: int = initial_energy - 5 + regen
	assert_eq(user.current_energy, expected, "Energy should reflect spend + end-of-turn regen")


func test_energy_spent_signal() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(_engine, "energy_spent", "energy_spent signal should fire")


# --- End-of-turn regen ---


func test_end_of_turn_energy_regen() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# Drain some energy first
	user.spend_energy(user.current_energy)
	assert_eq(user.current_energy, 0, "Energy should be 0 after draining")

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	# Rest restores 25% + end-of-turn regen 5%
	var rest_regen: int = maxi(floori(float(user.max_energy) * 0.25), 1)
	var turn_regen: int = maxi(floori(float(user.max_energy) * 0.05), 1)
	assert_eq(
		user.current_energy, mini(rest_regen + turn_regen, user.max_energy),
		"Energy should be rest regen + turn regen (clamped to max)",
	)


func test_energy_restored_signal() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(
		_engine, "energy_restored",
		"energy_restored should fire on rest and end-of-turn regen",
	)


# --- Rest ---


func test_rest_restores_energy() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.spend_energy(user.current_energy)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_gt(user.current_energy, 0, "Rest should restore some energy")


func test_rest_removes_bleeding() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"bleeding")
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_false(user.has_status(&"bleeding"), "Rest should remove bleeding")


# --- Overexertion ---


func test_overexertion_deals_self_damage() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# Drain all energy
	user.spend_energy(user.current_energy)
	var initial_hp: int = user.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		user.current_hp, initial_hp,
		"Overexertion should deal self-damage when energy is insufficient",
	)


func test_overexertion_can_cause_faint() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# Drain all energy and reduce HP to 1
	user.spend_energy(user.current_energy)
	user.current_hp = 1

	# test_expensive costs 999 energy, causing massive overexertion
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_expensive", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	watch_signals(_engine)
	_engine.execute_turn(actions)

	assert_true(user.is_fainted, "Overexertion should be able to cause faint")
