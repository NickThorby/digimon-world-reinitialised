extends GutTest
## Integration tests for doubles (2v2) battle format.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_2v2_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- 2v2 creation ---


func test_2v2_has_two_sides() -> void:
	assert_eq(_battle.sides.size(), 2, "Should have 2 sides")


func test_2v2_has_two_slots_per_side() -> void:
	assert_eq(_battle.sides[0].slots.size(), 2, "Side 0 should have 2 slots")
	assert_eq(_battle.sides[1].slots.size(), 2, "Side 1 should have 2 slots")


func test_2v2_all_slots_occupied() -> void:
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			assert_not_null(slot.digimon, "All slots should be occupied")


# --- ALL_FOES targeting ---


func test_all_foes_hits_both_opposing_slots() -> void:
	var foe_0: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var foe_1: BattleDigimonState = _battle.get_digimon_at(1, 1)
	var foe_0_initial: int = foe_0.current_hp
	var foe_1_initial: int = foe_1.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_earthquake", 1, 0),
		TestBattleFactory.make_rest_action(0, 1),
		TestBattleFactory.make_rest_action(1, 0),
		TestBattleFactory.make_rest_action(1, 1),
	]
	_engine.execute_turn(actions)

	assert_lt(foe_0.current_hp, foe_0_initial, "Foe slot 0 should take earthquake damage")
	assert_lt(foe_1.current_hp, foe_1_initial, "Foe slot 1 should take earthquake damage")


# --- SINGLE_FOE targeting ---


func test_single_foe_hits_only_chosen_target() -> void:
	var foe_0: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var foe_1: BattleDigimonState = _battle.get_digimon_at(1, 1)
	var foe_0_initial: int = foe_0.current_hp
	var foe_1_initial: int = foe_1.current_hp

	# Target slot 0 specifically
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(0, 1),
		TestBattleFactory.make_rest_action(1, 0),
		TestBattleFactory.make_rest_action(1, 1),
	]
	_engine.execute_turn(actions)

	assert_lt(foe_0.current_hp, foe_0_initial, "Targeted foe should take damage")
	assert_eq(foe_1.current_hp, foe_1_initial, "Non-targeted foe should not take damage")


# --- Speed ordering across 4 Digimon ---


func test_speed_ordering_four_digimon() -> void:
	# Side 0: test_agumon (spe=80), test_patamon (spe=50)
	# Side 1: test_gabumon (spe=60), test_tank (spe=30)
	# Expected speed order: agumon > gabumon > patamon > tank
	var order: Array[int] = []
	_engine.action_resolved.connect(func(action: BattleAction, _results: Array[Dictionary]) -> void:
		order.append(action.user_side * 10 + action.user_slot)
	)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),  # agumon spe=80
		TestBattleFactory.make_technique_action(0, 1, &"test_tackle", 1, 0),  # patamon spe=50
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),  # gabumon spe=60
		TestBattleFactory.make_technique_action(1, 1, &"test_tackle", 0, 0),  # tank spe=30
	]
	_engine.execute_turn(actions)

	assert_eq(order.size(), 4, "All 4 actions should resolve")
	# First should be the fastest (agumon, side=0, slot=0 -> 0)
	assert_eq(order[0], 0, "Fastest (agumon, spe=80) should go first")
	# Last should be the slowest (tank, side=1, slot=1 -> 11)
	assert_eq(order[3], 11, "Slowest (tank, spe=30) should go last")


# --- ON_ALLY_FAINT ---


func test_on_ally_faint_fires_for_partner() -> void:
	# Side 0: test_agumon (slot 0), test_patamon (slot 1, has ON_ALLY_FAINT ability)
	var partner: BattleDigimonState = _battle.get_digimon_at(0, 1)
	# test_patamon has test_ability_on_ally_faint: ON_ALLY_FAINT, ONCE_PER_TURN, atk+1
	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	agumon.current_hp = 1

	var initial_atk_stage: int = partner.stat_stages[&"attack"]

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(0, 1),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
		TestBattleFactory.make_rest_action(1, 1),
	]
	_engine.execute_turn(actions)

	assert_true(agumon.is_fainted, "Agumon should be fainted")
	assert_eq(
		partner.stat_stages[&"attack"], initial_atk_stage + 1,
		"ON_ALLY_FAINT should boost partner's attack by +1",
	)


# --- Side retains with one fainted ---


func test_side_retains_with_one_fainted() -> void:
	var foe_0: BattleDigimonState = _battle.get_digimon_at(1, 0)
	foe_0.current_hp = 1

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(0, 1),
		TestBattleFactory.make_rest_action(1, 0),
		TestBattleFactory.make_rest_action(1, 1),
	]
	_engine.execute_turn(actions)

	assert_true(foe_0.is_fainted, "Foe slot 0 should faint")
	assert_false(_battle.is_battle_over, "Battle should not end — foe slot 1 still alive")
	var foe_1: BattleDigimonState = _battle.get_digimon_at(1, 1)
	assert_false(foe_1.is_fainted, "Foe slot 1 should still be alive")


# --- 4 actions per turn ---


func test_four_actions_per_turn() -> void:
	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(0, 1),
		TestBattleFactory.make_rest_action(1, 0),
		TestBattleFactory.make_rest_action(1, 1),
	]
	_engine.execute_turn(actions)
	assert_signal_emit_count(
		_engine, "action_resolved", 4,
		"All 4 actions should be resolved in 2v2",
	)
