extends GutTest
## Unit tests for summary screen state manipulation (no UI nodes).


const MAX_EQUIPPED_TECHNIQUES: int = 4


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Unequip technique ---


func test_unequip_technique_valid() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_technique_keys = [
		&"test_tackle", &"test_fire_blast", &"test_ice_beam",
	] as Array[StringName]
	digimon.equipped_technique_keys.remove_at(1)
	assert_eq(digimon.equipped_technique_keys.size(), 2,
		"Equipped array should shrink from 3 to 2 after unequipping")
	assert_eq(digimon.equipped_technique_keys[0], &"test_tackle",
		"First technique should remain unchanged")
	assert_eq(digimon.equipped_technique_keys[1], &"test_ice_beam",
		"Last technique should shift into the removed slot")


func test_unequip_technique_invalid_index() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_technique_keys = [
		&"test_tackle", &"test_fire_blast",
	] as Array[StringName]
	var invalid_index: int = 10
	if invalid_index >= 0 and invalid_index < digimon.equipped_technique_keys.size():
		digimon.equipped_technique_keys.remove_at(invalid_index)
	assert_eq(digimon.equipped_technique_keys.size(), 2,
		"Out-of-range index should leave equipped techniques unchanged")


# --- Equip technique ---


func test_equip_technique_adds() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_technique_keys = [
		&"test_tackle", &"test_fire_blast",
	] as Array[StringName]
	if digimon.equipped_technique_keys.size() < MAX_EQUIPPED_TECHNIQUES:
		digimon.equipped_technique_keys.append(&"test_ice_beam")
	assert_eq(digimon.equipped_technique_keys.size(), 3,
		"Should be able to equip a technique when below the maximum")
	assert_eq(digimon.equipped_technique_keys[2], &"test_ice_beam",
		"Newly equipped technique should be at the end")


func test_equip_technique_respects_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_technique_keys = [
		&"test_tackle", &"test_fire_blast", &"test_ice_beam", &"test_earthquake",
	] as Array[StringName]
	if digimon.equipped_technique_keys.size() < MAX_EQUIPPED_TECHNIQUES:
		digimon.equipped_technique_keys.append(&"test_quick_strike")
	assert_eq(digimon.equipped_technique_keys.size(), 4,
		"Should not exceed the maximum of 4 equipped techniques")
	assert_false(digimon.equipped_technique_keys.has(&"test_quick_strike"),
		"The fifth technique should not have been added")


# --- Swap technique ---


func test_swap_technique_replaces() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_technique_keys = [
		&"test_tackle", &"test_fire_blast", &"test_ice_beam", &"test_earthquake",
	] as Array[StringName]
	var swap_index: int = 1
	digimon.equipped_technique_keys[swap_index] = &"test_quick_strike"
	assert_eq(digimon.equipped_technique_keys[swap_index], &"test_quick_strike",
		"Technique at index 1 should be replaced with the new one")
	assert_eq(digimon.equipped_technique_keys.size(), 4,
		"Array size should remain unchanged after a swap")


func test_swap_technique_invalid_index() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_technique_keys = [
		&"test_tackle", &"test_fire_blast",
	] as Array[StringName]
	var swap_index: int = 5
	if swap_index >= 0 and swap_index < digimon.equipped_technique_keys.size():
		digimon.equipped_technique_keys[swap_index] = &"test_quick_strike"
	assert_eq(digimon.equipped_technique_keys.size(), 2,
		"Out-of-range swap index should leave equipped techniques unchanged")
	assert_false(digimon.equipped_technique_keys.has(&"test_quick_strike"),
		"New technique should not appear when swap index is invalid")


# --- Personality colour ---


func test_personality_colour_boosted() -> void:
	# test_brave boosts ATTACK, reduces SPEED
	var personality: PersonalityData = Atlas.personalities[&"test_brave"]
	assert_eq(personality.boosted_stat, Registry.Stat.ATTACK,
		"Brave personality should boost ATTACK")
	assert_ne(personality.boosted_stat, personality.reduced_stat,
		"Boosted and reduced stats should differ for a non-neutral personality")


func test_personality_colour_reduced() -> void:
	# test_brave boosts ATTACK, reduces SPEED
	var personality: PersonalityData = Atlas.personalities[&"test_brave"]
	assert_eq(personality.reduced_stat, Registry.Stat.SPEED,
		"Brave personality should reduce SPEED")


func test_personality_colour_neutral() -> void:
	# test_neutral has same boosted and reduced stat (both ATTACK)
	var personality: PersonalityData = Atlas.personalities[&"test_neutral"]
	assert_eq(personality.boosted_stat, personality.reduced_stat,
		"Neutral personality should have the same boosted and reduced stat")


# --- Remove gear ---


func test_remove_gear_adds_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &"test_power_band"
	var inventory := InventoryState.new()
	# Remove gear: add to inventory, clear slot
	var gear_key: StringName = digimon.equipped_gear_key
	if gear_key != &"":
		inventory.items[gear_key] = int(inventory.items.get(gear_key, 0)) + 1
		digimon.equipped_gear_key = &""
	assert_eq(digimon.equipped_gear_key, &"",
		"Gear key should be empty after removal")
	assert_eq(int(inventory.items.get(&"test_power_band", 0)), 1,
		"Inventory should contain the removed gear")


func test_remove_gear_noop_when_empty() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_gear_key = &""
	var inventory := InventoryState.new()
	var gear_key: StringName = digimon.equipped_gear_key
	if gear_key != &"":
		inventory.items[gear_key] = int(inventory.items.get(gear_key, 0)) + 1
		digimon.equipped_gear_key = &""
	assert_eq(digimon.equipped_gear_key, &"",
		"Gear key should remain empty")
	assert_eq(inventory.items.size(), 0,
		"Inventory should remain empty when no gear was equipped")


# --- Remove consumable ---


func test_remove_consumable_adds_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.equipped_consumable_key = &"test_heal_berry"
	var inventory := InventoryState.new()
	# Remove consumable: add to inventory, clear slot
	var consumable_key: StringName = digimon.equipped_consumable_key
	if consumable_key != &"":
		inventory.items[consumable_key] = int(inventory.items.get(consumable_key, 0)) + 1
		digimon.equipped_consumable_key = &""
	assert_eq(digimon.equipped_consumable_key, &"",
		"Consumable key should be empty after removal")
	assert_eq(int(inventory.items.get(&"test_heal_berry", 0)), 1,
		"Inventory should contain the removed consumable")
