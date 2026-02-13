extends GutTest
## Integration tests for full evolution → de-evolution round trips.
## Verifies that evolving and then de-evolving restores the Digimon
## to its original state with items returned and partners restored.

const DEFAULT_SEED := 99


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


# --- Standard round trip ---


func test_standard_round_trip() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	# Evolve: agumon → tank
	var link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(digimon.key, &"test_tank", "Should be tank after evolution")

	# De-evolve back
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-evolution should succeed")
	assert_eq(digimon.key, &"test_agumon", "Should revert to agumon")
	assert_eq(
		digimon.evolution_history.size(), 0,
		"History should be empty after full round trip",
	)
	assert_true(digimon.current_hp > 0, "HP should remain positive")


# --- Armor round trip ---


func test_armor_round_trip_returns_digimental() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	# Evolve: agumon → speedster (armor, consumes digimental)
	var link: EvolutionLinkData = _get_link(&"test_evo_armor")
	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(digimon.key, &"test_speedster", "Should be speedster after armor evo")
	assert_false(
		inv.items.has(&"test_digimental_courage"),
		"Digimental should be consumed",
	)

	# De-evolve back
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-evolution should succeed")
	assert_eq(digimon.key, &"test_agumon", "Should revert to agumon")
	assert_true(
		inv.items.has(&"test_digimental_courage"),
		"Digimental should be returned to inventory",
	)
	assert_eq(
		digimon.evolution_item_key, &"",
		"evolution_item_key should be cleared",
	)


# --- Spirit round trip ---


func test_spirit_round_trip_returns_spirit() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_patamon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_spirit_item"] = 1
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	# Evolve: patamon → speedster (spirit, consumes spirit item)
	var link: EvolutionLinkData = _get_link(&"test_evo_patamon_speedster")
	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(digimon.key, &"test_speedster", "Should be speedster after spirit evo")

	# De-evolve back
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-evolution should succeed")
	assert_eq(digimon.key, &"test_patamon", "Should revert to patamon")
	assert_true(
		inv.items.has(&"test_spirit_item"),
		"Spirit item should be returned to inventory",
	)


# --- Slide then de-evo ---


func test_slide_then_de_evo_reverts_to_original() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	inv.items[&"test_digimental_friendship"] = 1
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	# Armor: agumon → speedster (consumes digimental_courage)
	var armor_link: EvolutionLinkData = _get_link(&"test_evo_armor")
	EvolutionExecutor.execute_evolution(digimon, armor_link, inv)
	assert_eq(digimon.key, &"test_speedster", "Should be speedster after armor evo")

	# Slide: speedster → wall (consumes digimental_friendship, returns digimental_courage)
	var slide_link: EvolutionLinkData = _get_link(&"test_evo_slide")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, slide_link, inv)
	assert_eq(digimon.key, &"test_wall", "Should be wall after slide")

	# De-evolve — should revert to agumon (not speedster), returning friendship digimental
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-evolution should succeed")
	assert_eq(
		digimon.key, &"test_agumon",
		"Should revert to agumon (original), not speedster",
	)
	assert_true(
		inv.items.has(&"test_digimental_friendship"),
		"Friendship digimental should be returned",
	)
	assert_true(
		inv.items.has(&"test_digimental_courage"),
		"Courage digimental should still be in inventory (returned by slide)",
	)


# --- Mode change round trip ---


func test_mode_change_round_trip_returns_mode_item() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_mode_item"] = 1
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	# Standard: agumon → tank
	var std_link: EvolutionLinkData = _get_link(&"test_evo_agumon_tank")
	EvolutionExecutor.execute_evolution(digimon, std_link, inv)
	assert_eq(digimon.key, &"test_tank", "Should be tank after standard evo")

	# Mode change: tank → sweeper (consumes mode item)
	var mc_link: EvolutionLinkData = _get_link(&"test_evo_mode_change")
	EvolutionExecutor.execute_slide_or_mode_change(digimon, mc_link, inv)
	assert_eq(digimon.key, &"test_sweeper", "Should be sweeper after mode change")

	# De-evolve — should revert to agumon (through the whole chain)
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-evolution should succeed")
	assert_eq(
		digimon.key, &"test_agumon",
		"Should revert to agumon (original before standard evo)",
	)
	assert_true(
		inv.items.has(&"test_mode_item"),
		"Mode item should be returned to inventory",
	)


# --- Jogress round trip ---


func test_jogress_round_trip_restores_partner() -> void:
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var link: EvolutionLinkData = _get_link(&"test_evo_jogress")
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	# Jogress: agumon + gabumon → wall
	var selected: Dictionary = {
		&"test_gabumon": {"digimon": partner, "source": "party", "party_index": 1},
	}
	EvolutionExecutor.execute_jogress(main, link, selected, inv, party, storage)
	assert_eq(main.key, &"test_wall", "Should be wall after jogress")
	assert_eq(party.members.size(), 1, "Partner should be absorbed")

	# De-evolve
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		main, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-evolution should succeed")
	assert_eq(main.key, &"test_agumon", "Should revert to agumon")
	assert_eq(
		party.members.size(), 2,
		"Partner should be restored to party",
	)

	# Verify the restored partner
	var restored: DigimonState = party.members[1]
	assert_eq(
		restored.key, &"test_gabumon",
		"Restored partner should be gabumon",
	)


# --- X-Antibody round trip ---


func test_x_antibody_round_trip_preserves_x_antibody() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	digimon.x_antibody = 1
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	# X-Antibody: agumon → wall
	var link: EvolutionLinkData = _get_link(&"test_evo_x_antibody")
	EvolutionExecutor.execute_evolution(digimon, link, inv)
	assert_eq(digimon.key, &"test_wall", "Should be wall after x-antibody evo")

	# De-evolve
	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_true(result["success"] as bool, "De-evolution should succeed")
	assert_eq(digimon.key, &"test_agumon", "Should revert to agumon")
	assert_eq(
		digimon.x_antibody, 1,
		"X-Antibody value should be preserved through round trip",
	)


# --- Empty history fails ---


func test_de_evo_with_empty_history_fails() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()
	var party: PartyState = _make_party([digimon])
	var storage: StorageState = _make_storage()

	var result: Dictionary = EvolutionExecutor.execute_de_digivolution(
		digimon, inv, party, storage,
	)
	assert_false(result["success"] as bool, "De-evolution should fail with empty history")
	assert_eq(
		digimon.key, &"test_agumon",
		"Key should remain unchanged on failure",
	)
