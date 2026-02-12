class_name TestScreenFactory
extends RefCounted
## Helper for creating test data used by screen-related tests.
## Delegates Atlas injection/cleanup to TestBattleFactory.


## Create a GameState pre-populated with party, storage, and inventory.
static func create_test_game_state() -> GameState:
	var state := GameState.new()
	state.tamer_name = "Test Tamer"
	state.tamer_id = &"test_tamer_001"
	state.party = create_test_party(3, 50)
	state.storage = create_test_storage(1, 5)
	state.inventory = create_test_inventory(10000)
	return state


## Create a PartyState with the given number of test Digimon.
static func create_test_party(count: int = 3, level: int = 50) -> PartyState:
	var party := PartyState.new()
	var keys: Array[StringName] = [
		&"test_agumon", &"test_gabumon", &"test_patamon",
		&"test_tank", &"test_sweeper", &"test_wall",
	]
	for i: int in mini(count, keys.size()):
		var member: DigimonState = TestBattleFactory.make_digimon_state(keys[i], level)
		if i == 0:
			member.equipped_gear_key = &"test_power_band"
			member.equipped_consumable_key = &"test_heal_berry"
		party.members.append(member)
	return party


## Create an InventoryState with the given bits and some test items.
static func create_test_inventory(bits: int = 10000) -> InventoryState:
	var inv := InventoryState.new()
	inv.bits = bits
	inv.items[&"test_potion"] = 10
	inv.items[&"test_super_potion"] = 5
	inv.items[&"test_energy_drink"] = 5
	return inv


## Create a StorageState with Digimon placed in the first boxes.
static func create_test_storage(
	box_count: int = 1, per_box: int = 5,
) -> StorageState:
	var storage := StorageState.new()
	var keys: Array[StringName] = [
		&"test_agumon", &"test_gabumon", &"test_patamon",
		&"test_tank", &"test_sweeper", &"test_wall",
	]
	for box_i: int in mini(box_count, storage.get_box_count()):
		for slot_i: int in per_box:
			var key: StringName = keys[slot_i % keys.size()]
			storage.set_digimon(
				box_i, slot_i,
				TestBattleFactory.make_digimon_state(key, 10),
			)
	return storage


## Create a test ShopData with standard test items.
static func create_test_shop() -> ShopData:
	var shop := ShopData.new()
	shop.key = &"test_shop"
	shop.name = "Test Shop"
	shop.stock = [
		{"item_key": &"test_potion", "price": 0, "quantity": -1},
		{"item_key": &"test_super_potion", "price": 0, "quantity": -1},
		{"item_key": &"test_energy_drink", "price": 0, "quantity": -1},
	]
	shop.buy_multiplier = 1.0
	shop.sell_multiplier = 0.5
	return shop


## Inject screen test data into Atlas. Delegates to TestBattleFactory.
static func inject_screen_test_data() -> void:
	TestBattleFactory.inject_all_test_data()


## Clear screen test data from Atlas. Delegates to TestBattleFactory.
static func clear_screen_test_data() -> void:
	TestBattleFactory.clear_test_data()
