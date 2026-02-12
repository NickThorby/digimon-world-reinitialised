extends GutTest
## Unit tests for FieldState (weather, terrain, global effects).

var _field: FieldState


func before_each() -> void:
	_field = FieldState.new()


# --- Weather ---


func test_set_weather() -> void:
	_field.set_weather(&"sun", 5, 0)
	assert_true(_field.has_weather(&"sun"), "Should have sun weather")
	assert_true(_field.has_weather(), "Should have any weather")


func test_clear_weather() -> void:
	_field.set_weather(&"rain", 5, 0)
	_field.clear_weather()
	assert_false(_field.has_weather(), "Should have no weather after clear")


func test_has_weather_generic() -> void:
	assert_false(_field.has_weather(), "Should have no weather initially")
	_field.set_weather(&"sandstorm", 3, 0)
	assert_true(_field.has_weather(), "Should have weather after setting")


func test_has_weather_specific() -> void:
	_field.set_weather(&"rain", 5, 0)
	assert_true(_field.has_weather(&"rain"), "Should have rain")
	assert_false(_field.has_weather(&"sun"), "Should not have sun")


func test_weather_replaces_previous() -> void:
	_field.set_weather(&"sun", 5, 0)
	_field.set_weather(&"rain", 3, 1)
	assert_true(_field.has_weather(&"rain"), "Should have rain (replaced sun)")
	assert_false(_field.has_weather(&"sun"), "Sun should be replaced")


# --- Terrain ---


func test_set_terrain() -> void:
	_field.set_terrain(&"flooded", 5, 0)
	assert_true(_field.has_terrain(&"flooded"), "Should have flooded terrain")
	assert_true(_field.has_terrain(), "Should have any terrain")


func test_clear_terrain() -> void:
	_field.set_terrain(&"blooming", 5, 0)
	_field.clear_terrain()
	assert_false(_field.has_terrain(), "Should have no terrain after clear")


func test_has_terrain_generic() -> void:
	assert_false(_field.has_terrain(), "Should have no terrain initially")
	_field.set_terrain(&"flooded", 3, 0)
	assert_true(_field.has_terrain(), "Should have terrain after setting")


func test_has_terrain_specific() -> void:
	_field.set_terrain(&"flooded", 5, 0)
	assert_true(_field.has_terrain(&"flooded"), "Should have flooded")
	assert_false(_field.has_terrain(&"blooming"), "Should not have blooming")


func test_terrain_replaces_previous() -> void:
	_field.set_terrain(&"flooded", 5, 0)
	_field.set_terrain(&"blooming", 3, 1)
	assert_true(_field.has_terrain(&"blooming"), "Should have blooming (replaced flooded)")
	assert_false(_field.has_terrain(&"flooded"), "Flooded should be replaced")


# --- Global effects ---


func test_add_global_effect() -> void:
	_field.add_global_effect(&"grounding_field", 5)
	assert_true(_field.has_global_effect(&"grounding_field"), "Should have effect")


func test_refresh_global_effect_duration() -> void:
	_field.add_global_effect(&"grounding_field", 3)
	_field.add_global_effect(&"grounding_field", 5)
	# Should update duration, not duplicate
	var count: int = 0
	for effect: Dictionary in _field.global_effects:
		if effect.get("key", &"") == &"grounding_field":
			count += 1
			assert_eq(
				int(effect.get("duration", 0)), 5,
				"Duration should be refreshed to 5",
			)
	assert_eq(count, 1, "Should only have one grounding_field entry")


func test_remove_global_effect() -> void:
	_field.add_global_effect(&"grounding_field", 5)
	_field.remove_global_effect(&"grounding_field")
	assert_false(
		_field.has_global_effect(&"grounding_field"),
		"Effect should be removed",
	)


func test_has_global_effect_false() -> void:
	assert_false(
		_field.has_global_effect(&"grounding_field"),
		"Should not have effect initially",
	)


# --- tick_durations() ---


func test_tick_weather_expires() -> void:
	_field.set_weather(&"sun", 1, 0)
	var expired: Dictionary = _field.tick_durations()
	assert_true(expired.get("weather", false), "Weather should expire at duration 1")
	assert_false(_field.has_weather(), "Weather should be cleared after expiring")


func test_tick_weather_decrements() -> void:
	_field.set_weather(&"rain", 3, 0)
	_field.tick_durations()
	assert_true(_field.has_weather(&"rain"), "Rain should still be active")
	assert_eq(
		int(_field.weather.get("duration", 0)), 2,
		"Duration should decrement to 2",
	)


func test_tick_terrain_expires() -> void:
	_field.set_terrain(&"flooded", 1, 0)
	var expired: Dictionary = _field.tick_durations()
	assert_true(expired.get("terrain", false), "Terrain should expire at duration 1")
	assert_false(_field.has_terrain(), "Terrain should be cleared after expiring")


func test_tick_global_effect_expires() -> void:
	_field.add_global_effect(&"grounding_field", 1)
	var expired: Dictionary = _field.tick_durations()
	var expired_effects: Array = expired.get("global_effects", [])
	assert_true(
		expired_effects.has(&"grounding_field"),
		"Grounding field should be in expired list",
	)
	assert_false(
		_field.has_global_effect(&"grounding_field"),
		"Effect should be removed after expiring",
	)


func test_tick_multiple_durations_independently() -> void:
	_field.set_weather(&"sun", 2, 0)
	_field.set_terrain(&"flooded", 1, 0)
	_field.add_global_effect(&"grounding_field", 3)

	var expired: Dictionary = _field.tick_durations()

	assert_false(expired.get("weather", false), "Weather should not expire yet (2->1)")
	assert_true(expired.get("terrain", false), "Terrain should expire (1->0)")
	assert_true(_field.has_weather(&"sun"), "Sun should still be active")
	assert_false(_field.has_terrain(), "Terrain should be gone")
	assert_true(
		_field.has_global_effect(&"grounding_field"),
		"Global effect should still be active (3->2)",
	)
