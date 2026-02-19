extends GutTest
## Unit tests for battle evolution mechanics.

var _battle: BattleState
var _engine: BattleEngine


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Priority ---


func test_evolve_action_has_maximum_priority() -> void:
	# EVOLVE should execute before techniques (MAXIMUM priority)
	var evolve: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var tech: BattleAction = TestBattleFactory.make_technique_action(
		1, 0, &"test_tackle", 0, 0,
	)
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(
		[tech, evolve], _battle,
	)
	assert_eq(
		sorted[0].action_type, BattleAction.ActionType.EVOLVE,
		"EVOLVE should have MAXIMUM priority (before techniques)",
	)


# --- Standard evolution ---


func test_evolve_changes_species_and_recalculates_stats() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	var old_key: StringName = user.source_state.key
	var old_max_hp: int = user.max_hp

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	# Pair with a rest so engine has actions for both sides
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_eq(
		user.source_state.key, &"test_tank",
		"Source state key should change to evolved form",
	)
	assert_eq(
		user.data.key, &"test_tank",
		"Battle data reference should be updated",
	)
	assert_ne(
		user.max_hp, old_max_hp,
		"Max HP should change after species change (different base stats)",
	)


func test_evolve_preserves_stat_stages() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	user.stat_stages[&"attack"] = 2
	user.stat_stages[&"speed"] = -1

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_eq(
		user.stat_stages[&"attack"], 2,
		"Stat stages should be preserved through evolution",
	)
	assert_eq(
		user.stat_stages[&"speed"], -1,
		"Negative stat stages should persist through evolution",
	)


func test_evolve_preserves_status_conditions() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	user.add_status(&"burned", 3)

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_true(
		user.has_status(&"burned"),
		"Status conditions should persist through evolution",
	)


func test_evolve_preserves_slot_identity_and_participation() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	user.participated_against_ids.append(&"some_id")

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_eq(user.side_index, 0, "Side index should remain unchanged")
	assert_eq(user.slot_index, 0, "Slot index should remain unchanged")
	assert_true(
		&"some_id" in user.participated_against_ids,
		"Participation IDs should persist through evolution",
	)


func test_evolve_scales_hp_energy_proportionally() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	# Set HP to 50% of max
	user.current_hp = user.max_hp / 2
	var hp_ratio: float = float(user.current_hp) / float(user.max_hp)

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	# HP should be approximately the same ratio of the new max
	var new_ratio: float = float(user.current_hp) / float(user.max_hp)
	assert_almost_eq(
		new_ratio, hp_ratio, 0.05,
		"HP should scale proportionally (within 5%% tolerance)",
	)


func test_evolve_sets_evolved_in_battle_flag() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	assert_false(user.evolved_in_battle, "Flag should start false")

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_true(
		user.evolved_in_battle,
		"evolved_in_battle should be set after evolution",
	)


# --- De-evolution ---


func test_devolve_reverts_species() -> void:
	# First evolve, then de-evolve
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	var original_key: StringName = user.source_state.key

	var evolve: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([evolve, rest])
	assert_eq(user.source_state.key, &"test_tank", "Should be evolved")

	# Now de-evolve
	var devolve: BattleAction = TestBattleFactory.make_de_evolve_action(0, 0)
	var rest2: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([devolve, rest2])

	assert_eq(
		user.source_state.key, original_key,
		"De-evolution should restore original species",
	)


# --- Jogress ---


func test_jogress_consumes_reserve_partner() -> void:
	# Use battle with reserves: [test_agumon, test_patamon] vs [test_gabumon, test_tank]
	_battle = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_gabumon"],
		[&"test_gabumon", &"test_tank"],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var reserves_before: int = _battle.sides[0].party.size()

	# Jogress: test_agumon + reserve test_gabumon → test_wall
	# Partner index 0 = first reserve
	var action: BattleAction = TestBattleFactory.make_jogress_evolve_action(
		0, 0, &"test_evo_jogress", [0],
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_eq(
		_battle.sides[0].slots[0].digimon.source_state.key, &"test_wall",
		"Jogress should produce the target species",
	)
	assert_true(
		_battle.sides[0].party.size() < reserves_before,
		"Consumed reserve partner should be removed from party",
	)


# --- Failure cases ---


func test_evolve_fainted_digimon_fails() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	user.current_hp = 0
	user.is_fainted = true
	var original_key: StringName = user.source_state.key

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_eq(
		user.source_state.key, original_key,
		"Fainted Digimon should not evolve",
	)


func test_evolve_transformed_digimon_fails() -> void:
	var user: BattleDigimonState = _battle.sides[0].slots[0].digimon
	# Set non-empty transform_backup to simulate transformed state
	user.volatiles["transform_backup"] = {"base_stats": user.base_stats.duplicate()}
	var original_key: StringName = user.source_state.key

	var action: BattleAction = TestBattleFactory.make_evolve_action(
		0, 0, &"test_evo_agumon_tank",
	)
	var rest: BattleAction = TestBattleFactory.make_rest_action(1, 0)
	_engine.execute_turn([action, rest])

	assert_eq(
		user.source_state.key, original_key,
		"Transformed Digimon should not evolve",
	)
