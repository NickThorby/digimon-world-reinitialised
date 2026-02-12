extends GutTest
## Integration tests for entry hazards through the battle engine.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	# Need reserves for switch-in hazard tests
	_battle = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_tank"],
	)
	_engine = TestBattleFactory.create_engine(_battle)


# --- Entry damage hazard ---


func test_entry_damage_hazard_on_switch_in() -> void:
	# Lay a fire hazard on side 1 (12.5% max HP per layer)
	_battle.sides[1].add_hazard(&"entry_damage", 1, {
		"damagePercent": 0.125,
		"element": &"fire",
		"maxLayers": 3,
	})

	# Switch side 1's active Digimon
	var target_side: SideState = _battle.sides[1]
	var incoming_state: DigimonState = target_side.party[0]
	var incoming_data: DigimonData = Atlas.digimon.get(
		incoming_state.key,
	) as DigimonData
	var all_stats: Dictionary = StatCalculator.calculate_all_stats(
		incoming_data, incoming_state,
	)
	var personality: PersonalityData = Atlas.personalities.get(
		incoming_state.personality_key,
	) as PersonalityData
	var expected_max_hp: int = StatCalculator.apply_personality(
		all_stats.get(&"hp", 100), &"hp", personality,
	)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	# Fire hazard damage, scaled by target's fire resistance
	var fire_resistance: float = float(
		new_mon.data.resistances.get(&"fire", 1.0),
	)
	var expected_damage: int = maxi(
		floori(float(expected_max_hp) * 0.125 * fire_resistance), 1,
	)

	assert_lt(
		new_mon.current_hp, expected_max_hp,
		"Incoming Digimon should take hazard damage",
	)
	# Allow +/- 1 for rounding
	assert_almost_eq(
		float(expected_max_hp - new_mon.current_hp),
		float(expected_damage),
		1.0,
		"Hazard damage should be ~12.5%% * fire resistance",
	)


func test_entry_damage_scales_with_layers() -> void:
	# 2 layers should deal more than 1 layer
	_battle.sides[1].add_hazard(&"entry_damage", 2, {
		"damagePercent": 0.125,
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	# 2 layers * 12.5% = 25% max HP
	var expected_damage: int = maxi(
		floori(float(new_mon.max_hp) * 0.125 * 2.0), 1,
	)
	var actual_damage: int = new_mon.max_hp - new_mon.current_hp

	assert_almost_eq(
		float(actual_damage), float(expected_damage), 1.0,
		"2 layers should deal ~25%% damage (got %d vs expected %d)" % [
			actual_damage, expected_damage,
		],
	)


func test_entry_damage_immune_target_takes_no_damage() -> void:
	# test_patamon has dark: 0.0 (immune)
	# Lay a dark element hazard on side 0
	_battle.sides[0].add_hazard(&"entry_damage", 1, {
		"damagePercent": 0.125,
		"element": &"dark",
		"maxLayers": 3,
	})

	# test_patamon is in side 0's party; switch it in
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		new_mon.current_hp, new_mon.max_hp,
		"Immune target should take no hazard damage",
	)


# --- Entry stat reduction ---


func test_entry_stat_reduction_lowers_stat() -> void:
	_battle.sides[1].add_hazard(&"entry_stat_reduction", 1, {
		"stat": "spe",
		"stages": -1,
		"maxLayers": 1,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	assert_eq(
		new_mon.stat_stages.get(&"speed", 0), -1,
		"Speed should be reduced by 1 stage on entry",
	)


# --- Defog clears hazards ---


func test_defog_clears_all_hazards() -> void:
	_battle.sides[1].add_hazard(&"entry_damage", 2, {
		"damagePercent": 0.125,
	})
	_battle.sides[1].add_hazard(&"entry_stat_reduction", 1, {
		"stat": "spe",
		"stages": -1,
	})

	assert_eq(
		_battle.sides[1].hazards.size(), 2,
		"Should have 2 hazards before defog",
	)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_defog", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		_battle.sides[1].hazards.size(), 0,
		"All hazards should be cleared after defog",
	)


# --- Hazard persistence ---


func test_hazards_persist_after_triggering() -> void:
	_battle.sides[1].add_hazard(&"entry_damage", 1, {
		"damagePercent": 0.125,
		"maxLayers": 3,
	})

	# First switch-in
	var actions_1: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions_1)

	# Hazard should still be there
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 1,
		"Hazard should persist after triggering",
	)


# --- Fire hazard technique ---


func test_fire_hazard_technique_lays_hazard() -> void:
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_hazard", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 1,
		"Fire hazard technique should lay entry_damage hazard",
	)


func test_stat_hazard_technique_lays_hazard() -> void:
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_stat_hazard", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_stat_reduction"), 1,
		"Stat hazard technique should lay entry_stat_reduction hazard",
	)


# --- Aerial hazard immunity ---


func test_aerial_mon_immune_to_aerial_hazard() -> void:
	# Patamon (aerial) switches into entry_damage hazard with aerial_is_immune
	_battle.sides[0].add_hazard(&"entry_damage", 1, {
		"damagePercent": 0.125,
		"element": &"fire",
		"maxLayers": 3,
		"aerial_is_immune": true,
	})

	# Switch Patamon in on side 0
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		new_mon.current_hp, new_mon.max_hp,
		"Aerial Digimon should be immune to aerial-immune hazard",
	)


func test_aerial_mon_not_immune_to_grounded_hazard() -> void:
	# Patamon (aerial) switches into hazard WITHOUT aerial_is_immune
	_battle.sides[0].add_hazard(&"entry_damage", 1, {
		"damagePercent": 0.125,
		"element": &"fire",
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_lt(
		new_mon.current_hp, new_mon.max_hp,
		"Aerial Digimon should still take damage from non-aerial-immune hazard",
	)


func test_grounding_field_negates_aerial_immunity() -> void:
	# Patamon (aerial) + grounding_field active → should take damage
	_battle.sides[0].add_hazard(&"entry_damage", 1, {
		"damagePercent": 0.125,
		"element": &"fire",
		"maxLayers": 3,
		"aerial_is_immune": true,
	})
	_battle.field.add_global_effect(&"grounding_field", 5)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_lt(
		new_mon.current_hp, new_mon.max_hp,
		"Grounding field should negate aerial immunity to hazards",
	)


func test_non_aerial_mon_takes_aerial_hazard_damage() -> void:
	# Agumon (terrestrial) switches into aerial-immune hazard → takes damage
	_battle.sides[1].add_hazard(&"entry_damage", 1, {
		"damagePercent": 0.125,
		"element": &"fire",
		"maxLayers": 3,
		"aerial_is_immune": true,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	assert_lt(
		new_mon.current_hp, new_mon.max_hp,
		"Non-aerial Digimon should take damage from aerial-immune hazard",
	)


# --- Entry status effect hazard ---


func test_entry_status_effect_hazard_applies_on_switch_in() -> void:
	# Use agumon as side 1 reserve (no dark immunity, unlike test_tank)
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_agumon"],
	)
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	battle.sides[1].add_hazard(&"entry_status_effect", 1, {
		"status": &"poisoned",
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	engine.execute_turn(actions)

	var new_mon: BattleDigimonState = battle.get_digimon_at(1, 0)
	assert_true(
		new_mon.has_status(&"poisoned"),
		"Incoming Digimon should be poisoned by status hazard",
	)


func test_entry_status_effect_two_layers_upgrades_poison() -> void:
	# Use agumon as side 1 reserve (no dark immunity, unlike test_tank)
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_agumon"],
	)
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	battle.sides[1].add_hazard(&"entry_status_effect", 2, {
		"status": &"poisoned",
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	engine.execute_turn(actions)

	var new_mon: BattleDigimonState = battle.get_digimon_at(1, 0)
	assert_true(
		new_mon.has_status(&"badly_poisoned"),
		"2-layer poison hazard should upgrade to badly_poisoned",
	)
	assert_false(
		new_mon.has_status(&"poisoned"),
		"Base poisoned should be removed after upgrade",
	)


func test_entry_status_effect_two_layers_upgrades_burned() -> void:
	# 2-layer burned → badly_burned
	_battle.sides[1].add_hazard(&"entry_status_effect", 2, {
		"status": &"burned",
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	assert_true(
		new_mon.has_status(&"badly_burned"),
		"2-layer burned hazard should upgrade to badly_burned",
	)


func test_entry_status_effect_two_layers_upgrades_frostbitten() -> void:
	# 2-layer frostbitten → frozen
	_battle.sides[1].add_hazard(&"entry_status_effect", 2, {
		"status": &"frostbitten",
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	assert_true(
		new_mon.has_status(&"frozen"),
		"2-layer frostbitten hazard should upgrade to frozen",
	)


func test_entry_status_effect_three_layers_same_as_two() -> void:
	# Use agumon as side 1 reserve (no dark immunity, unlike test_tank)
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_agumon"],
	)
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	battle.sides[1].add_hazard(&"entry_status_effect", 3, {
		"status": &"poisoned",
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	engine.execute_turn(actions)

	var new_mon: BattleDigimonState = battle.get_digimon_at(1, 0)
	assert_true(
		new_mon.has_status(&"badly_poisoned"),
		"3-layer poison should still upgrade to badly_poisoned",
	)


func test_entry_status_effect_aerial_immunity() -> void:
	# Patamon (aerial) switching into poisoned hazard with aerial_is_immune
	_battle.sides[0].add_hazard(&"entry_status_effect", 1, {
		"status": &"poisoned",
		"maxLayers": 3,
		"aerial_is_immune": true,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_false(
		new_mon.has_status(&"poisoned"),
		"Aerial Digimon should be immune to aerial-immune status hazard",
	)


func test_entry_status_effect_resistance_immunity() -> void:
	# test_patamon has dark: 0.0 (immune to dark element)
	# Poisoned maps to dark resistance immunity
	_battle.sides[0].add_hazard(&"entry_status_effect", 1, {
		"status": &"poisoned",
		"maxLayers": 3,
	})

	# Switch Patamon in on side 0 — no aerial_is_immune, so aerial doesn't
	# block it, but dark resistance ≤ 0.5 should grant immunity
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var new_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_false(
		new_mon.has_status(&"poisoned"),
		"Digimon with dark immunity should resist poison status hazard",
	)


func test_entry_status_effect_persists_after_triggering() -> void:
	_battle.sides[1].add_hazard(&"entry_status_effect", 1, {
		"status": &"poisoned",
		"maxLayers": 3,
	})

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_switch_action(1, 0, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_status_effect"), 1,
		"Status hazard should persist after triggering",
	)
