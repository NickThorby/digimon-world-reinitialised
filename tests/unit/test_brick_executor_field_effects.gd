extends GutTest
## Unit tests for BrickExecutor field effect, side effect, and hazard handlers.

var _battle: BattleState
var _user: BattleDigimonState
var _target: BattleDigimonState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_user = _battle.get_digimon_at(0, 0)
	_target = _battle.get_digimon_at(1, 0)


# --- Field Effect: Weather ---


func test_field_effect_sets_weather() -> void:
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "weather", "weather": "sun",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	assert_eq(result.get("weather", &""), &"sun")
	assert_eq(result.get("action", ""), "set")
	assert_true(_battle.field.has_weather(&"sun"), "Weather should be sun")


func test_field_effect_removes_weather() -> void:
	_battle.field.set_weather(&"rain", 5, 0)
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "weather",
		"weather": "rain", "remove": true,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false))
	assert_eq(result.get("action", ""), "remove")
	assert_false(_battle.field.has_weather(), "Weather should be cleared")


func test_field_effect_weather_uses_default_duration() -> void:
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "weather", "weather": "rain",
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	var duration: int = int(_battle.field.weather.get("duration", 0))
	assert_eq(duration, 5, "Should use default weather duration from GameBalance")


func test_field_effect_weather_custom_duration() -> void:
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "weather",
		"weather": "hail", "duration": 8,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	var duration: int = int(_battle.field.weather.get("duration", 0))
	assert_eq(duration, 8, "Should use custom duration")


# --- Field Effect: Terrain ---


func test_field_effect_sets_terrain() -> void:
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "terrain", "terrain": "flooded",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false))
	assert_eq(result.get("terrain", &""), &"flooded")
	assert_true(
		_battle.field.has_terrain(&"flooded"),
		"Terrain should be flooded",
	)


func test_field_effect_removes_terrain() -> void:
	_battle.field.set_terrain(&"blooming", 5, 0)
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "terrain",
		"terrain": "blooming", "remove": true,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false))
	assert_false(_battle.field.has_terrain(), "Terrain should be cleared")


# --- Field Effect: Global ---


func test_field_effect_sets_global_effect() -> void:
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "global",
		"effect": "speed_inversion",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false))
	assert_eq(result.get("global", &""), &"speed_inversion")
	assert_true(
		_battle.field.has_global_effect(&"speed_inversion"),
		"Global effect should be active",
	)


func test_field_effect_removes_global_effect() -> void:
	_battle.field.add_global_effect(&"gear_suppression", 5)
	var brick: Dictionary = {
		"brick": "fieldEffect", "type": "global",
		"effect": "gear_suppression", "remove": true,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false))
	assert_false(
		_battle.field.has_global_effect(&"gear_suppression"),
		"Global effect should be removed",
	)


# --- Side Effect ---


func test_side_effect_sets_on_user_side() -> void:
	var brick: Dictionary = {
		"brick": "sideEffect", "effect": "physical_barrier",
		"side": "user", "duration": 5,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false))
	assert_eq(result.get("effect", &""), &"physical_barrier")
	assert_true(
		_battle.sides[_user.side_index].has_side_effect(
			&"physical_barrier",
		),
		"User side should have physical_barrier",
	)


func test_side_effect_sets_on_target_side() -> void:
	var brick: Dictionary = {
		"brick": "sideEffect", "effect": "status_immunity",
		"side": "target", "duration": 3,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_true(
		_battle.sides[_target.side_index].has_side_effect(
			&"status_immunity",
		),
	)


func test_side_effect_resolves_all_foes() -> void:
	var brick: Dictionary = {
		"brick": "sideEffect", "effect": "stat_drop_immunity",
		"side": "allFoes", "duration": 5,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_true(
		_battle.sides[_target.side_index].has_side_effect(
			&"stat_drop_immunity",
		),
	)
	assert_false(
		_battle.sides[_user.side_index].has_side_effect(
			&"stat_drop_immunity",
		),
	)


func test_side_effect_resolves_both() -> void:
	var brick: Dictionary = {
		"brick": "sideEffect", "effect": "speed_boost",
		"side": "both", "duration": 5,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_true(
		_battle.sides[0].has_side_effect(&"speed_boost"),
		"Side 0 should have speed_boost",
	)
	assert_true(
		_battle.sides[1].has_side_effect(&"speed_boost"),
		"Side 1 should have speed_boost",
	)


func test_side_effect_removes() -> void:
	_battle.sides[0].add_side_effect(&"physical_barrier", 5)
	var brick: Dictionary = {
		"brick": "sideEffect", "effect": "physical_barrier",
		"side": "user", "remove": true,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_false(
		_battle.sides[0].has_side_effect(&"physical_barrier"),
		"Barrier should be removed",
	)


# --- Hazard ---


func test_hazard_lays_entry_damage() -> void:
	var brick: Dictionary = {
		"brick": "hazard", "hazardType": "entry_damage",
		"damagePercent": 0.125, "element": "fire",
		"maxLayers": 3, "side": "target",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false))
	assert_eq(result.get("hazard", &""), &"entry_damage")
	assert_eq(result.get("action", ""), "set")
	assert_eq(
		_battle.sides[_target.side_index].get_hazard_layers(
			&"entry_damage",
		),
		1,
	)


func test_hazard_respects_max_layers() -> void:
	var brick: Dictionary = {
		"brick": "hazard", "hazardType": "entry_damage",
		"damagePercent": 0.125, "maxLayers": 2, "side": "target",
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_eq(
		_battle.sides[_target.side_index].get_hazard_layers(
			&"entry_damage",
		),
		2,
		"Should cap at maxLayers",
	)


func test_hazard_remove_all() -> void:
	_battle.sides[1].add_hazard(&"entry_damage", 2)
	_battle.sides[1].add_hazard(&"entry_stat_reduction", 1)
	var brick: Dictionary = {
		"brick": "hazard", "removeAll": true, "side": "target",
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_eq(
		_battle.sides[1].hazards.size(), 0,
		"All hazards should be cleared",
	)


func test_hazard_remove_specific() -> void:
	_battle.sides[1].add_hazard(&"entry_damage", 2)
	_battle.sides[1].add_hazard(&"entry_stat_reduction", 1)
	var brick: Dictionary = {
		"brick": "hazard", "remove": "entry_damage", "side": "target",
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 0,
		"entry_damage should be removed",
	)
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_stat_reduction"), 1,
		"entry_stat_reduction should remain",
	)


func test_hazard_stores_extra_data() -> void:
	var brick: Dictionary = {
		"brick": "hazard", "hazardType": "entry_damage",
		"damagePercent": 0.125, "element": "fire",
		"maxLayers": 3, "side": "target",
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	var hazard: Dictionary = _battle.sides[_target.side_index].hazards[0]
	assert_eq(
		float(hazard.get("damagePercent", 0.0)), 0.125,
		"damagePercent should be stored",
	)
	assert_eq(
		hazard.get("element", &"") as StringName, &"fire",
		"element should be stored",
	)
