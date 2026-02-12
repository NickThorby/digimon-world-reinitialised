extends GutTest
## Tests for Start Battle Screen logic (no UI, tests state mutations directly).
## Verifies player side construction, inventory bridging, and post-battle writeback.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	Game.state = TestScreenFactory.create_test_game_state()
	Game.builder_context = {}
	Game.picker_context = {}
	Game.picker_result = null
	Game.screen_context = {}
	Game.battle_config = null


func after_each() -> void:
	Game.state = null
	Game.builder_context = {}
	Game.picker_context = {}
	Game.picker_result = null
	Game.screen_context = {}
	Game.battle_config = null


# --- BagState.from_inventory ---


func test_bag_from_inventory_copies_all_items() -> void:
	var inv := InventoryState.new()
	inv.items[&"test_potion"] = 5
	inv.items[&"test_super_potion"] = 3

	var bag: BagState = BagState.from_inventory(inv)

	assert_eq(bag.get_quantity(&"test_potion"), 5,
		"Bag should have 5 potions from inventory")
	assert_eq(bag.get_quantity(&"test_super_potion"), 3,
		"Bag should have 3 super potions from inventory")


func test_bag_from_inventory_skips_zero_quantity() -> void:
	var inv := InventoryState.new()
	inv.items[&"test_potion"] = 0
	inv.items[&"test_super_potion"] = 2

	var bag: BagState = BagState.from_inventory(inv)

	assert_false(bag.has_item(&"test_potion"),
		"Bag should skip items with zero quantity")
	assert_eq(bag.get_quantity(&"test_super_potion"), 2,
		"Bag should have items with positive quantity")


func test_bag_from_inventory_empty_inventory() -> void:
	var inv := InventoryState.new()
	var bag: BagState = BagState.from_inventory(inv)

	assert_true(bag.is_empty(), "Bag from empty inventory should be empty")


func test_bag_get_items_dict() -> void:
	var bag := BagState.new()
	bag.add_item(&"test_potion", 5)
	bag.add_item(&"test_super_potion", 2)

	var items: Dictionary = bag.get_items_dict()

	assert_eq(items.size(), 2, "Should return 2 items")
	assert_eq(int(items[&"test_potion"]), 5, "Potion should be 5")
	assert_eq(int(items[&"test_super_potion"]), 2, "Super potion should be 2")


# --- BagState.sync_to_inventory ---


func test_sync_to_inventory_deducts_consumed_items() -> void:
	var inv := InventoryState.new()
	inv.items[&"test_potion"] = 10
	inv.items[&"test_super_potion"] = 5

	var snapshot: Dictionary = inv.items.duplicate()

	var bag := BagState.new()
	bag.add_item(&"test_potion", 7)  # Consumed 3
	bag.add_item(&"test_super_potion", 5)  # Consumed 0

	BagState.sync_to_inventory(bag, inv, snapshot)

	assert_eq(int(inv.items.get(&"test_potion", 0)), 7,
		"Inventory should have 7 potions after 3 consumed")
	assert_eq(int(inv.items.get(&"test_super_potion", 0)), 5,
		"Inventory should remain at 5 super potions (none consumed)")


func test_sync_to_inventory_removes_fully_consumed() -> void:
	var inv := InventoryState.new()
	inv.items[&"test_potion"] = 3

	var snapshot: Dictionary = inv.items.duplicate()

	var bag := BagState.new()
	# All 3 potions consumed (not in bag)

	BagState.sync_to_inventory(bag, inv, snapshot)

	assert_false(inv.items.has(&"test_potion"),
		"Fully consumed items should be erased from inventory")


func test_sync_to_inventory_no_changes_when_nothing_consumed() -> void:
	var inv := InventoryState.new()
	inv.items[&"test_potion"] = 10

	var snapshot: Dictionary = inv.items.duplicate()

	var bag := BagState.new()
	bag.add_item(&"test_potion", 10)

	BagState.sync_to_inventory(bag, inv, snapshot)

	assert_eq(int(inv.items.get(&"test_potion", 0)), 10,
		"Inventory should be unchanged when nothing consumed")


# --- Player side construction ---


func test_player_side_config_has_player_controller() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	# Build player side manually (mirroring what start_battle_screen does)
	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": player_party,
		"is_wild": false,
		"is_owned": true,
		"bag": BagState.from_inventory(Game.state.inventory),
	}

	assert_eq(
		int(config.side_configs[0]["controller"]),
		BattleConfig.ControllerType.PLAYER,
		"Player side should have PLAYER controller"
	)
	assert_false(
		config.side_configs[0]["is_wild"],
		"Player side should not be wild"
	)
	assert_true(
		config.side_configs[0]["is_owned"],
		"Player side should be owned"
	)


func test_player_side_uses_same_references() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	config.side_configs[0]["party"] = player_party

	var party: Array = config.side_configs[0]["party"]
	for i: int in Game.state.party.members.size():
		assert_true(
			party[i] == Game.state.party.members[i],
			"Side 0 party[%d] should be same reference as Game.state.party" % i
		)


func test_player_side_bag_from_inventory() -> void:
	Game.state.inventory.items[&"test_potion"] = 10
	Game.state.inventory.items[&"test_super_potion"] = 5

	var bag: BagState = BagState.from_inventory(Game.state.inventory)

	assert_eq(bag.get_quantity(&"test_potion"), 10,
		"Player bag should have 10 potions from inventory")
	assert_eq(bag.get_quantity(&"test_super_potion"), 5,
		"Player bag should have 5 super potions from inventory")


# --- Post-battle inventory writeback ---


func test_post_battle_inventory_writeback() -> void:
	Game.state.inventory.items[&"test_potion"] = 10
	Game.state.inventory.items[&"test_super_potion"] = 5

	# Snapshot before battle
	var snapshot: Dictionary = Game.state.inventory.items.duplicate()

	# Create bag and simulate consumption
	var bag: BagState = BagState.from_inventory(Game.state.inventory)
	bag.remove_item(&"test_potion", 3)  # Used 3 potions
	bag.remove_item(&"test_super_potion", 5)  # Used all super potions

	# Sync back
	BagState.sync_to_inventory(bag, Game.state.inventory, snapshot)

	assert_eq(int(Game.state.inventory.items.get(&"test_potion", 0)), 7,
		"Inventory should have 7 potions after using 3")
	assert_false(Game.state.inventory.items.has(&"test_super_potion"),
		"Fully consumed super potions should be removed from inventory")


# --- Format change behaviour ---


func test_format_change_preserves_player_side() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	# Build player side
	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": player_party,
		"is_wild": false,
		"is_owned": true,
	}

	# Change format
	config.apply_preset(BattleConfig.FormatPreset.DOUBLES_2V2)

	# Rebuild player side (as the screen would)
	var new_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		new_party.append(member)
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": new_party,
		"is_wild": false,
		"is_owned": true,
	}

	assert_eq(config.side_count, 2, "Doubles 2v2 should have 2 sides")
	assert_eq(config.slots_per_side, 2, "Doubles 2v2 should have 2 slots")
	assert_eq(
		int(config.side_configs[0]["controller"]),
		BattleConfig.ControllerType.PLAYER,
		"Side 0 should remain PLAYER after format change"
	)


# --- Opponent side management ---


func test_add_digimon_to_opponent_side() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	var opponent_state: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50
	)
	var party: Array = config.side_configs[1].get("party", [])
	party.append(opponent_state)
	config.side_configs[1]["party"] = party

	assert_eq(
		(config.side_configs[1]["party"] as Array).size(), 1,
		"Opponent side should have 1 Digimon after adding"
	)


func test_remove_digimon_from_opponent_side() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	var state1: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50
	)
	var state2: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_gabumon", 50
	)
	config.side_configs[1]["party"] = [state1, state2]

	var party: Array = config.side_configs[1]["party"]
	party.remove_at(0)

	assert_eq(party.size(), 1, "Should have 1 Digimon after removing one")
	assert_eq(
		(party[0] as DigimonState).key, &"test_gabumon",
		"Remaining Digimon should be gabumon"
	)


# --- Validation ---


func test_validation_fails_with_empty_player_party() -> void:
	Game.state.party.members.clear()

	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	# Player side with empty party
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": [] as Array[DigimonState],
		"is_wild": false,
		"is_owned": true,
	}

	# Opponent side with valid party
	config.side_configs[1]["party"] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	]

	var errors: Array[String] = config.validate()
	assert_gt(errors.size(), 0, "Validation should fail with empty player party")


func test_validation_passes_with_valid_config() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": [TestBattleFactory.make_digimon_state(&"test_agumon", 50)],
		"is_wild": false,
		"is_owned": true,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": [TestBattleFactory.make_digimon_state(&"test_gabumon", 50)],
		"is_wild": false,
		"is_owned": false,
	}

	var errors: Array[String] = config.validate()
	assert_eq(errors.size(), 0, "Valid config should have no validation errors")


# --- Context reading ---


func test_context_reads_mode() -> void:
	Game.screen_context = {
		"mode": Registry.GameMode.TEST,
		"return_scene": "res://scenes/screens/mode_screen.tscn",
	}
	var mode: Registry.GameMode = Game.screen_context.get(
		"mode", Registry.GameMode.TEST
	)
	assert_eq(
		int(mode), int(Registry.GameMode.TEST),
		"Should read TEST mode from context"
	)


func test_context_reads_return_scene() -> void:
	var expected: String = "res://scenes/screens/mode_screen.tscn"
	Game.screen_context = {
		"mode": Registry.GameMode.TEST,
		"return_scene": expected,
	}
	var return_scene: String = Game.screen_context.get("return_scene", "")
	assert_eq(return_scene, expected, "Should read return_scene from context")


# --- Builder context round-trip ---


func test_builder_context_stores_return_scene() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	var return_path: String = "res://scenes/screens/start_battle_screen.tscn"
	Game.builder_context = {
		"config": config,
		"current_opponent_side": 1,
		"side_presets": {},
		"return_scene": return_path,
		"pre_battle_inventory": {},
	}

	assert_eq(
		Game.builder_context.get("return_scene", ""),
		return_path,
		"Builder context should store return_scene"
	)


func test_builder_context_stores_pre_battle_inventory() -> void:
	Game.state.inventory.items[&"test_potion"] = 10
	var snapshot: Dictionary = Game.state.inventory.items.duplicate()

	Game.builder_context = {
		"pre_battle_inventory": snapshot,
	}

	var restored: Dictionary = Game.builder_context["pre_battle_inventory"]
	assert_eq(int(restored.get(&"test_potion", 0)), 10,
		"Pre-battle inventory snapshot should be stored in builder context")


# --- Energy restore after battle ---


func test_restore_party_energy_for_owned_side() -> void:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	var state: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50
	)
	state.current_energy = 0  # Drained
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": [state],
		"is_wild": false,
		"is_owned": true,
	}

	# Simulate energy restore (mirroring _restore_party_energy)
	for digimon: Variant in config.side_configs[0].get("party", []):
		if digimon is not DigimonState:
			continue
		var ds: DigimonState = digimon as DigimonState
		var data: DigimonData = Atlas.digimon.get(ds.key) as DigimonData
		if data == null:
			continue
		var stats: Dictionary = StatCalculator.calculate_all_stats(data, ds)
		var personality: PersonalityData = Atlas.personalities.get(
			ds.personality_key,
		) as PersonalityData
		var max_energy: int = StatCalculator.apply_personality(
			stats.get(&"energy", 1), &"energy", personality,
		)
		ds.current_energy = max_energy

	assert_gt(state.current_energy, 0,
		"Owned side's energy should be restored after battle")


# --- Picker context round-trip ---


func test_picker_context_stores_return_scene() -> void:
	var return_path: String = "res://scenes/screens/start_battle_screen.tscn"
	Game.picker_context = {
		"side": 1,
		"editing_index": -1,
		"return_scene": return_path,
	}

	var restored: String = Game.picker_context.get("return_scene", "")
	assert_eq(restored, return_path,
		"Picker context should store return_scene for Start Battle Screen")
