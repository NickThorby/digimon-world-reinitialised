extends GutTest
## Unit tests for SaveManager round-trip logic (no UI nodes needed).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func after_each() -> void:
	SaveManager.delete_save("test_slot", Registry.GameMode.TEST)
	SaveManager.delete_save("test_slot_a", Registry.GameMode.TEST)
	SaveManager.delete_save("test_slot_b", Registry.GameMode.TEST)
	SaveManager.delete_save("test_unused", Registry.GameMode.TEST)


# --- Round-trip ---


func test_save_load_round_trip() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	SaveManager.save_game(state, "test_slot", Registry.GameMode.TEST)
	var loaded: GameState = SaveManager.load_game("test_slot", Registry.GameMode.TEST)
	assert_not_null(loaded, "Loaded GameState should not be null")
	assert_eq(loaded.tamer_name, state.tamer_name,
		"Loaded tamer_name should match the saved value")


# --- Metadata ---


func test_save_metadata_populated() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	SaveManager.save_game(state, "test_slot", Registry.GameMode.TEST)
	var meta: Dictionary = SaveManager.get_save_metadata(
		"test_slot", Registry.GameMode.TEST,
	)
	assert_true(meta.has("tamer_name"), "Metadata should contain 'tamer_name' key")
	assert_eq(str(meta["tamer_name"]), state.tamer_name,
		"Metadata tamer_name should match saved state")


func test_delete_clears_metadata() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	SaveManager.save_game(state, "test_slot", Registry.GameMode.TEST)
	SaveManager.delete_save("test_slot", Registry.GameMode.TEST)
	var meta: Dictionary = SaveManager.get_save_metadata(
		"test_slot", Registry.GameMode.TEST,
	)
	assert_true(meta.is_empty(),
		"Metadata should be empty after deleting the save")


# --- Slot isolation ---


func test_slot_isolation() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	SaveManager.save_game(state, "test_slot_a", Registry.GameMode.TEST)
	var meta_b: Dictionary = SaveManager.get_save_metadata(
		"test_slot_b", Registry.GameMode.TEST,
	)
	assert_true(meta_b.is_empty(),
		"Metadata for an unrelated slot should be empty")


func test_metadata_empty_for_unused_slot() -> void:
	var meta: Dictionary = SaveManager.get_save_metadata(
		"test_unused", Registry.GameMode.TEST,
	)
	assert_true(meta.is_empty(),
		"Metadata for a never-used slot should be an empty dictionary")
