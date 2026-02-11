extends GutTest
## Unit tests for flexible weather config: element modifiers, stat modifiers,
## per-element healing, and resistance-based tick immunity.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()
	# Add temporary test weather for negate_resistance tests
	Registry.WEATHER_CONFIG[&"test_negate_res_weather"] = {
		"negate_resistance": [&"fire"],
	}
	# Add temporary test weather for tick healing tests
	Registry.WEATHER_CONFIG[&"test_healing_weather"] = {
		"tick_healing": true,
		"healing_elements": [&"plant"],
	}


func after_all() -> void:
	TestBattleFactory.clear_test_data()
	Registry.WEATHER_CONFIG.erase(&"test_negate_res_weather")
	Registry.WEATHER_CONFIG.erase(&"test_healing_weather")


# --- Element modifiers (damage) ---


func test_sun_fire_damage_boosted() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# No weather baseline
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var no_weather_damage: int = hp_before - target.current_hp

	# With sun
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sun", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var sun_damage: int = hp_before - target.current_hp

	assert_gt(
		sun_damage, no_weather_damage,
		"Sun should boost fire damage via element_modifiers (1.5x)",
	)


func test_sun_water_damage_nerfed() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sun", 5, 0)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_water_gun", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var sun_damage: int = hp_before - target.current_hp

	# Without weather
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(0, 0, &"test_water_gun", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var neutral_damage: int = hp_before - target.current_hp

	assert_lt(
		sun_damage, neutral_damage,
		"Sun should nerf water damage via element_modifiers (0.5x)",
	)


func test_rain_water_damage_boosted() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"rain", 5, 0)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_water_gun", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var rain_damage: int = hp_before - target.current_hp

	# Without weather
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(0, 0, &"test_water_gun", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var neutral_damage: int = hp_before - target.current_hp

	assert_gt(
		rain_damage, neutral_damage,
		"Rain should boost water damage via element_modifiers (1.5x)",
	)


func test_no_element_modifier_neutral_element() -> void:
	# A null-element technique should not be modified by sun
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sun", 5, 0)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var sun_damage: int = hp_before - target.current_hp

	# Without weather
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var neutral_damage: int = hp_before - target.current_hp

	assert_eq(
		sun_damage, neutral_damage,
		"Null-element technique should not be affected by sun weather",
	)


# --- Per-element healing ---


func test_sun_plant_heal_boosted() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"sun", 5, 0)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	var tech: TechniqueData = Atlas.techniques[&"test_plant_heal"]
	BrickExecutor.execute_bricks(tech.bricks, user, user, tech, _battle)

	var healed: int = user.current_hp - hp_before
	# In sun with plant element: healing_boost → weather_healing_boost (0.667)
	var expected_min: int = floori(float(user.max_hp) * 0.6)
	assert_gt(
		healed, expected_min,
		"Plant-element healing in sun should be boosted (healed %d)" % healed,
	)


func test_sun_null_element_heal_default() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"sun", 5, 0)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	# test_weather_heal has null element — not in healing_boost_elements
	var tech: TechniqueData = Atlas.techniques[&"test_weather_heal"]
	BrickExecutor.execute_bricks(tech.bricks, user, user, tech, _battle)

	var healed: int = user.current_hp - hp_before
	# Sun no longer blanket-boosts; null element → default (0.5)
	var expected: int = floori(float(user.max_hp) * 0.5)
	assert_eq(
		healed, expected,
		"Null-element weather heal in sun should use default (0.5), not boost",
	)


func test_sandstorm_fire_heal_nerfed() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	var tech: TechniqueData = Atlas.techniques[&"test_fire_heal"]
	BrickExecutor.execute_bricks(tech.bricks, user, user, tech, _battle)

	var healed: int = user.current_hp - hp_before
	# Fire element in sandstorm healing_nerf_elements → weather_healing_nerf (0.25)
	var expected_max: int = ceili(float(user.max_hp) * 0.3)
	assert_lt(
		healed, expected_max,
		"Fire-element healing in sandstorm should be nerfed (healed %d)" % healed,
	)


func test_rain_water_heal_boosted() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"rain", 5, 0)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	var tech: TechniqueData = Atlas.techniques[&"test_water_heal"]
	BrickExecutor.execute_bricks(tech.bricks, user, user, tech, _battle)

	var healed: int = user.current_hp - hp_before
	# Water element in rain → healing_boost → 0.667
	var expected_min: int = floori(float(user.max_hp) * 0.6)
	assert_gt(
		healed, expected_min,
		"Water-element healing in rain should be boosted (healed %d)" % healed,
	)


func test_no_weather_default_healing() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	var tech: TechniqueData = Atlas.techniques[&"test_weather_heal"]
	BrickExecutor.execute_bricks(tech.bricks, user, user, tech, _battle)

	var healed: int = user.current_hp - hp_before
	var expected: int = floori(float(user.max_hp) * 0.5)
	assert_eq(
		healed, expected,
		"Weather healing with no weather should heal 50%% of max HP",
	)


# --- Stat modifiers ---


func test_sandstorm_earth_special_defence_boost() -> void:
	# Earth-type Digimon should get 1.5x SpDef in sandstorm
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_earth_mon",
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Fire blast (special) on earth mon without weather
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var no_weather_damage: int = hp_before - target.current_hp

	# With sandstorm → earth mon gets 1.5x SpDef
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_earth_mon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sandstorm", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var sandstorm_damage: int = hp_before - target.current_hp

	assert_lt(
		sandstorm_damage, no_weather_damage,
		"Earth mon should take less special damage in sandstorm (SpDef 1.5x)",
	)


func test_sandstorm_non_earth_no_spdef_boost() -> void:
	# Non-earth Digimon should not get SpDef boost in sandstorm
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var no_weather_damage: int = hp_before - target.current_hp

	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sandstorm", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var sandstorm_damage: int = hp_before - target.current_hp

	assert_eq(
		sandstorm_damage, no_weather_damage,
		"Non-earth Digimon should not get SpDef boost in sandstorm",
	)


func test_snow_ice_defence_boost() -> void:
	# Ice-type Digimon should get 1.5x Def in snow
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_ice_mon",
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Physical attack without weather
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var no_weather_damage: int = hp_before - target.current_hp

	# With snow
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_ice_mon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"snow", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var snow_damage: int = hp_before - target.current_hp

	assert_lt(
		snow_damage, no_weather_damage,
		"Ice mon should take less physical damage in snow (Def 1.5x)",
	)


func test_get_weather_stat_multiplier_no_weather() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_weather_stat_multiplier(
		_battle, &"attack", user,
	)
	assert_eq(mult, 1.0, "No weather should return 1.0")


func test_get_weather_stat_multiplier_sandstorm_earth() -> void:
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_earth_mon", &"test_agumon",
	)
	_battle.field.set_weather(&"sandstorm", 5, 0)
	var earth_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_weather_stat_multiplier(
		_battle, &"special_defence", earth_mon,
	)
	assert_eq(
		mult, 1.5,
		"Earth mon SpDef in sandstorm should be 1.5 (stage +1)",
	)


func test_get_weather_stat_multiplier_sandstorm_non_earth() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"sandstorm", 5, 0)
	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_weather_stat_multiplier(
		_battle, &"special_defence", agumon,
	)
	assert_eq(
		mult, 1.0,
		"Non-earth mon SpDef in sandstorm should be 1.0",
	)


func test_get_weather_stat_multiplier_fog_accuracy() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"fog", 5, 0)
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_weather_stat_multiplier(
		_battle, &"accuracy", user,
	)
	# Fog accuracy -1 stage → STAT_STAGE_MULTIPLIERS[-1] = 0.67
	assert_eq(
		mult, 0.67,
		"Fog should give accuracy multiplier of 0.67 (stage -1)",
	)


func test_get_weather_stat_multiplier_snow_ice_defence() -> void:
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_ice_mon", &"test_agumon",
	)
	_battle.field.set_weather(&"snow", 5, 0)
	var ice_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_weather_stat_multiplier(
		_battle, &"defence", ice_mon,
	)
	assert_eq(
		mult, 1.5,
		"Ice mon Def in snow should be 1.5 (stage +1)",
	)


func test_get_weather_stat_multiplier_snow_non_ice() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"snow", 5, 0)
	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_weather_stat_multiplier(
		_battle, &"defence", agumon,
	)
	assert_eq(
		mult, 1.0,
		"Non-ice mon Def in snow should be 1.0",
	)


# --- Resistance-based tick immunity ---


func test_sandstorm_earth_resistant_immune() -> void:
	# test_earth_mon has earth: 0.5 resistance (≤ 0.5 = immune)
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_earth_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var earth_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = earth_mon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		earth_mon.current_hp, hp_before,
		"Earth-resistant mon (resistance ≤ 0.5) should be immune to sandstorm",
	)


func test_sandstorm_metal_resistant_immune() -> void:
	# test_metal_mon has metal: 0.5, earth: 0.5 resistances
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_metal_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var metal_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = metal_mon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		metal_mon.current_hp, hp_before,
		"Metal-resistant mon should be immune to sandstorm tick damage",
	)


func test_sandstorm_non_resistant_takes_damage() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = agumon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		agumon.current_hp, hp_before,
		"Non-resistant Digimon should take sandstorm tick damage",
	)


func test_resistance_override_grants_tick_immunity() -> void:
	# Give a normally non-immune Digimon earth resistance via override
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# Override earth resistance to 0.5 (immune threshold)
	agumon.volatiles["resistance_overrides"] = {&"earth": 0.5}
	var hp_before: int = agumon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		agumon.current_hp, hp_before,
		"Resistance override granting earth ≤ 0.5 should grant sandstorm immunity",
	)


func test_hail_ice_resistant_immune() -> void:
	# test_ice_mon has ice: 0.5 resistance
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_ice_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"hail", 5, 0)

	var ice_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = ice_mon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		ice_mon.current_hp, hp_before,
		"Ice-resistant mon should be immune to hail tick damage",
	)


# --- Side effect stat modifiers ---


func test_get_side_effect_stat_multiplier_speed_boost() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	var digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	_battle.sides[0].add_side_effect(&"speed_boost", 5)
	var mult: float = DamageCalculator.get_side_effect_stat_multiplier(
		_battle, &"speed", digimon,
	)
	assert_eq(
		mult, 1.5,
		"Speed boost side effect should give 1.5x speed (stage +1)",
	)


func test_get_side_effect_stat_multiplier_no_effect() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	var digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_side_effect_stat_multiplier(
		_battle, &"speed", digimon,
	)
	assert_eq(
		mult, 1.0,
		"No active side effects should return 1.0",
	)


func test_get_side_effect_stat_multiplier_wrong_stat() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	var digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	_battle.sides[0].add_side_effect(&"speed_boost", 5)
	var mult: float = DamageCalculator.get_side_effect_stat_multiplier(
		_battle, &"attack", digimon,
	)
	assert_eq(
		mult, 1.0,
		"Speed boost should not affect attack stat",
	)


func test_get_side_effect_stat_multiplier_null_battle() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	var digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.get_side_effect_stat_multiplier(
		null, &"speed", digimon,
	)
	assert_eq(
		mult, 1.0,
		"Null battle should return 1.0",
	)


func test_get_side_effect_stat_multiplier_opponent_unaffected() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.sides[0].add_side_effect(&"speed_boost", 5)
	# Opponent (side 1) should not get the boost
	var opponent: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var mult: float = DamageCalculator.get_side_effect_stat_multiplier(
		_battle, &"speed", opponent,
	)
	assert_eq(
		mult, 1.0,
		"Speed boost on side 0 should not affect side 1 Digimon",
	)


# --- Negate elements ---


func test_heavy_rain_negates_fire_attack() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"heavy_rain", 5, 0)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Heavy rain should completely negate fire-type attacks",
	)


func test_extremely_harsh_sunlight_negates_water_attack() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"extremely_harsh_sunlight", 5, 0)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Extremely harsh sunlight should completely negate water-type attacks",
	)


func test_heavy_rain_does_not_negate_non_fire() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"heavy_rain", 5, 0)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		target.current_hp, hp_before,
		"Heavy rain should not negate null-element attacks",
	)


func test_heavy_rain_boosts_water() -> void:
	# Without weather
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var neutral_damage: int = hp_before - target.current_hp

	# With heavy rain
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"heavy_rain", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	actions = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var heavy_rain_damage: int = hp_before - target.current_hp

	assert_gt(
		heavy_rain_damage, neutral_damage,
		"Heavy rain should still boost water damage via element_modifiers",
	)


# --- Negate resistance ---


func test_negate_resistance_removes_resistance() -> void:
	# test_agumon has fire resistance 0.5 — negate_resistance should set to 1.0
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"test_negate_res_weather", 5, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(
		&"fire", target, _battle,
	)
	assert_eq(
		mult, 1.0,
		"negate_resistance should set fire resistance 0.5 to 1.0",
	)


func test_negate_resistance_does_not_affect_weakness() -> void:
	# test_agumon has water weakness 1.5 — negate_resistance[fire] should not
	# affect water or any weakness
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"test_negate_res_weather", 5, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(
		&"water", target, _battle,
	)
	assert_eq(
		mult, 1.5,
		"negate_resistance should not affect elements not in the list",
	)


func test_negate_resistance_no_weather_unaffected() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(
		&"fire", target, _battle,
	)
	assert_eq(
		mult, 0.5,
		"Without weather, fire resistance should remain 0.5",
	)


# --- Increase resistance (strong winds) ---


func test_strong_winds_removes_lightning_weakness() -> void:
	# test_earth_mon has lightning weakness 1.5 — strong_winds should set to 1.0
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_earth_mon", &"test_agumon",
	)
	_battle.field.set_weather(&"strong_winds", 5, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(
		&"lightning", target, _battle,
	)
	assert_eq(
		mult, 1.0,
		"strong_winds should clamp lightning weakness 1.5 to 1.0",
	)


func test_strong_winds_does_not_affect_lightning_resistance() -> void:
	# Give a Digimon lightning resistance via override — should not be affected
	_battle = TestBattleFactory.create_1v1_battle()
	_battle.field.set_weather(&"strong_winds", 5, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	target.volatiles["resistance_overrides"] = {&"lightning": 0.5}
	var mult: float = DamageCalculator.calculate_element_multiplier(
		&"lightning", target, _battle,
	)
	assert_eq(
		mult, 0.5,
		"strong_winds should not affect lightning resistance (0.5 stays 0.5)",
	)


# --- Weather tick healing ---


func test_weather_tick_healing_matching_element() -> void:
	# Plant mon should be healed by test_healing_weather
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_plant_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"test_healing_weather", 5, 0)

	var plant_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	plant_mon.apply_damage(plant_mon.max_hp / 2)
	var hp_before: int = plant_mon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_gt(
		plant_mon.current_hp, hp_before,
		"Plant mon should be healed by weather with healing_elements [plant]",
	)


func test_weather_tick_healing_non_matching_element() -> void:
	# Agumon (fire trait) should NOT be healed by test_healing_weather
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"test_healing_weather", 5, 0)

	var agumon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	agumon.apply_damage(agumon.max_hp / 2)
	var hp_before: int = agumon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		agumon.current_hp, hp_before,
		"Non-plant Digimon should not be healed by weather with healing_elements [plant]",
	)
