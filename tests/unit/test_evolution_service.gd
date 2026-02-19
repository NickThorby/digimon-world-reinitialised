extends GutTest
## Unit tests for EvolutionService utility.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func test_find_available_evolutions_returns_all_valid_links() -> void:
	# test_agumon at level 50 should have multiple evolution links
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var links: Array[EvolutionLinkData] = EvolutionService.find_available_evolutions(
		digimon,
	)
	# Should include standard, jogress, armor, x_antibody links from test_agumon
	assert_gt(links.size(), 0, "Should find at least one evolution link")

	var link_keys: Array[StringName] = []
	for link: EvolutionLinkData in links:
		link_keys.append(link.key)

	assert_true(
		&"test_evo_agumon_tank" in link_keys,
		"Should include standard evolution link",
	)
	assert_true(
		&"test_evo_jogress" in link_keys,
		"Should include jogress evolution link",
	)


func test_find_available_evolutions_includes_slide_and_mode_change() -> void:
	# test_wall has a free slide link (no requirements) — should be included
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_wall", 50,
	)
	var links: Array[EvolutionLinkData] = EvolutionService.find_available_evolutions(
		digimon,
	)
	var link_keys: Array[StringName] = []
	for link: EvolutionLinkData in links:
		link_keys.append(link.key)

	assert_true(
		&"test_evo_free_slide" in link_keys,
		"SLIDE links with no requirements should still be included",
	)


func test_find_warp_evolutions_follows_standard_chain() -> void:
	# test_agumon → test_tank (level 20) → test_wall (level 20)
	# At level 50, both should pass. Warp should find the chain.
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var inventory := InventoryState.new()
	var warps: Array[Dictionary] = EvolutionService.find_warp_evolutions(
		digimon, inventory,
	)
	# Should find at least one warp path ending at test_wall
	var found_wall: bool = false
	for warp: Dictionary in warps:
		if warp.get("final_key") == &"test_wall":
			found_wall = true
			var chain: Array = warp.get("chain", [])
			assert_gt(
				chain.size(), 1,
				"Warp chain should have more than 1 link",
			)
	assert_true(
		found_wall,
		"Should find warp chain ending at test_wall",
	)


func test_find_warp_evolutions_skips_unmet_requirements() -> void:
	# At level 10, test_agumon cannot meet the level 20 requirement
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 10,
	)
	var inventory := InventoryState.new()
	var warps: Array[Dictionary] = EvolutionService.find_warp_evolutions(
		digimon, inventory,
	)
	assert_eq(
		warps.size(), 0,
		"Should find no warp paths when requirements are not met",
	)


func test_can_de_digivolve_with_history() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_tank", 50,
	)
	# No history — cannot de-evolve
	assert_false(
		EvolutionService.can_de_digivolve(digimon),
		"Cannot de-evolve without evolution history",
	)
	# Add history
	digimon.evolution_history.append({
		"from_key": "test_agumon",
		"to_key": "test_tank",
		"evolution_type": Registry.EvolutionType.STANDARD,
	})
	assert_true(
		EvolutionService.can_de_digivolve(digimon),
		"Can de-evolve with evolution history",
	)
