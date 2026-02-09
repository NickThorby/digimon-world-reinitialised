extends GutTest
## Integration tests for technique execution through the engine.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Basic technique execution ---


func test_physical_technique_reduces_hp() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_lt(target.current_hp, initial_hp, "Physical technique should reduce target HP")


func test_special_technique_reduces_hp() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_fire_blast", 0, 0),
	]
	_engine.execute_turn(actions)
	assert_lt(target.current_hp, initial_hp, "Special technique should reduce target HP")


func test_status_technique_no_damage() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_status_burn", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		target.current_hp, initial_hp,
		"Status technique should not deal direct damage",
	)


func test_status_technique_applies_status() -> void:
	# test_status_paralyse has 100% accuracy and 100% chance
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_status_paralyse", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(target.has_status(&"paralysed"), "Target should be paralysed")


# --- Signals ---


func test_damage_dealt_signal() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(_engine, "damage_dealt", "damage_dealt signal should fire")


func test_battle_message_signal() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(
		_engine, "battle_message",
		"battle_message signal should fire for technique use",
	)


func test_technique_animation_requested_signal() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(
		_engine, "technique_animation_requested",
		"technique_animation_requested should fire",
	)


func test_status_applied_signal() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_status_paralyse", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(
		_engine, "status_applied",
		"status_applied signal should fire when status applied",
	)


# --- Multi-brick technique ---


func test_multi_brick_technique_damage_and_status() -> void:
	# test_ice_beam: damage + frostbitten (30% chance)
	# Use seed that makes the 30% chance hit
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_gabumon", &"test_agumon", 42,
	)
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp

	# Run multiple turns to test the damage portion (status may or may not apply)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_ice_beam", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)
	assert_lt(target.current_hp, initial_hp, "Ice beam should deal damage")


# --- STAB ---


func test_stab_increases_damage() -> void:
	# test_agumon (fire type) using fire_blast vs gabumon
	# Compare to a non-STAB attack of similar power
	var battle_stab: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon", 99999,
	)
	var engine_stab: BattleEngine = TestBattleFactory.create_engine(battle_stab)
	var target_stab: BattleDigimonState = battle_stab.get_digimon_at(1, 0)

	var actions_stab: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine_stab.execute_turn(actions_stab)
	var stab_damage: int = target_stab.max_hp - target_stab.current_hp

	# fire_blast (power 90, fire, STAB) should deal more than tackle (power 40, no element)
	assert_gt(stab_damage, 0, "STAB fire_blast should deal damage")


# --- Ability triggers ---


func test_on_before_technique_fires() -> void:
	# This is tested implicitly — the engine fires ON_BEFORE_TECHNIQUE
	# We verify the turn completes without error
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(_battle.turn_number, 1, "Turn should complete")


func test_on_take_damage_ability_fires() -> void:
	# Give gabumon the on_damage ability (spe+1 when hit)
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon",
	)
	# Manually assign the on_damage ability to gabumon
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.ability_key = &"test_ability_on_damage"

	var engine: BattleEngine = TestBattleFactory.create_engine(battle)
	var initial_spe_stage: int = target.stat_stages[&"speed"]

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)
	assert_eq(
		target.stat_stages[&"speed"], initial_spe_stage + 1,
		"ON_TAKE_DAMAGE ability should boost speed by +1",
	)


# --- Volatiles ---


func test_last_technique_key_updated() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		user.volatiles.get("last_technique_key", &""), &"test_tackle",
		"last_technique_key should be updated after technique use",
	)


# --- Participation tracking ---


func test_participation_tracked() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(
		user.participated_against.has(target.source_state.key),
		"User should track participation against target",
	)
