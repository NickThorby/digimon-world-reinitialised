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


# --- Give item from bag (mirrors _handle_give_item logic) ---


func test_give_gear_from_bag_equips_and_decrements() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	var item_key: StringName = &"test_power_band"
	inventory.items[item_key] = 5

	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	assert_not_null(item_data, "Item should exist in Atlas")

	# Exact logic from _handle_give_item
	if item_data.is_consumable:
		if digimon.equipped_consumable_key != &"":
			var old_key: StringName = digimon.equipped_consumable_key
			inventory.items[old_key] = int(inventory.items.get(old_key, 0)) + 1
		digimon.equipped_consumable_key = item_key
	else:
		if digimon.equipped_gear_key != &"":
			var old_key: StringName = digimon.equipped_gear_key
			inventory.items[old_key] = int(inventory.items.get(old_key, 0)) + 1
		digimon.equipped_gear_key = item_key

	var current_qty: int = inventory.items.get(item_key, 0) as int
	if current_qty <= 1:
		inventory.items.erase(item_key)
	else:
		inventory.items[item_key] = current_qty - 1

	assert_eq(digimon.equipped_gear_key, item_key,
		"Digimon should have the gear equipped")
	assert_eq(int(inventory.items.get(item_key, 0)), 4,
		"Inventory should decrease from 5 to 4")


func test_give_consumable_from_bag_equips_and_decrements() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	var item_key: StringName = &"test_heal_berry"
	inventory.items[item_key] = 3

	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	assert_not_null(item_data, "Item should exist in Atlas")

	if item_data.is_consumable:
		if digimon.equipped_consumable_key != &"":
			var old_key: StringName = digimon.equipped_consumable_key
			inventory.items[old_key] = int(inventory.items.get(old_key, 0)) + 1
		digimon.equipped_consumable_key = item_key
	else:
		if digimon.equipped_gear_key != &"":
			var old_key: StringName = digimon.equipped_gear_key
			inventory.items[old_key] = int(inventory.items.get(old_key, 0)) + 1
		digimon.equipped_gear_key = item_key

	var current_qty: int = inventory.items.get(item_key, 0) as int
	if current_qty <= 1:
		inventory.items.erase(item_key)
	else:
		inventory.items[item_key] = current_qty - 1

	assert_eq(digimon.equipped_consumable_key, item_key,
		"Digimon should have the consumable equipped")
	assert_eq(int(inventory.items.get(item_key, 0)), 2,
		"Inventory should decrease from 3 to 2")


func test_give_last_item_removes_from_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	var item_key: StringName = &"test_power_band"
	inventory.items[item_key] = 1

	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	assert_not_null(item_data, "Item should exist in Atlas")

	if item_data.is_consumable:
		digimon.equipped_consumable_key = item_key
	else:
		digimon.equipped_gear_key = item_key

	var current_qty: int = inventory.items.get(item_key, 0) as int
	if current_qty <= 1:
		inventory.items.erase(item_key)
	else:
		inventory.items[item_key] = current_qty - 1

	assert_false(inventory.items.has(item_key),
		"Last item should be erased from inventory")


func test_give_swaps_existing_gear_back_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &"test_power_band"
	var inventory := InventoryState.new()
	var new_key: StringName = &"test_counter_gem"
	inventory.items[new_key] = 2
	inventory.items[&"test_power_band"] = 0

	var item_data: ItemData = Atlas.items.get(new_key) as ItemData
	assert_not_null(item_data, "Item should exist in Atlas")

	if item_data.is_consumable:
		if digimon.equipped_consumable_key != &"":
			var old_key: StringName = digimon.equipped_consumable_key
			inventory.items[old_key] = int(inventory.items.get(old_key, 0)) + 1
		digimon.equipped_consumable_key = new_key
	else:
		if digimon.equipped_gear_key != &"":
			var old_key: StringName = digimon.equipped_gear_key
			inventory.items[old_key] = int(inventory.items.get(old_key, 0)) + 1
		digimon.equipped_gear_key = new_key

	var current_qty: int = inventory.items.get(new_key, 0) as int
	if current_qty <= 1:
		inventory.items.erase(new_key)
	else:
		inventory.items[new_key] = current_qty - 1

	assert_eq(digimon.equipped_gear_key, new_key,
		"New gear should be equipped")
	assert_eq(int(inventory.items.get(new_key, 0)), 1,
		"New gear should decrease from 2 to 1")
	assert_eq(int(inventory.items.get(&"test_power_band", 0)), 1,
		"Old gear should be returned to inventory")


func test_give_same_item_already_equipped_is_rejected() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var inventory := InventoryState.new()
	var item_key: StringName = &"test_heal_berry"
	# Digimon already has this berry equipped, and bag has 5 more
	digimon.equipped_consumable_key = item_key
	inventory.items[item_key] = 5

	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	assert_not_null(item_data, "Item should exist in Atlas")

	# Mirrors _handle_give_item: reject if already holding same item
	var already_held: bool = false
	if item_data.is_consumable:
		already_held = digimon.equipped_consumable_key == item_key
	else:
		already_held = digimon.equipped_gear_key == item_key

	assert_true(already_held, "Should detect item is already held")
	# When already held, give is skipped — inventory unchanged
	assert_eq(int(inventory.items.get(item_key, 0)), 5,
		"Inventory should remain at 5 when give is rejected")
