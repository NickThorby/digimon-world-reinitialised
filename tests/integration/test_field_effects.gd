extends GutTest
## Integration tests for weather and field effects through the battle engine.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Weather setting via technique ---


func test_sunny_day_sets_sun_weather() -> void:
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_sunny_day", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(
		_battle.field.has_weather(&"sun"),
		"Weather should be sun after Sunny Day",
	)


func test_rain_dance_sets_rain_weather() -> void:
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_rain_dance", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(
		_battle.field.has_weather(&"rain"),
		"Weather should be rain after Rain Dance",
	)


# --- Sun boosts fire, nerfs water ---


func test_sun_boosts_fire_damage() -> void:
	# Set sun manually, then fire a fire technique
	_battle.field.set_weather(&"sun", 5, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Measure damage without weather
	_battle.field.clear_weather()
	var hp_before_no_weather: int = target.current_hp
	var actions_1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_1)
	var no_weather_damage: int = hp_before_no_weather - target.current_hp

	# Reset and measure with sun
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sun", 5, 0)
	target = _battle.get_digimon_at(1, 0)
	var hp_before_sun: int = target.current_hp
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fire_blast", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)
	var sun_damage: int = hp_before_sun - target.current_hp

	assert_gt(
		sun_damage, no_weather_damage,
		"Sun should boost fire damage (got %d vs %d)" % [
			sun_damage, no_weather_damage,
		],
	)


func test_sun_nerfs_water_damage() -> void:
	_battle.field.set_weather(&"sun", 5, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Damage with sun (should nerf water)
	var hp_before_sun: int = target.current_hp
	var actions_1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_1)
	var sun_damage: int = hp_before_sun - target.current_hp

	# Damage without weather
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	target = _battle.get_digimon_at(1, 0)
	var hp_before_neutral: int = target.current_hp
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)
	var neutral_damage: int = hp_before_neutral - target.current_hp

	assert_lt(
		sun_damage, neutral_damage,
		"Sun should nerf water damage (got %d vs %d)" % [
			sun_damage, neutral_damage,
		],
	)


# --- Rain boosts water, nerfs fire ---


func test_rain_boosts_water_damage() -> void:
	_battle.field.set_weather(&"rain", 5, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var rain_damage: int = hp_before - target.current_hp

	# Compare with neutral
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	target = _battle.get_digimon_at(1, 0)
	hp_before = target.current_hp
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_water_gun", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)
	var neutral_damage: int = hp_before - target.current_hp

	assert_gt(
		rain_damage, neutral_damage,
		"Rain should boost water damage",
	)


# --- Sandstorm tick damage ---


func test_sandstorm_deals_tick_damage() -> void:
	# test_agumon has fire element, test_gabumon has ice element
	# Neither has earth or metal, so both should take sandstorm damage
	_battle.field.set_weather(&"sandstorm", 5, 0)
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var user_hp_before: int = user.current_hp
	var target_hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		user.current_hp, user_hp_before,
		"User should take sandstorm damage",
	)
	assert_lt(
		target.current_hp, target_hp_before,
		"Target should take sandstorm damage",
	)


func test_sandstorm_earth_immune() -> void:
	# Create battle with earth mon
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_earth_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var earth_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var fire_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var earth_hp_before: int = earth_mon.current_hp
	var fire_hp_before: int = fire_mon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		earth_mon.current_hp, earth_hp_before,
		"Earth mon should be immune to sandstorm",
	)
	assert_lt(
		fire_mon.current_hp, fire_hp_before,
		"Fire mon should take sandstorm damage",
	)


# --- Hail tick damage ---


func test_hail_deals_tick_damage() -> void:
	_battle.field.set_weather(&"hail", 5, 0)
	# Side 0 is test_agumon (fire) — not ice-immune, should take hail damage
	# Side 1 is test_gabumon (ice) — immune to hail
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = user.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		user.current_hp, hp_before,
		"Non-ice Digimon should take hail damage",
	)


func test_hail_ice_immune() -> void:
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_ice_mon", &"test_agumon",
	)
	_engine = TestBattleFactory.create_engine(_battle)
	_battle.field.set_weather(&"hail", 5, 0)

	var ice_mon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var fire_mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var ice_hp_before: int = ice_mon.current_hp
	var fire_hp_before: int = fire_mon.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		ice_mon.current_hp, ice_hp_before,
		"Ice mon should be immune to hail",
	)
	assert_lt(
		fire_mon.current_hp, fire_hp_before,
		"Fire mon should take hail damage",
	)


# --- Weather expiry ---


func test_weather_expires_after_duration() -> void:
	_battle.field.set_weather(&"sun", 2, 0)
	var rest_actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	# Turn 1: duration 2 -> 1
	_engine.execute_turn(rest_actions)
	assert_true(
		_battle.field.has_weather(&"sun"),
		"Sun should still be active after 1 turn",
	)
	# Turn 2: duration 1 -> 0, expires
	_engine.execute_turn(rest_actions)
	assert_false(
		_battle.field.has_weather(),
		"Sun should expire after 2 turns",
	)
