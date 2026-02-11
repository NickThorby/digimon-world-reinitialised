extends GutTest
## Integration tests for preset field effects — environment conditions applied
## at battle start with auto-restoration behaviour.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# ==========================================================================
# Preset field effects — basic application
# ==========================================================================


func test_preset_weather_applied() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"weather": {"key": &"sun", "permanent": true}},
	)
	_engine = TestBattleFactory.create_engine(_battle)
	assert_true(
		_battle.field.has_weather(&"sun"),
		"Battle should start with preset sun weather",
	)
	assert_eq(
		int(_battle.field.weather.get("duration", 0)), -1,
		"Permanent preset weather should have duration -1",
	)


func test_preset_terrain_applied() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"terrain": {"key": &"flooded", "permanent": true}},
	)
	_engine = TestBattleFactory.create_engine(_battle)
	assert_true(
		_battle.field.has_terrain(&"flooded"),
		"Battle should start with preset flooded terrain",
	)
	assert_eq(
		int(_battle.field.terrain.get("duration", 0)), -1,
		"Permanent preset terrain should have duration -1",
	)


func test_preset_global_effect_applied() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"global_effects": [{"key": &"grounding_field", "permanent": true}]},
	)
	_engine = TestBattleFactory.create_engine(_battle)
	assert_true(
		_battle.field.has_global_effect(&"grounding_field"),
		"Battle should start with preset grounding field",
	)


# ==========================================================================
# Preset permanent weather restoration
# ==========================================================================


func test_preset_weather_restores_after_override_expires() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"weather": {"key": &"sun", "permanent": true}},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Override with rain (duration 5) using technique
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_rain_dance", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(
		_battle.field.has_weather(&"rain"),
		"Weather should be rain after override",
	)

	# Tick through turns until rain expires (duration 5, tick once per turn end)
	# Turn 1 already ticked at end, so 4 more turns needed
	for i: int in 4:
		var rest_actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest_actions)

	# After rain expires, sun should restore
	assert_true(
		_battle.field.has_weather(&"sun"),
		"Preset sun should restore after rain expires",
	)
	assert_eq(
		int(_battle.field.weather.get("duration", 0)), -1,
		"Restored preset weather should have duration -1",
	)


func test_preset_weather_restores_after_clear() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"weather": {"key": &"sun", "permanent": true}},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Clear weather with technique
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_clear_weather", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Sun should be restored at end of the same turn
	assert_true(
		_battle.field.has_weather(&"sun"),
		"Preset sun should restore after being cleared",
	)


# ==========================================================================
# Preset permanent terrain restoration
# ==========================================================================


func test_preset_terrain_restores_after_override_expires() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"terrain": {"key": &"flooded", "permanent": true}},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Override with fiery terrain (duration 5)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_fiery_terrain", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_true(
		_battle.field.has_terrain(&"fiery"),
		"Terrain should be fiery after override",
	)

	# Tick through turns until fiery expires
	for i: int in 4:
		var rest_actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest_actions)

	# After fiery expires, flooded should restore
	assert_true(
		_battle.field.has_terrain(&"flooded"),
		"Preset flooded terrain should restore after fiery expires",
	)


# ==========================================================================
# Preset permanent global effect restoration
# ==========================================================================


func test_preset_global_effect_restores_after_removal() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"global_effects": [{"key": &"grounding_field", "permanent": true}]},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Remove grounding field with technique
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_remove_grounding", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Grounding field should be restored at end of turn
	assert_true(
		_battle.field.has_global_effect(&"grounding_field"),
		"Preset grounding field should restore after removal",
	)


# ==========================================================================
# Preset permanent side effect restoration
# ==========================================================================


func test_preset_side_effect_restores_after_removal() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{},
		[{"key": &"physical_barrier", "sides": [], "permanent": true}],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Verify it was applied
	assert_true(
		_battle.sides[0].has_side_effect(&"physical_barrier"),
		"Side 0 should have physical barrier preset",
	)
	assert_true(
		_battle.sides[1].has_side_effect(&"physical_barrier"),
		"Side 1 should have physical barrier preset (sides=[] means all)",
	)

	# Remove from side 1 via technique targeting side 1
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_remove_physical_barrier", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Physical barrier should be restored on side 1 at end of turn
	assert_true(
		_battle.sides[1].has_side_effect(&"physical_barrier"),
		"Preset physical barrier should restore on side 1 after removal",
	)


# ==========================================================================
# Preset permanent hazard restoration (delayed)
# ==========================================================================


func test_preset_hazard_returns_after_delay() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{}, [],
		[{
			"key": &"entry_damage", "sides": [1], "layers": 1,
			"permanent": true,
			"extra": {"damagePercent": 0.125, "element": &"fire"},
		}],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Verify hazard was applied
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 1,
		"Side 1 should have entry_damage hazard",
	)

	# Remove hazard with defog (removeAll)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_defog", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Hazard should be gone but pending return
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 0,
		"Hazard should be removed after defog",
	)
	assert_true(
		_battle.pending_hazard_returns.size() > 0,
		"Should have pending hazard return scheduled",
	)

	# Tick through delay (preset_hazard_return_delay = 2)
	var rest_actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(rest_actions)

	# After 2 turns total (1 already happened), hazard should return
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 1,
		"Preset hazard should return after delay",
	)


func test_preset_hazard_non_permanent_no_return() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{}, [],
		[{
			"key": &"entry_damage", "sides": [1], "layers": 1,
			"permanent": false,
			"extra": {"damagePercent": 0.125, "element": &"fire"},
		}],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Verify hazard was applied
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 1,
		"Side 1 should have entry_damage hazard",
	)

	# Remove with defog
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_defog", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# No pending returns for non-permanent
	assert_eq(
		_battle.pending_hazard_returns.size(), 0,
		"Non-permanent hazard should not schedule a return",
	)

	# Tick a few turns
	for i: int in 3:
		var rest_actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest_actions)

	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 0,
		"Non-permanent hazard should not return",
	)


# ==========================================================================
# Brick permanent (duration -1)
# ==========================================================================


func test_brick_permanent_weather_never_expires() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Manually set weather with duration -1 (brick permanent)
	_battle.field.set_weather(&"sun", -1, 0)

	# Tick through many turns
	for i: int in 10:
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

	assert_true(
		_battle.field.has_weather(&"sun"),
		"Brick permanent weather (duration -1) should never expire",
	)


func test_brick_permanent_weather_no_restore_on_override() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Set brick permanent sun (not a preset — no auto-restore)
	_battle.field.set_weather(&"sun", -1, 0)

	# Override with rain
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_rain_dance", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_true(
		_battle.field.has_weather(&"rain"),
		"Rain should override brick permanent sun",
	)

	# Let rain expire
	for i: int in 4:
		var rest_actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest_actions)

	# Sun should NOT restore (was brick permanent, not preset permanent)
	assert_false(
		_battle.field.has_weather(&"sun"),
		"Brick permanent weather should NOT auto-restore after override",
	)
	assert_false(
		_battle.field.has_weather(),
		"Weather should be empty after rain expires (no preset restoration)",
	)


func test_brick_permanent_side_effect_never_expires() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Set brick permanent side effect (duration -1)
	_battle.sides[0].add_side_effect(&"physical_barrier", -1)

	# Tick through many turns
	for i: int in 10:
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

	assert_true(
		_battle.sides[0].has_side_effect(&"physical_barrier"),
		"Brick permanent side effect (duration -1) should never expire",
	)


# ==========================================================================
# Non-permanent presets
# ==========================================================================


func test_non_permanent_preset_weather_no_restore() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"weather": {"key": &"sun", "permanent": false, "duration": 5}},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Override with rain
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_rain_dance", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Let rain expire
	for i: int in 4:
		var rest_actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest_actions)

	# Sun should NOT restore (was non-permanent preset)
	assert_false(
		_battle.field.has_weather(&"sun"),
		"Non-permanent preset weather should not restore after override",
	)


func test_non_permanent_preset_terrain_expires_normally() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{"terrain": {"key": &"flooded", "permanent": false, "duration": 3}},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	assert_true(
		_battle.field.has_terrain(&"flooded"),
		"Should start with flooded terrain",
	)

	# Tick 3 turns (terrain should expire)
	for i: int in 3:
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

	assert_false(
		_battle.field.has_terrain(&"flooded"),
		"Non-permanent preset terrain should expire normally after duration",
	)


# ==========================================================================
# Flexible side targeting
# ==========================================================================


func test_preset_hazard_specific_sides() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{}, [],
		[{
			"key": &"entry_damage", "sides": [0], "layers": 1,
			"permanent": true,
			"extra": {"damagePercent": 0.125, "element": &"fire"},
		}],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	assert_eq(
		_battle.sides[0].get_hazard_layers(&"entry_damage"), 1,
		"Side 0 should have the hazard",
	)
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 0,
		"Side 1 should NOT have the hazard (only applied to side 0)",
	)


func test_preset_hazard_all_sides() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{}, [],
		[{
			"key": &"entry_damage", "sides": [], "layers": 1,
			"permanent": true,
			"extra": {"damagePercent": 0.125, "element": &"fire"},
		}],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	assert_eq(
		_battle.sides[0].get_hazard_layers(&"entry_damage"), 1,
		"Side 0 should have the hazard (sides=[] means all)",
	)
	assert_eq(
		_battle.sides[1].get_hazard_layers(&"entry_damage"), 1,
		"Side 1 should have the hazard (sides=[] means all)",
	)


func test_preset_side_effect_multiple_sides() -> void:
	_battle = TestBattleFactory.create_preset_battle(
		{},
		[{"key": &"physical_barrier", "sides": [0, 1], "permanent": true}],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	assert_true(
		_battle.sides[0].has_side_effect(&"physical_barrier"),
		"Side 0 should have physical barrier",
	)
	assert_true(
		_battle.sides[1].has_side_effect(&"physical_barrier"),
		"Side 1 should have physical barrier",
	)
