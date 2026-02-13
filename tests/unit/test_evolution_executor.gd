extends GutTest
## Unit tests for EvolutionExecutor.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Helpers ---


func _make_inventory() -> InventoryState:
	return InventoryState.new()


func _make_party(members: Array[DigimonState]) -> PartyState:
	var party := PartyState.new()
	party.members = members
	return party


func _make_storage() -> StorageState:
	return StorageState.new()


func _get_link(key: StringName) -> EvolutionLinkData:
	return Atlas.evolutions.get(key) as EvolutionLinkData


# --- Standard evolution ---


func test_standard_evo_changes_key() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()

	var result: Dictionary = EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_true(result["success"] as bool, "Standard evolution should succeed")
	assert_eq(digimon.key, &"test_tank", "Key should change to evolution target")


func test_standard_evo_scales_hp() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var old_hp: int = digimon.current_hp
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	# test_tank has base_hp=120 vs test_agumon base_hp=80, so HP should change
	assert_ne(digimon.current_hp, old_hp, "HP should be scaled to new form")
	assert_true(digimon.current_hp > 0, "HP should remain positive after scaling")


func test_standard_evo_learns_innate_techniques() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	# test_tank has innate techniques test_tackle and test_earthquake
	var tank_data: DigimonData = Atlas.digimon.get(&"test_tank") as DigimonData
	var innate_keys: Array[StringName] = tank_data.get_innate_technique_keys()
	for tech_key: StringName in innate_keys:
		assert_true(
			digimon.known_technique_keys.has(tech_key),
			"Should learn innate technique: %s" % tech_key,
		)


func test_standard_evo_appends_history() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(digimon.evolution_history.size(), 1, "Should have 1 history entry")
	var entry: Dictionary = digimon.evolution_history[0]
	assert_eq(
		StringName(entry["from_key"]), &"test_agumon",
		"History from_key should be original species",
	)
	assert_eq(
		StringName(entry["to_key"]), &"test_tank",
		"History to_key should be target species",
	)


func test_standard_evo_no_item_held() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(
		digimon.evolution_item_key, &"",
		"Standard evolution should not set evolution_item_key",
	)


# --- Armor evolution ---


func test_armor_evo_removes_item_from_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_armor")
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_false(
		inv.items.has(&"test_digimental_courage"),
		"Digimental should be consumed from inventory",
	)


func test_armor_evo_sets_evolution_item_key() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_armor")
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(
		digimon.evolution_item_key, &"test_digimental_courage",
		"Armor evo should set evolution_item_key to the digimental",
	)


func test_armor_evo_history_includes_item() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_armor")
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(digimon.evolution_history.size(), 1, "Should have 1 history entry")
	var entry: Dictionary = digimon.evolution_history[0]
	assert_eq(
		StringName(entry["evolution_item_key"]), &"test_digimental_courage",
		"History should record the digimental key",
	)


# --- Spirit evolution ---


func test_spirit_evo_consumes_spirit_item() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_patamon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_patamon_speedster")
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_spirit_item"] = 1

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_false(
		inv.items.has(&"test_spirit_item"),
		"Spirit item should be consumed from inventory",
	)
	assert_eq(
		digimon.evolution_item_key, &"test_spirit_item",
		"Spirit evo should set evolution_item_key to the spirit item",
	)
	assert_eq(digimon.key, &"test_speedster", "Key should change to spirit target")


func test_spirit_evo_history_records_item() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_patamon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_patamon_speedster")
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_spirit_item"] = 1

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	var entry: Dictionary = digimon.evolution_history[0]
	assert_eq(
		StringName(entry["evolution_item_key"]), &"test_spirit_item",
		"Spirit evo history should record spirit item key",
	)


# --- Slide evolution ---


func test_slide_evo_replaces_last_history_entry() -> void:
	# First: armor evolve agumon → speedster (holding digimental_courage)
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	inv.items[&"test_digimental_friendship"] = 1
	var armor_link: EvolutionLinkData = _get_link(&"test_evo_armor")
	EvolutionExecutor.execute_evolution(digimon, armor_link, inv)
	assert_eq(digimon.evolution_history.size(), 1, "Should have 1 entry after armor evo")

	# Then: slide speedster → wall (requires digimental_friendship)
	var slide_link: EvolutionLinkData = _get_link(&"test_evo_slide")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, slide_link, inv)

	assert_eq(
		digimon.evolution_history.size(), 1,
		"Slide should replace last history entry, not append",
	)
	assert_eq(digimon.key, &"test_wall", "Key should change to slide target")


func test_slide_evo_returns_old_item_takes_new_item() -> void:
	# Armor evolve: consumes digimental_courage
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	inv.items[&"test_digimental_friendship"] = 1
	var armor_link: EvolutionLinkData = _get_link(&"test_evo_armor")
	EvolutionExecutor.execute_evolution(digimon, armor_link, inv)
	assert_eq(
		digimon.evolution_item_key, &"test_digimental_courage",
		"After armor evo, should hold courage digimental",
	)

	# Slide: returns courage, takes friendship
	var slide_link: EvolutionLinkData = _get_link(&"test_evo_slide")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, slide_link, inv)

	assert_true(
		inv.items.has(&"test_digimental_courage"),
		"Old digimental should be returned to inventory",
	)
	assert_eq(
		inv.items.get(&"test_digimental_courage", 0), 1,
		"Old digimental should have quantity 1",
	)
	assert_false(
		inv.items.has(&"test_digimental_friendship"),
		"New digimental should be consumed from inventory",
	)
	assert_eq(
		digimon.evolution_item_key, &"test_digimental_friendship",
		"Should now hold the friendship digimental",
	)


func test_slide_evo_preserves_from_key() -> void:
	# Armor: agumon → speedster
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	inv.items[&"test_digimental_friendship"] = 1
	var armor_link: EvolutionLinkData = _get_link(&"test_evo_armor")
	EvolutionExecutor.execute_evolution(digimon, armor_link, inv)

	# Slide: speedster → wall
	var slide_link: EvolutionLinkData = _get_link(&"test_evo_slide")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, slide_link, inv)

	var entry: Dictionary = digimon.evolution_history[0]
	assert_eq(
		StringName(entry["from_key"]), &"test_agumon",
		"Slide should preserve from_key from previous entry (original tier)",
	)


# --- Mode change with item ---


func test_mode_change_with_item_replaces_last_history() -> void:
	# Standard: agumon → tank
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_mode_item"] = 1
	var std_link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	EvolutionExecutor.execute_evolution(digimon, std_link, inv)
	assert_eq(digimon.evolution_history.size(), 1, "Should have 1 entry after standard evo")

	# Mode change: tank → sweeper (requires mode item)
	var mc_link: EvolutionLinkData = _get_link(&"test_evo_mode_change")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, mc_link, inv)

	assert_eq(
		digimon.evolution_history.size(), 1,
		"Mode change should replace last history entry",
	)
	assert_eq(digimon.key, &"test_sweeper", "Key should change to mode change target")


func test_mode_change_with_item_swaps_item() -> void:
	# Standard: agumon → tank (no item held)
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_mode_item"] = 1
	var std_link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	EvolutionExecutor.execute_evolution(digimon, std_link, inv)
	assert_eq(digimon.evolution_item_key, &"", "Tank should hold no item after standard evo")

	# Mode change: tank → sweeper (requires test_mode_item)
	var mc_link: EvolutionLinkData = _get_link(&"test_evo_mode_change")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, mc_link, inv)

	assert_false(
		inv.items.has(&"test_mode_item"),
		"Mode item should be consumed from inventory",
	)
	assert_eq(
		digimon.evolution_item_key, &"test_mode_item",
		"Should now hold the mode item",
	)


# --- Free mode change ---


func test_free_mode_change_replaces_last_history() -> void:
	# First get to sweeper: agumon → tank → sweeper via mode change
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_mode_item"] = 1
	var std_link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	EvolutionExecutor.execute_evolution(digimon, std_link, inv)
	var mc_link: EvolutionLinkData = _get_link(&"test_evo_mode_change")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, mc_link, inv)
	assert_eq(digimon.key, &"test_sweeper", "Should be sweeper before free mode change")

	# Free mode change: sweeper → speedster (no item required)
	var free_mc_link: EvolutionLinkData = _get_link(&"test_evo_free_mode_change")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, free_mc_link, inv)

	assert_eq(
		digimon.evolution_history.size(), 1,
		"Free mode change should replace history, not append",
	)
	assert_eq(digimon.key, &"test_speedster", "Key should change to speedster")


func test_free_mode_change_returns_old_item_no_new_item() -> void:
	# Get to sweeper holding test_mode_item
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_mode_item"] = 1
	var std_link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	EvolutionExecutor.execute_evolution(digimon, std_link, inv)
	var mc_link: EvolutionLinkData = _get_link(&"test_evo_mode_change")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, mc_link, inv)
	assert_eq(
		digimon.evolution_item_key, &"test_mode_item",
		"Should hold mode item before free mode change",
	)

	# Free mode change: sweeper → speedster (no item)
	var free_mc_link: EvolutionLinkData = _get_link(&"test_evo_free_mode_change")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, free_mc_link, inv)

	assert_true(
		inv.items.has(&"test_mode_item"),
		"Old mode item should be returned to inventory",
	)
	assert_eq(
		digimon.evolution_item_key, &"",
		"No new item should be held after free mode change",
	)


# --- X-Antibody evolution ---


func test_x_antibody_evo_appends_history() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	digimon.x_antibody = 1
	var link: EvolutionLinkData = _get_link(&"test_evo_x_antibody")
	var inv: InventoryState = _make_inventory()

	var result: Dictionary = EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_true(result["success"] as bool, "X-Antibody evolution should succeed")
	assert_eq(digimon.key, &"test_wall", "Key should change to x-antibody target")
	assert_eq(
		digimon.evolution_history.size(), 1,
		"Should append 1 history entry",
	)


func test_x_antibody_evo_does_not_consume_inventory_item() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	digimon.x_antibody = 1
	var link: EvolutionLinkData = _get_link(&"test_evo_x_antibody")
	var inv: InventoryState = _make_inventory()
	inv.items[&"some_item"] = 3

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(
		inv.items.get(&"some_item", 0), 3,
		"X-Antibody evo should not consume any inventory items",
	)
	assert_eq(
		digimon.evolution_item_key, &"",
		"X-Antibody evo should not set an evolution item",
	)


# --- Jogress evolution ---


func test_jogress_evo_succeeds_and_changes_key() -> void:
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_jogress")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	var selected: Dictionary = {
		&"test_gabumon": {"digimon": partner, "source": "party", "party_index": 1},
	}
	var result: Dictionary = EvolutionExecutor.execute_jogress(
		main, link, selected, inv, party, storage,
	)
	assert_true(result["success"] as bool, "Jogress evolution should succeed")
	assert_eq(main.key, &"test_wall", "Key should change to jogress target")


func test_jogress_evo_stores_partner_snapshots() -> void:
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_jogress")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	var selected: Dictionary = {
		&"test_gabumon": {"digimon": partner, "source": "party", "party_index": 1},
	}
	EvolutionExecutor.execute_jogress(main, link, selected, inv, party, storage)

	assert_eq(main.evolution_history.size(), 1, "Should have 1 history entry")
	var entry: Dictionary = main.evolution_history[0]
	assert_true(
		entry.has("jogress_partners"),
		"History entry should contain jogress_partners",
	)
	var partners: Array = entry["jogress_partners"]
	assert_eq(partners.size(), 1, "Should have 1 partner snapshot")
	var snapshot: Dictionary = partners[0] as Dictionary
	assert_eq(
		StringName(snapshot.get("key", "")), &"test_gabumon",
		"Partner snapshot should have correct key",
	)


func test_jogress_evo_removes_partner_from_party() -> void:
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_jogress")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	var selected: Dictionary = {
		&"test_gabumon": {"digimon": partner, "source": "party", "party_index": 1},
	}
	EvolutionExecutor.execute_jogress(main, link, selected, inv, party, storage)

	assert_eq(
		party.members.size(), 1,
		"Partner should be removed from party after jogress",
	)
	assert_eq(
		party.members[0].key, &"test_wall",
		"Remaining party member should be the evolved main Digimon",
	)


func test_jogress_evo_appends_history() -> void:
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_jogress")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	var selected: Dictionary = {
		&"test_gabumon": {"digimon": partner, "source": "party", "party_index": 1},
	}
	EvolutionExecutor.execute_jogress(main, link, selected, inv, party, storage)

	var entry: Dictionary = main.evolution_history[0]
	assert_eq(
		StringName(entry["from_key"]), &"test_agumon",
		"Jogress history from_key should be the main Digimon's original key",
	)
	assert_eq(
		StringName(entry["to_key"]), &"test_wall",
		"Jogress history to_key should be the jogress target",
	)
	assert_eq(
		entry["evolution_type"] as int,
		Registry.EvolutionType.JOGRESS as int,
		"History should record JOGRESS evolution type",
	)


# --- De-digivolution ---


func test_de_digivolution_pops_history() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(digimon.key, &"test_tank", "Should be tank after evolution")
	assert_eq(digimon.evolution_history.size(), 1, "Should have 1 history entry")

	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-digivolution should succeed")
	assert_eq(
		digimon.evolution_history.size(), 0,
		"History should be empty after de-digivolution",
	)


func test_de_digivolution_reverts_key() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	EvolutionExecutor.execute_de_digivolution(digimon, inv, party, storage)
	assert_eq(
		digimon.key, &"test_agumon",
		"De-digivolution should revert key to from_key",
	)


func test_de_digivolution_returns_item_to_inventory() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_armor")
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_false(
		inv.items.has(&"test_digimental_courage"),
		"Item should be consumed after armor evo",
	)

	EvolutionExecutor.execute_de_digivolution(digimon, inv, party, storage)
	assert_true(
		inv.items.has(&"test_digimental_courage"),
		"Item should be returned to inventory after de-digivolution",
	)
	assert_eq(
		inv.items.get(&"test_digimental_courage", 0), 1,
		"Returned item should have quantity 1",
	)


func test_de_digivolution_scales_hp() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	var original_hp: int = digimon.current_hp
	EvolutionExecutor.execute_evolution(digimon, link, inv)
	var evolved_hp: int = digimon.current_hp
	assert_ne(evolved_hp, original_hp, "HP should change after evo")

	EvolutionExecutor.execute_de_digivolution(digimon, inv, party, storage)
	# HP should be scaled back (may not be exactly original due to rounding)
	assert_true(digimon.current_hp > 0, "HP should remain positive after de-digivolution")


func test_de_digivolution_restores_jogress_partners() -> void:
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_jogress")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	var selected: Dictionary = {
		&"test_gabumon": {"digimon": partner, "source": "party", "party_index": 1},
	}
	EvolutionExecutor.execute_jogress(main, link, selected, inv, party, storage)
	assert_eq(party.members.size(), 1, "Party should have 1 member after jogress")

	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		main, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-digivolution should succeed")
	var restored: Array = result["restored_partners"]
	assert_eq(restored.size(), 1, "Should restore 1 partner")
	var restored_entry: Dictionary = restored[0] as Dictionary
	var restored_partner: DigimonState = restored_entry["digimon"] as DigimonState
	assert_eq(
		restored_partner.key, &"test_gabumon",
		"Restored partner should be the original species",
	)
	assert_eq(
		restored_entry["destination"], "party",
		"Partner should be restored to party",
	)
	assert_eq(
		party.members.size(), 2,
		"Restored partner should be added back to party",
	)


func test_de_digivolution_empty_history_returns_failure() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_false(
		result["success"] as bool,
		"De-digivolution should fail on empty history",
	)
	assert_ne(
		result["error"] as String, "",
		"Should return a descriptive error message",
	)


func test_de_digivolution_without_item() -> void:
	# Standard evo (no item involved)
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	EvolutionExecutor.execute_evolution(digimon, link, inv)
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-digivolution without item should succeed")
	assert_eq(digimon.key, &"test_agumon", "Should revert to original key")
	assert_eq(
		digimon.evolution_item_key, &"",
		"evolution_item_key should remain empty",
	)
	assert_true(inv.items.is_empty(), "Inventory should remain empty")
