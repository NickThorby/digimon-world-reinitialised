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


## Create a test ShopData with priced items for buy/sell testing.
static func create_test_priced_shop() -> ShopData:
	var shop := ShopData.new()
	shop.key = &"test_priced_shop"
	shop.name = "Test Priced Shop"
	shop.stock = [
		{"item_key": &"test_potion", "price": 100, "quantity": -1},
		{"item_key": &"test_super_potion", "price": 300, "quantity": -1},
		{"item_key": &"test_energy_drink", "price": 200, "quantity": 5},
	]
	shop.buy_multiplier = 1.0
	shop.sell_multiplier = 0.5
	return shop


## Create a test EncounterTableData with the given number of entries.
static func create_test_encounter_table(entry_count: int = 5) -> EncounterTableData:
	var table := EncounterTableData.new()
	table.key = &"test_encounter_table"
	table.name = "Test Encounter Table"
	table.default_min_level = 5
	table.default_max_level = 15
	table.format_weights = {
		BattleConfig.FormatPreset.SINGLES_1V1: 85,
		BattleConfig.FormatPreset.DOUBLES_2V2: 15,
	}

	var keys: Array[StringName] = [
		&"test_agumon", &"test_gabumon", &"test_patamon",
		&"test_tank", &"test_speedster",
	]
	var rarities: Array[int] = [
		Registry.Rarity.COMMON, Registry.Rarity.COMMON,
		Registry.Rarity.UNCOMMON, Registry.Rarity.RARE,
		Registry.Rarity.VERY_RARE,
	]
	for i: int in mini(entry_count, keys.size()):
		table.entries.append({
			"digimon_key": keys[i],
			"rarity": rarities[i],
			"min_level": -1,
			"max_level": -1,
		})
	return table


## Create a test ZoneData with encounter entries.
static func create_test_zone_data() -> ZoneData:
	var zone := ZoneData.new()
	zone.key = &"test_region/test_sector/test_zone"
	zone.name = "Test Zone"
	zone.region_name = "Test Region"
	zone.sector_name = "Test Sector"
	zone.default_min_level = 5
	zone.default_max_level = 15
	zone.format_weights = {
		BattleConfig.FormatPreset.SINGLES_1V1: 100,
	}
	zone.encounter_entries = [
		{
			"digimon_key": &"test_agumon",
			"rarity": Registry.Rarity.COMMON,
			"min_level": -1,
			"max_level": -1,
		},
		{
			"digimon_key": &"test_gabumon",
			"rarity": Registry.Rarity.UNCOMMON,
			"min_level": -1,
			"max_level": -1,
		},
		{
			"digimon_key": &"test_patamon",
			"rarity": Registry.Rarity.RARE,
			"min_level": -1,
			"max_level": -1,
		},
	]
	return zone


## Inject screen test data into Atlas. Delegates to TestBattleFactory.
static func inject_screen_test_data() -> void:
	TestBattleFactory.inject_all_test_data()


## Clear screen test data from Atlas. Delegates to TestBattleFactory.
static func clear_screen_test_data() -> void:
	TestBattleFactory.clear_test_data()
