extends GutTest
## Unit tests for StorageState box-based storage system.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Initialisation ---


func test_default_box_count() -> void:
	var storage := StorageState.new()
	assert_eq(storage.get_box_count(), 100,
		"Default storage should have 100 boxes")


func test_default_box_names() -> void:
	var storage := StorageState.new()
	assert_eq(storage.boxes[0]["name"], "Box 1",
		"First box should be named 'Box 1'")
	assert_eq(storage.boxes[99]["name"], "Box 100",
		"Last box should be named 'Box 100'")


func test_all_slots_start_empty() -> void:
	var storage := StorageState.new()
	assert_eq(storage.get_total_stored(), 0,
		"New storage should be empty")


# --- CRUD ---


func test_set_and_get_digimon() -> void:
	var storage := StorageState.new()
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	storage.set_digimon(0, 0, digimon)
	var retrieved: DigimonState = storage.get_digimon(0, 0)
	assert_not_null(retrieved, "Should retrieve stored Digimon")
	assert_eq(retrieved.key, &"test_agumon", "Retrieved Digimon key should match")


func test_remove_digimon() -> void:
	var storage := StorageState.new()
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	storage.set_digimon(0, 0, digimon)
	var removed: DigimonState = storage.remove_digimon(0, 0)
	assert_not_null(removed, "remove_digimon should return the Digimon")
	assert_eq(removed.key, &"test_agumon", "Removed Digimon key should match")
	assert_null(storage.get_digimon(0, 0), "Slot should be empty after removal")


func test_remove_empty_slot_returns_null() -> void:
	var storage := StorageState.new()
	var removed: DigimonState = storage.remove_digimon(0, 0)
	assert_null(removed, "Removing from empty slot should return null")


func test_get_total_stored() -> void:
	var storage := StorageState.new()
	storage.set_digimon(0, 0, TestBattleFactory.make_digimon_state(&"test_agumon"))
	storage.set_digimon(0, 1, TestBattleFactory.make_digimon_state(&"test_gabumon"))
	storage.set_digimon(1, 0, TestBattleFactory.make_digimon_state(&"test_patamon"))
	assert_eq(storage.get_total_stored(), 3,
		"Should count 3 stored Digimon across boxes")


# --- Swap ---


func test_swap_digimon_same_box() -> void:
	var storage := StorageState.new()
	var agumon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var gabumon: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon")
	storage.set_digimon(0, 0, agumon)
	storage.set_digimon(0, 1, gabumon)
	storage.swap_digimon(0, 0, 0, 1)
	assert_eq(storage.get_digimon(0, 0).key, &"test_gabumon",
		"Slot 0 should now have gabumon")
	assert_eq(storage.get_digimon(0, 1).key, &"test_agumon",
		"Slot 1 should now have agumon")


func test_swap_digimon_different_boxes() -> void:
	var storage := StorageState.new()
	var agumon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var gabumon: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon")
	storage.set_digimon(0, 0, agumon)
	storage.set_digimon(5, 3, gabumon)
	storage.swap_digimon(0, 0, 5, 3)
	assert_eq(storage.get_digimon(0, 0).key, &"test_gabumon",
		"Box 0 slot 0 should now have gabumon")
	assert_eq(storage.get_digimon(5, 3).key, &"test_agumon",
		"Box 5 slot 3 should now have agumon")


func test_swap_with_empty_slot() -> void:
	var storage := StorageState.new()
	var agumon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	storage.set_digimon(0, 0, agumon)
	storage.swap_digimon(0, 0, 0, 1)
	assert_null(storage.get_digimon(0, 0),
		"Original slot should be empty after swap with empty")
	assert_eq(storage.get_digimon(0, 1).key, &"test_agumon",
		"Target slot should now have the Digimon")


# --- Find first empty ---


func test_find_first_empty_slot() -> void:
	var storage := StorageState.new()
	var result: Dictionary = storage.find_first_empty_slot()
	assert_eq(result, {"box": 0, "slot": 0},
		"First empty slot in fresh storage should be box 0 slot 0")


func test_find_first_empty_slot_skips_occupied() -> void:
	var storage := StorageState.new()
	storage.set_digimon(0, 0, TestBattleFactory.make_digimon_state(&"test_agumon"))
	var result: Dictionary = storage.find_first_empty_slot()
	assert_eq(result, {"box": 0, "slot": 1},
		"Should skip occupied slot 0 and return slot 1")


# --- Bounds safety ---


func test_get_out_of_bounds_box_returns_null() -> void:
	var storage := StorageState.new()
	assert_null(storage.get_digimon(-1, 0), "Negative box index should return null")
	assert_null(storage.get_digimon(999, 0), "Box index beyond count should return null")


func test_get_out_of_bounds_slot_returns_null() -> void:
	var storage := StorageState.new()
	assert_null(storage.get_digimon(0, -1), "Negative slot index should return null")
	assert_null(storage.get_digimon(0, 999), "Slot index beyond count should return null")


func test_set_out_of_bounds_does_not_crash() -> void:
	var storage := StorageState.new()
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	# These should silently do nothing
	storage.set_digimon(-1, 0, digimon)
	storage.set_digimon(999, 0, digimon)
	storage.set_digimon(0, -1, digimon)
	storage.set_digimon(0, 999, digimon)
	assert_eq(storage.get_total_stored(), 0, "No Digimon should be stored after OOB sets")


# --- Serialisation ---


func test_serialisation_round_trip() -> void:
	var storage := StorageState.new()
	storage.set_digimon(0, 0, TestBattleFactory.make_digimon_state(&"test_agumon"))
	storage.set_digimon(2, 5, TestBattleFactory.make_digimon_state(&"test_gabumon"))
	storage.boxes[0]["name"] = "My Box"

	var data: Dictionary = storage.to_dict()
	var restored: StorageState = StorageState.from_dict(data)

	assert_eq(restored.get_total_stored(), 2,
		"Restored storage should have 2 Digimon")
	assert_eq(restored.get_digimon(0, 0).key, &"test_agumon",
		"Box 0 slot 0 should be agumon")
	assert_eq(restored.get_digimon(2, 5).key, &"test_gabumon",
		"Box 2 slot 5 should be gabumon")
	assert_eq(restored.boxes[0]["name"], "My Box",
		"Custom box name should persist")
	assert_null(restored.get_digimon(0, 1),
		"Empty slots should remain null after restore")


func test_from_dict_empty_creates_default() -> void:
	var restored: StorageState = StorageState.from_dict({})
	assert_eq(restored.get_box_count(), 100,
		"from_dict with empty data should create default boxes")
	assert_eq(restored.get_total_stored(), 0,
		"from_dict with empty data should have no stored Digimon")
