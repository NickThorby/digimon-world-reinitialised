extends GutTest
## Unit tests for data-driven terrain config: tick damage, tick healing,
## element modifiers, aerial immunity, and the is_aerial_on_terrain helper.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Fiery terrain tick damage ---


func test_fiery_terrain_tick_damage() -> void:
	# Non-fire Digimon (gabumon has no fire resistance ≤ 0.5) takes damage
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_gabumon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"fiery", 5, 0)

	var gabumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = gabumon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		gabumon.current_hp, hp_before,
		"Non-fire-resistant Digimon should take fiery terrain tick damage",
	)


func test_fiery_terrain_fire_resistant_immune() -> void:
	# Agumon has fire resistance 0.5 (≤ 0.5 = immune)
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"fiery", 5, 0)

	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = agumon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		agumon.current_hp, hp_before,
		"Fire-resistant Digimon (resistance ≤ 0.5) should be immune to fiery terrain",
	)


func test_fiery_terrain_aerial_immune() -> void:
	# Patamon is aerial → immune to all terrain effects
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_patamon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"fiery", 5, 0)

	var patamon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = patamon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		patamon.current_hp, hp_before,
		"Aerial Digimon should be immune to fiery terrain tick damage",
	)


func test_fiery_terrain_aerial_grounded_takes_damage() -> void:
	# Patamon (aerial) + grounding_field → takes fiery terrain damage
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_patamon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"fiery", 5, 0)
	_battle.field.add_global_effect(&"grounding_field", 5)

	var patamon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = patamon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		patamon.current_hp, hp_before,
		"Grounded aerial Digimon should take fiery terrain tick damage",
	)


# --- Fiery terrain element modifier ---


func test_fiery_terrain_fire_damage_boosted() -> void:
	# Fire damage should be boosted on fiery terrain
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Baseline without terrain
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var no_terrain_damage: int = hp_before - target.current_hp

	# With fiery terrain
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"fiery", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var terrain_damage: int = hp_before - target.current_hp

	assert_gt(
		terrain_damage, no_terrain_damage,
		"Fiery terrain should boost fire damage via element_modifiers (1.5x)",
	)


func test_fiery_terrain_aerial_user_no_element_boost() -> void:
	# Aerial fire user should NOT get terrain element boost.
	# Use agumon as target — fire res 0.5 means immune to fiery terrain tick,
	# so end-of-turn tick damage won't pollute the comparison.
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_aerial_fire_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Baseline without terrain
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var no_terrain_damage: int = hp_before - target.current_hp

	# With fiery terrain — aerial user should get no boost
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_aerial_fire_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"fiery", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var terrain_damage: int = hp_before - target.current_hp

	assert_eq(
		terrain_damage, no_terrain_damage,
		"Aerial user should get no terrain element boost",
	)


# --- Blooming terrain tick healing ---


func test_blooming_terrain_plant_healed() -> void:
	# Plant mon (plant element trait) should be healed by blooming terrain
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_plant_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"blooming", 5, 0)

	var plant_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	@warning_ignore("integer_division")
	plant_mon.apply_damage(plant_mon.max_hp / 2)
	var hp_before: int = plant_mon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_gt(
		plant_mon.current_hp, hp_before,
		"Plant mon should be healed by blooming terrain",
	)


func test_blooming_terrain_non_plant_not_healed() -> void:
	# Agumon (fire trait) should NOT be healed by blooming terrain
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"blooming", 5, 0)

	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	@warning_ignore("integer_division")
	agumon.apply_damage(agumon.max_hp / 2)
	var hp_before: int = agumon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		agumon.current_hp, hp_before,
		"Non-plant Digimon should not be healed by blooming terrain",
	)


func test_blooming_terrain_aerial_plant_not_healed() -> void:
	# Aerial Digimon with plant trait added should still not heal (aerial immune)
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_patamon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"blooming", 5, 0)

	var patamon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# Add plant element trait via volatiles override
	patamon.volatiles["element_trait_overrides"] = [&"light", &"plant"]
	@warning_ignore("integer_division")
	patamon.apply_damage(patamon.max_hp / 2)
	var hp_before: int = patamon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		patamon.current_hp, hp_before,
		"Aerial Digimon should not be healed by terrain even with plant trait",
	)


# --- Flooded terrain element modifier ---


func test_flooded_terrain_water_damage_boosted() -> void:
	# Water damage should be boosted on flooded terrain
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Baseline without terrain
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var no_terrain_damage: int = hp_before - target.current_hp

	# With flooded terrain
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_terrain(&"flooded", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var terrain_damage: int = hp_before - target.current_hp

	assert_gt(
		terrain_damage, no_terrain_damage,
		"Flooded terrain should boost water damage via element_modifiers (1.5x)",
	)


# --- Aerial helper unit tests ---


func test_is_aerial_on_terrain_true() -> void:
	# Patamon (aerial) with no grounding field → true
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_patamon", &"test_agumon",
	)
	var patamon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_true(
		DamageCalculator.is_aerial_on_terrain(patamon, _battle),
		"Patamon (aerial) should return true for is_aerial_on_terrain",
	)


func test_is_aerial_on_terrain_grounded() -> void:
	# Patamon (aerial) + grounding_field → false
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_patamon", &"test_agumon",
	)
	_battle.field.add_global_effect(&"grounding_field", 5)
	var patamon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_false(
		DamageCalculator.is_aerial_on_terrain(patamon, _battle),
		"Patamon + grounding_field should return false",
	)


func test_is_aerial_on_terrain_terrestrial() -> void:
	# Agumon (terrestrial) → false
	_battle = TestBattleFactory.create_1v1_battle()
	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_false(
		DamageCalculator.is_aerial_on_terrain(agumon, _battle),
		"Agumon (terrestrial) should return false for is_aerial_on_terrain",
	)
