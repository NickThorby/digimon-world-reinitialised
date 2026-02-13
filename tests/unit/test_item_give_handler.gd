extends GutTest
## Unit tests for ItemGiveHandler.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func test_give_gear_equips_and_decrements_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	inventory.items[&"test_power_band"] = 5

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_power_band", inventory,
	)

	assert_eq(
		result.result, ItemGiveHandler.GiveResult.EQUIPPED,
		"Should return EQUIPPED for new gear",
	)
	assert_eq(result.old_key, &"", "No old key when slot was empty")
	assert_eq(
		digimon.equipped_gear_key, &"test_power_band",
		"Digimon should have gear equipped",
	)
	assert_eq(
		int(inventory.items.get(&"test_power_band", 0)), 4,
		"Inventory should decrease from 5 to 4",
	)


func test_give_consumable_equips_and_decrements_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	inventory.items[&"test_heal_berry"] = 3

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_heal_berry", inventory,
	)

	assert_eq(
		result.result, ItemGiveHandler.GiveResult.EQUIPPED,
		"Should return EQUIPPED for new consumable",
	)
	assert_eq(
		digimon.equipped_consumable_key, &"test_heal_berry",
		"Digimon should have consumable equipped",
	)
	assert_eq(
		int(inventory.items.get(&"test_heal_berry", 0)), 2,
		"Inventory should decrease from 3 to 2",
	)


func test_give_last_item_removes_from_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	inventory.items[&"test_power_band"] = 1

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_power_band", inventory,
	)

	assert_eq(
		result.result, ItemGiveHandler.GiveResult.EQUIPPED,
		"Should return EQUIPPED",
	)
	assert_false(
		inventory.items.has(&"test_power_band"),
		"Last item should be erased from inventory",
	)


func test_give_swaps_existing_gear_returns_old_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &"test_power_band"
	var inventory := InventoryState.new()
	inventory.items[&"test_counter_gem"] = 2

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_counter_gem", inventory,
	)

	assert_eq(
		result.result, ItemGiveHandler.GiveResult.SWAPPED,
		"Should return SWAPPED when replacing existing gear",
	)
	assert_eq(
		result.old_key, &"test_power_band",
		"Should report old key",
	)
	assert_eq(
		digimon.equipped_gear_key, &"test_counter_gem",
		"New gear should be equipped",
	)
	assert_eq(
		int(inventory.items.get(&"test_counter_gem", 0)), 1,
		"New gear inventory should decrease from 2 to 1",
	)
	assert_eq(
		int(inventory.items.get(&"test_power_band", 0)), 1,
		"Old gear should be returned to inventory",
	)


func test_give_same_item_already_equipped_returns_already_held() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_consumable_key = &"test_heal_berry"
	var inventory := InventoryState.new()
	inventory.items[&"test_heal_berry"] = 5

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_heal_berry", inventory,
	)

	assert_eq(
		result.result, ItemGiveHandler.GiveResult.ALREADY_HELD,
		"Should return ALREADY_HELD",
	)
	assert_eq(
		int(inventory.items.get(&"test_heal_berry", 0)), 5,
		"Inventory should remain unchanged",
	)
	assert_eq(
		digimon.equipped_consumable_key, &"test_heal_berry",
		"Equipped item should remain unchanged",
	)


func test_give_invalid_item_key_returns_invalid() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"nonexistent_item", inventory,
	)

	assert_eq(
		result.result, ItemGiveHandler.GiveResult.INVALID,
		"Should return INVALID for unknown item key",
	)
