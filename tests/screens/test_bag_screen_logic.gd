extends GutTest
## Unit tests for bag/inventory state manipulation (no UI).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Toss items ---


func test_toss_removes_item() -> void:
	var inventory := InventoryState.new()
	inventory.items[&"test_potion"] = 5
	inventory.items.erase(&"test_potion")
	assert_false(inventory.items.has(&"test_potion"),
		"Item should be removed from inventory after tossing")


func test_toss_nonexistent_safe() -> void:
	var inventory := InventoryState.new()
	# Erasing a key that does not exist should not raise an error
	inventory.items.erase(&"test_nonexistent")
	assert_false(inventory.items.has(&"test_nonexistent"),
		"Erasing a nonexistent key should be safe and cause no error")


# --- Consume items ---


func test_consume_decrements() -> void:
	var inventory := InventoryState.new()
	inventory.items[&"test_potion"] = 5
	inventory.items[&"test_potion"] = int(inventory.items[&"test_potion"]) - 1
	assert_eq(int(inventory.items[&"test_potion"]), 4,
		"Consuming should decrement quantity from 5 to 4")


func test_consume_removes_last() -> void:
	var inventory := InventoryState.new()
	inventory.items[&"test_potion"] = 1
	var new_qty: int = int(inventory.items[&"test_potion"]) - 1
	if new_qty <= 0:
		inventory.items.erase(&"test_potion")
	else:
		inventory.items[&"test_potion"] = new_qty
	assert_false(inventory.items.has(&"test_potion"),
		"Consuming the last item should erase the key from the dictionary")


# --- Use filters ---


func test_revive_filter_targets_fainted() -> void:
	var is_fainted := func(d: DigimonState) -> bool: return d.current_hp <= 0

	var fainted: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	fainted.current_hp = 0
	assert_true(is_fainted.call(fainted),
		"Revive filter should return true for a fainted Digimon (HP <= 0)")

	var alive: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	alive.current_hp = 50
	assert_false(is_fainted.call(alive),
		"Revive filter should return false for an alive Digimon (HP > 0)")


func test_normal_use_filter_targets_alive() -> void:
	var is_alive := func(d: DigimonState) -> bool: return d.current_hp > 0

	var alive: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	alive.current_hp = 50
	assert_true(is_alive.call(alive),
		"Normal use filter should return true for an alive Digimon (HP > 0)")

	var fainted: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	fainted.current_hp = 0
	assert_false(is_alive.call(fainted),
		"Normal use filter should return false for a fainted Digimon (HP <= 0)")
