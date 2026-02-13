extends GutTest
## Unit tests for party state manipulation logic (no UI).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Swap members ---


func test_swap_members() -> void:
	var party: PartyState = TestScreenFactory.create_test_party(3, 50)
	var first_key: StringName = party.members[0].key
	var last_key: StringName = party.members[2].key
	# Swap indices 0 and 2
	var temp: DigimonState = party.members[0]
	party.members[0] = party.members[2]
	party.members[2] = temp
	assert_eq(party.members[0].key, last_key,
		"After swap, index 0 should hold the previously last member")
	assert_eq(party.members[2].key, first_key,
		"After swap, index 2 should hold the previously first member")


func test_swap_same_index_noop() -> void:
	var party: PartyState = TestScreenFactory.create_test_party(3, 50)
	var original_key: StringName = party.members[1].key
	# Swap index 1 with itself
	var temp: DigimonState = party.members[1]
	party.members[1] = party.members[1]
	party.members[1] = temp
	assert_eq(party.members[1].key, original_key,
		"Swapping an index with itself should leave the member unchanged")


# --- Take gear ---


func test_take_gear_removes_key() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &"test_power_band"
	# Simulate taking gear off
	digimon.equipped_gear_key = &""
	assert_eq(digimon.equipped_gear_key, &"",
		"Gear key should be empty after removal")


func test_take_gear_adds_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &"test_power_band"
	var inventory := InventoryState.new()
	# Simulate taking gear: move to inventory, clear slot
	var gear_key: StringName = digimon.equipped_gear_key
	inventory.items[gear_key] = int(inventory.items.get(gear_key, 0)) + 1
	digimon.equipped_gear_key = &""
	assert_eq(int(inventory.items.get(&"test_power_band", 0)), 1,
		"Inventory should contain the removed gear")


# --- Take consumable ---


func test_take_consumable_removes_key() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_consumable_key = &"test_heal_berry"
	digimon.equipped_consumable_key = &""
	assert_eq(digimon.equipped_consumable_key, &"",
		"Consumable key should be empty after removal")


func test_take_consumable_adds_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_consumable_key = &"test_heal_berry"
	var inventory := InventoryState.new()
	var consumable_key: StringName = digimon.equipped_consumable_key
	inventory.items[consumable_key] = int(inventory.items.get(consumable_key, 0)) + 1
	digimon.equipped_consumable_key = &""
	assert_eq(int(inventory.items.get(&"test_heal_berry", 0)), 1,
		"Inventory should contain the removed consumable")


# --- Gear stacking ---


func test_take_gear_stacks() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &"test_power_band"
	var inventory := InventoryState.new()
	inventory.items[&"test_power_band"] = 2
	# Take gear from Digimon, add to existing stack
	var gear_key: StringName = digimon.equipped_gear_key
	inventory.items[gear_key] = int(inventory.items.get(gear_key, 0)) + 1
	digimon.equipped_gear_key = &""
	assert_eq(int(inventory.items[&"test_power_band"]), 3,
		"Gear quantity should increment from 2 to 3")


# --- Select filter ---


func test_select_filter_rejects_fainted() -> void:
	var is_alive := func(d: DigimonState) -> bool: return d.current_hp > 0

	var fainted: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	fainted.current_hp = 0
	assert_false(is_alive.call(fainted),
		"Filter should reject a fainted Digimon with 0 HP")

	var alive: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	alive.current_hp = 50
	assert_true(is_alive.call(alive),
		"Filter should accept an alive Digimon with HP > 0")


# --- Give item from bag (uses ItemGiveHandler) ---


func test_give_gear_from_bag_equips_and_decrements() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	inventory.items[&"test_power_band"] = 5

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_power_band", inventory,
	)

	assert_eq(result.result, ItemGiveHandler.GiveResult.EQUIPPED,
		"Should return EQUIPPED for new gear")
	assert_eq(digimon.equipped_gear_key, &"test_power_band",
		"Digimon should have the gear equipped")
	assert_eq(int(inventory.items.get(&"test_power_band", 0)), 4,
		"Inventory should decrease from 5 to 4")


func test_give_consumable_from_bag_equips_and_decrements() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	inventory.items[&"test_heal_berry"] = 3

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_heal_berry", inventory,
	)

	assert_eq(result.result, ItemGiveHandler.GiveResult.EQUIPPED,
		"Should return EQUIPPED for new consumable")
	assert_eq(digimon.equipped_consumable_key, &"test_heal_berry",
		"Digimon should have the consumable equipped")
	assert_eq(int(inventory.items.get(&"test_heal_berry", 0)), 2,
		"Inventory should decrease from 3 to 2")


func test_give_last_item_removes_from_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	inventory.items[&"test_power_band"] = 1

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_power_band", inventory,
	)

	assert_eq(result.result, ItemGiveHandler.GiveResult.EQUIPPED,
		"Should return EQUIPPED")
	assert_false(inventory.items.has(&"test_power_band"),
		"Last item should be erased from inventory")


func test_give_swaps_existing_gear_back_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &"test_power_band"
	var inventory := InventoryState.new()
	inventory.items[&"test_counter_gem"] = 2
	inventory.items[&"test_power_band"] = 0

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_counter_gem", inventory,
	)

	assert_eq(result.result, ItemGiveHandler.GiveResult.SWAPPED,
		"Should return SWAPPED when replacing existing gear")
	assert_eq(result.old_key, &"test_power_band",
		"Should report old key")
	assert_eq(digimon.equipped_gear_key, &"test_counter_gem",
		"New gear should be equipped")
	assert_eq(int(inventory.items.get(&"test_counter_gem", 0)), 1,
		"New gear should decrease from 2 to 1")
	assert_eq(int(inventory.items.get(&"test_power_band", 0)), 1,
		"Old gear should be returned to inventory")


func test_give_same_item_already_equipped_is_rejected() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	digimon.equipped_consumable_key = &"test_heal_berry"
	inventory.items[&"test_heal_berry"] = 5

	var result: Dictionary = ItemGiveHandler.give_item(
		digimon, &"test_heal_berry", inventory,
	)

	assert_eq(result.result, ItemGiveHandler.GiveResult.ALREADY_HELD,
		"Should return ALREADY_HELD")
	assert_eq(int(inventory.items.get(&"test_heal_berry", 0)), 5,
		"Inventory should remain at 5 when give is rejected")
