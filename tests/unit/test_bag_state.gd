extends GutTest
## Unit tests for BagState.

var _bag: BagState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_bag = BagState.new()


func test_add_and_get_quantity() -> void:
	_bag.add_item(&"test_potion", 3)
	assert_eq(
		_bag.get_quantity(&"test_potion"), 3,
		"Should have 3 potions after adding 3",
	)
	_bag.add_item(&"test_potion", 2)
	assert_eq(
		_bag.get_quantity(&"test_potion"), 5,
		"Should have 5 potions after adding 2 more",
	)


func test_remove_item_success() -> void:
	_bag.add_item(&"test_potion", 3)
	var result: bool = _bag.remove_item(&"test_potion", 2)
	assert_true(result, "Should return true when removing available items")
	assert_eq(
		_bag.get_quantity(&"test_potion"), 1,
		"Should have 1 potion remaining",
	)


func test_remove_item_insufficient() -> void:
	_bag.add_item(&"test_potion", 1)
	var result: bool = _bag.remove_item(&"test_potion", 2)
	assert_false(result, "Should return false when removing more than available")
	assert_eq(
		_bag.get_quantity(&"test_potion"), 1,
		"Quantity should remain unchanged on failure",
	)


func test_remove_item_removes_entry_at_zero() -> void:
	_bag.add_item(&"test_potion", 1)
	_bag.remove_item(&"test_potion", 1)
	assert_false(
		_bag.has_item(&"test_potion"),
		"Should not have item after removing last one",
	)
	assert_eq(
		_bag.get_quantity(&"test_potion"), 0,
		"Quantity should be 0",
	)


func test_has_item() -> void:
	assert_false(
		_bag.has_item(&"test_potion"),
		"Should not have item before adding",
	)
	_bag.add_item(&"test_potion")
	assert_true(
		_bag.has_item(&"test_potion"),
		"Should have item after adding",
	)


func test_get_items_in_category() -> void:
	_bag.add_item(&"test_potion", 2)
	_bag.add_item(&"test_super_potion", 1)
	_bag.add_item(&"test_scanner", 5)
	var medicine: Array[Dictionary] = _bag.get_items_in_category(
		Registry.ItemCategory.MEDICINE,
	)
	assert_eq(
		medicine.size(), 2,
		"Should return 2 medicine items",
	)
	var capture: Array[Dictionary] = _bag.get_items_in_category(
		Registry.ItemCategory.CAPTURE_SCAN,
	)
	assert_eq(
		capture.size(), 1,
		"Should return 1 capture item",
	)


func test_get_combat_usable_items() -> void:
	_bag.add_item(&"test_potion", 2)
	_bag.add_item(&"test_power_band", 1)  # Not combat usable
	_bag.add_item(&"test_scanner", 3)
	var usable: Array[Dictionary] = _bag.get_combat_usable_items()
	# test_potion and test_scanner are combat usable, test_power_band is not
	assert_eq(
		usable.size(), 2,
		"Should return only combat-usable items",
	)


func test_is_empty() -> void:
	assert_true(_bag.is_empty(), "New bag should be empty")
	_bag.add_item(&"test_potion")
	assert_false(_bag.is_empty(), "Bag should not be empty after adding item")
	_bag.remove_item(&"test_potion")
	assert_true(_bag.is_empty(), "Bag should be empty after removing last item")


func test_to_dict_and_from_dict() -> void:
	_bag.add_item(&"test_potion", 3)
	_bag.add_item(&"test_scanner", 1)
	var dict: Dictionary = _bag.to_dict()
	var restored: BagState = BagState.from_dict(dict)
	assert_eq(
		restored.get_quantity(&"test_potion"), 3,
		"Restored bag should have 3 potions",
	)
	assert_eq(
		restored.get_quantity(&"test_scanner"), 1,
		"Restored bag should have 1 scanner",
	)
	assert_false(
		restored.has_item(&"test_super_potion"),
		"Restored bag should not have items that weren't added",
	)
