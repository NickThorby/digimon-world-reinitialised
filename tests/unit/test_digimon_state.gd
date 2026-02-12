extends GutTest
## Unit tests for DigimonState ID generation, serialisation, and tamer fields.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- ID serialisation ---


func test_ids_persist_through_serialisation() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var original_display: StringName = state.display_id
	var original_secret: StringName = state.secret_id
	assert_ne(str(original_display), "", "display_id should be non-empty")
	assert_ne(str(original_secret), "", "secret_id should be non-empty")
	var data: Dictionary = state.to_dict()
	var restored: DigimonState = DigimonState.from_dict(data)
	assert_eq(restored.display_id, original_display,
		"display_id should persist through serialisation")
	assert_eq(restored.secret_id, original_secret,
		"secret_id should persist through serialisation")


func test_backward_compat_generates_ids_when_missing() -> void:
	var data: Dictionary = {
		"key": "test_agumon",
		"level": 10,
	}
	var state: DigimonState = DigimonState.from_dict(data)
	assert_ne(str(state.display_id), "",
		"from_dict should generate display_id when missing")
	assert_ne(str(state.secret_id), "",
		"from_dict should generate secret_id when missing")
	assert_eq(str(state.display_id).length(), 8,
		"Generated display_id should be 8 characters")
	assert_eq(str(state.secret_id).length(), 8,
		"Generated secret_id should be 8 characters")


# --- Tamer fields ---


func test_tamer_fields_persist_through_serialisation() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	state.original_tamer_name = "Marcus Damon"
	state.original_tamer_id = &"tamer_001"
	var data: Dictionary = state.to_dict()
	var restored: DigimonState = DigimonState.from_dict(data)
	assert_eq(restored.original_tamer_name, "Marcus Damon",
		"original_tamer_name should persist")
	assert_eq(restored.original_tamer_id, &"tamer_001",
		"original_tamer_id should persist")


func test_tamer_fields_default_empty() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	assert_eq(state.original_tamer_name, "",
		"original_tamer_name should default to empty")
	assert_eq(state.original_tamer_id, &"",
		"original_tamer_id should default to empty StringName")


# --- Training points ---


func test_training_points_default_zero() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	assert_eq(state.training_points, 0,
		"training_points should default to 0")


func test_training_points_serialisation_round_trip() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	state.training_points = 42
	var data: Dictionary = state.to_dict()
	var restored: DigimonState = DigimonState.from_dict(data)
	assert_eq(restored.training_points, 42,
		"training_points should persist through serialisation")


func test_training_points_backward_compat() -> void:
	# Old save data without training_points
	var data: Dictionary = {
		"key": "test_agumon",
		"level": 10,
	}
	var state: DigimonState = DigimonState.from_dict(data)
	assert_eq(state.training_points, 0,
		"Missing training_points in save data should default to 0")


# --- unique_id ---


func test_unique_id_is_concatenation() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var expected: StringName = StringName(
		str(state.display_id) + str(state.secret_id),
	)
	assert_eq(state.unique_id, expected,
		"unique_id should be display_id + secret_id")
	assert_eq(str(state.unique_id).length(), 16,
		"unique_id should be 16 characters")


func test_factory_assigns_unique_ids() -> void:
	var state_a: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var state_b: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	assert_ne(state_a.unique_id, state_b.unique_id,
		"Two separately created Digimon should have different unique_ids")


func test_helper_assigns_ids() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	assert_ne(str(state.display_id), "",
		"TestBattleFactory should assign non-empty display_id")
	assert_ne(str(state.secret_id), "",
		"TestBattleFactory should assign non-empty secret_id")
	assert_eq(str(state.display_id).length(), 8,
		"display_id should be 8 characters")
	assert_eq(str(state.secret_id).length(), 8,
		"secret_id should be 8 characters")
