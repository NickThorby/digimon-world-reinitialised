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


# --- Hyper trained IVs ---


func test_get_final_iv_combines_base_and_hyper() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	state.ivs[&"attack"] = 30
	state.hyper_trained_ivs[&"attack"] = 15
	assert_eq(state.get_final_iv(&"attack"), 45,
		"Final IV should combine base IV + hyper IV")


func test_get_final_iv_capped_at_max() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	state.ivs[&"attack"] = 40
	state.hyper_trained_ivs[&"attack"] = 20
	assert_eq(state.get_final_iv(&"attack"), 50,
		"Final IV should be capped at max_iv (50), not 60")


func test_get_final_iv_no_hyper() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	state.ivs[&"speed"] = 25
	assert_eq(state.get_final_iv(&"speed"), 25,
		"Final IV with no hyper training should equal base IV")


func test_get_total_tvs_sums_all() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	state.tvs = {
		&"hp": 100, &"energy": 50, &"attack": 200,
		&"defence": 0, &"special_attack": 0,
		&"special_defence": 150, &"speed": 0,
	}
	assert_eq(state.get_total_tvs(), 500,
		"get_total_tvs should sum all TV values")


func test_get_total_tvs_empty() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	assert_eq(state.get_total_tvs(), 0,
		"get_total_tvs should return 0 when all TVs are 0")


func test_hyper_trained_ivs_serialisation() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	state.hyper_trained_ivs = {&"attack": 10, &"speed": 5}
	var data: Dictionary = state.to_dict()
	var restored: DigimonState = DigimonState.from_dict(data)
	assert_eq(restored.hyper_trained_ivs.get(&"attack", 0), 10,
		"hyper_trained_ivs[attack] should persist through serialisation")
	assert_eq(restored.hyper_trained_ivs.get(&"speed", 0), 5,
		"hyper_trained_ivs[speed] should persist through serialisation")


func test_hyper_trained_ivs_backward_compat() -> void:
	var data: Dictionary = {
		"key": "test_agumon",
		"level": 10,
	}
	var state: DigimonState = DigimonState.from_dict(data)
	assert_eq(state.hyper_trained_ivs.size(), 0,
		"Missing hyper_trained_ivs should default to empty dict")
