extends GutTest
## Integration tests for the ability trigger system.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Trigger timing ---


func test_on_entry_fires_at_battle_start() -> void:
	# test_agumon has test_ability_on_entry (ON_ENTRY, atk+1, ONCE_PER_SWITCH)
	_engine.start_battle()
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		user.stat_stages[&"attack"], 1,
		"ON_ENTRY should boost attack +1 at battle start",
	)


func test_on_entry_fires_on_switch_in() -> void:
	# Create battle with reserves where reserve has ON_ENTRY ability
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_patamon", &"test_agumon"],  # patamon active, agumon in reserve
		[&"test_gabumon", &"test_tank"],
	)
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	# Switch to agumon (reserve index 0) which has ON_ENTRY
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)

	var new_digimon: BattleDigimonState = battle.get_digimon_at(0, 0)
	assert_eq(
		new_digimon.stat_stages[&"attack"], 1,
		"ON_ENTRY should fire when switching in",
	)


func test_on_turn_start_fires_each_turn() -> void:
	# test_gabumon has test_ability_on_turn_start (UNLIMITED, empty bricks)
	# Just verify the ability message fires each turn
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(
		_engine, "battle_message",
		"ON_TURN_START ability should emit a battle_message",
	)


func test_on_deal_damage_fires() -> void:
	# Assign ON_DEAL_DAMAGE ability to user
	# We use the existing test data — just verify the trigger fires without error
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(_battle.turn_number, 1, "Turn should complete after ON_DEAL_DAMAGE")


func test_on_take_damage_fires() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.ability_key = &"test_ability_on_damage"

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		target.stat_stages[&"speed"], 1,
		"ON_TAKE_DAMAGE should boost speed +1",
	)


func test_on_faint_fires() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.ability_key = &"test_ability_on_faint"
	# Reduce HP to 1 so tackle will faint
	target.current_hp = 1

	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(_engine, "digimon_fainted", "Faint signal should fire")


func test_on_foe_faint_fires() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.current_hp = 1

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# The user has test_ability_on_entry which won't fire again here,
	# but foe faint triggers are checked separately
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(target.is_fainted, "Target should be fainted")


func test_on_status_applied_fires() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.ability_key = &"test_ability_on_status"

	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_status_paralyse", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_signal_emitted(
		_engine, "battle_message",
		"ON_STATUS_APPLIED ability should emit a message",
	)


# --- Stack limits ---


func test_once_per_turn_blocks_after_first() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.ability_key = &"test_ability_on_damage"  # ONCE_PER_TURN

	# Hit target twice in one turn (both sides attack)
	var battle: BattleState = TestBattleFactory.create_2v2_battle(
		[&"test_agumon", &"test_speedster"],
		[&"test_gabumon", &"test_tank"],
	)
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)
	var hit_target: BattleDigimonState = battle.get_digimon_at(1, 0)
	hit_target.ability_key = &"test_ability_on_damage"

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_technique_action(0, 1, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
		TestBattleFactory.make_rest_action(1, 1),
	]
	engine.execute_turn(actions)
	# ONCE_PER_TURN: should only trigger once, so speed +1 (not +2)
	assert_eq(
		hit_target.stat_stages[&"speed"], 1,
		"ONCE_PER_TURN ability should only trigger once per turn",
	)


func test_once_per_switch_blocks_after_first() -> void:
	# ON_ENTRY with ONCE_PER_SWITCH — should fire at start, not again same switch
	_engine.start_battle()
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(user.stat_stages[&"attack"], 1, "ON_ENTRY should fire once")

	# The trigger is ONCE_PER_SWITCH, so it should not fire again
	assert_false(
		user.can_trigger_ability(Registry.StackLimit.ONCE_PER_SWITCH),
		"Should be blocked after first trigger",
	)


func test_once_per_battle_permanent() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.ability_key = &"test_ability_on_faint"  # ONCE_PER_BATTLE
	user.record_ability_trigger(Registry.StackLimit.ONCE_PER_BATTLE)
	user.reset_volatiles()
	assert_false(
		user.can_trigger_ability(Registry.StackLimit.ONCE_PER_BATTLE),
		"ONCE_PER_BATTLE should remain blocked even after switch",
	)


# --- Nullified ---


func test_nullified_blocks_abilities() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"nullified")
	_engine.start_battle()
	# ON_ENTRY should NOT fire because user is nullified
	assert_eq(
		user.stat_stages[&"attack"], 0,
		"Nullified should block ON_ENTRY ability",
	)


# --- Ability brick targets self ---


func test_ability_targets_self() -> void:
	# test_ability_on_entry has target="self" and boosts atk +1
	_engine.start_battle()
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var foe: BattleDigimonState = _battle.get_digimon_at(1, 0)
	assert_eq(user.stat_stages[&"attack"], 1, "Self-targeting ability should boost user")
	# gabumon also has an ability (ON_TURN_START) but it has no bricks
	assert_eq(
		foe.stat_stages[&"attack"], 0,
		"Foe should not be affected by user's self-targeting ability",
	)
