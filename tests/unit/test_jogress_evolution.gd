extends GutTest
## Unit tests for Jogress (DNA) evolution support.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Helpers ---


func _make_jogress_link(
	partner_keys: Array[StringName] = [&"test_gabumon"],
	requirements: Array[Dictionary] = [{"type": "level", "level": 20}],
) -> EvolutionLinkData:
	var link := EvolutionLinkData.new()
	link.key = &"test_evo_jogress_custom"
	link.from_key = &"test_agumon"
	link.to_key = &"test_wall"
	link.evolution_type = Registry.EvolutionType.JOGRESS
	link.requirements = requirements
	link.jogress_partner_keys = partner_keys
	return link


func _make_party(members: Array[DigimonState]) -> PartyState:
	var party := PartyState.new()
	party.members = members
	return party


func _make_storage() -> StorageState:
	return StorageState.new()


func _make_inventory() -> InventoryState:
	return InventoryState.new()


# --- check_jogress_partners ---


func test_check_jogress_partners_met() -> void:
	var link: EvolutionLinkData = _make_jogress_link()
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	var results: Array[Dictionary] = EvolutionChecker.check_jogress_partners(
		link, main, party, storage,
	)
	assert_eq(results.size(), 1, "Should have 1 partner requirement")
	assert_true(results[0]["met"] as bool, "Partner in party at level should be met")
	assert_string_contains(
		results[0]["description"] as String, "Partner:",
		"Description should mention partner",
	)


func test_check_jogress_partners_not_found() -> void:
	var link: EvolutionLinkData = _make_jogress_link()
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	# Party with no gabumon
	var party: PartyState = _make_party([main])
	var storage: StorageState = _make_storage()

	var results: Array[Dictionary] = EvolutionChecker.check_jogress_partners(
		link, main, party, storage,
	)
	assert_eq(results.size(), 1, "Should have 1 partner requirement")
	assert_false(results[0]["met"] as bool, "No matching partner should be unmet")


func test_check_jogress_partners_low_level() -> void:
	var link: EvolutionLinkData = _make_jogress_link()
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 10)
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()

	var results: Array[Dictionary] = EvolutionChecker.check_jogress_partners(
		link, main, party, storage,
	)
	assert_false(
		results[0]["met"] as bool,
		"Partner below level requirement should be unmet",
	)


func test_check_jogress_partners_excludes_main() -> void:
	# Main is test_gabumon, partner needs test_gabumon — should exclude self
	var link: EvolutionLinkData = _make_jogress_link()
	link.from_key = &"test_gabumon"
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	# Party has only the main Digimon (same species as needed partner)
	var party: PartyState = _make_party([main])
	var storage: StorageState = _make_storage()

	var results: Array[Dictionary] = EvolutionChecker.check_jogress_partners(
		link, main, party, storage,
	)
	assert_false(
		results[0]["met"] as bool,
		"Main Digimon should be excluded from partner candidates",
	)


# --- find_jogress_candidates ---


func test_find_candidates_party_and_storage() -> void:
	var link: EvolutionLinkData = _make_jogress_link(
		[&"test_gabumon"],
		[] as Array[Dictionary],  # No level requirement
	)
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var party_partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 10)
	var storage_partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 15)
	var party: PartyState = _make_party([main, party_partner])
	var storage: StorageState = _make_storage()
	storage.set_digimon(0, 0, storage_partner)

	var candidates: Dictionary = EvolutionChecker.find_jogress_candidates(
		link, main, party, storage,
	)
	assert_true(candidates.has(&"test_gabumon"), "Should have entry for partner key")
	var found: Array = candidates[&"test_gabumon"]
	assert_eq(found.size(), 2, "Should find 2 candidates (party + storage)")

	var sources: Array[String] = []
	for c: Dictionary in found:
		sources.append(c["source"] as String)
	assert_has(sources, "party", "Should include party candidate")
	assert_has(sources, "storage", "Should include storage candidate")


# --- can_evolve with jogress ---


func test_can_evolve_jogress_all_met() -> void:
	var link: EvolutionLinkData = _make_jogress_link()
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 25)
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()
	var inv: InventoryState = _make_inventory()

	assert_true(
		EvolutionChecker.can_evolve(link, main, inv, party, storage),
		"Should be able to evolve when all requirements and partners met",
	)


func test_can_evolve_jogress_partner_missing() -> void:
	var link: EvolutionLinkData = _make_jogress_link()
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var party: PartyState = _make_party([main])
	var storage: StorageState = _make_storage()
	var inv: InventoryState = _make_inventory()

	assert_false(
		EvolutionChecker.can_evolve(link, main, inv, party, storage),
		"Should not evolve when partner is missing",
	)


func test_can_evolve_jogress_null_party_storage() -> void:
	var link: EvolutionLinkData = _make_jogress_link()
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var inv: InventoryState = _make_inventory()

	assert_false(
		EvolutionChecker.can_evolve(link, main, inv),
		"Should return false when party/storage not provided for jogress",
	)


func test_can_evolve_jogress_no_standard_reqs() -> void:
	var link: EvolutionLinkData = _make_jogress_link(
		[&"test_gabumon"],
		[] as Array[Dictionary],  # No standard requirements
	)
	var main: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 5)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 5)
	var party: PartyState = _make_party([main, partner])
	var storage: StorageState = _make_storage()
	var inv: InventoryState = _make_inventory()

	assert_true(
		EvolutionChecker.can_evolve(link, main, inv, party, storage),
		"Should evolve with only jogress partners, no standard requirements",
	)


# --- Serialisation ---


func test_jogress_partners_serialisation() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 25)
	var partner_data: Dictionary = {
		"key": "test_gabumon",
		"display_id": "AABB1122",
		"level": 20,
	}
	state.jogress_partners.append(partner_data)

	var dict: Dictionary = state.to_dict()
	assert_true(dict.has("jogress_partners"), "to_dict should include jogress_partners")
	assert_eq(
		(dict["jogress_partners"] as Array).size(), 1,
		"Should have 1 partner in serialised data",
	)

	var restored: DigimonState = DigimonState.from_dict(dict)
	assert_eq(
		restored.jogress_partners.size(), 1,
		"from_dict should restore jogress_partners",
	)
	assert_eq(
		restored.jogress_partners[0].get("key", ""),
		"test_gabumon",
		"Restored partner key should match",
	)
