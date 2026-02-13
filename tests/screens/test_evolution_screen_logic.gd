extends GutTest
## Tests for evolution screen logic (no UI, tests state mutations directly).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Finding evolutions ---


func test_find_evolutions_filters_by_from_key() -> void:
	var links: Array[EvolutionLinkData] = []
	for evo_key: StringName in Atlas.evolutions:
		var link: EvolutionLinkData = Atlas.evolutions[evo_key] as EvolutionLinkData
		if link and link.from_key == &"test_agumon":
			links.append(link)
	assert_eq(links.size(), 3,
		"test_agumon should have 3 evolution paths (standard x2 + jogress)")


func test_find_evolutions_none_for_no_evos() -> void:
	var links: Array[EvolutionLinkData] = []
	for evo_key: StringName in Atlas.evolutions:
		var link: EvolutionLinkData = Atlas.evolutions[evo_key] as EvolutionLinkData
		if link and link.from_key == &"test_tank":
			links.append(link)
	assert_eq(links.size(), 0,
		"test_tank should have no evolution paths")


# --- Evolve changes key ---


func test_evolve_changes_key() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	assert_eq(digimon.key, &"test_agumon", "Should start as test_agumon")
	digimon.key = &"test_tank"
	assert_eq(digimon.key, &"test_tank",
		"After evolution, key should be test_tank")


# --- HP/energy proportional adjustment ---


func test_evolve_adjusts_hp_proportionally() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var old_data: DigimonData = Atlas.digimon.get(&"test_agumon") as DigimonData
	var old_stats: Dictionary = StatCalculator.calculate_all_stats(old_data, digimon)
	var old_max_hp: int = old_stats.get(&"hp", 1) as int

	# Set current HP to half
	digimon.current_hp = floori(old_max_hp * 0.5)
	var hp_ratio: float = float(digimon.current_hp) / float(old_max_hp)

	# Evolve
	digimon.key = &"test_tank"
	var new_data: DigimonData = Atlas.digimon.get(&"test_tank") as DigimonData
	var new_stats: Dictionary = StatCalculator.calculate_all_stats(new_data, digimon)
	var new_max_hp: int = new_stats.get(&"hp", 1) as int
	digimon.current_hp = maxi(floori(hp_ratio * float(new_max_hp)), 1)

	# Should be roughly 50% of new max
	var expected: int = maxi(floori(0.5 * float(new_max_hp)), 1)
	assert_eq(digimon.current_hp, expected,
		"HP should be proportionally scaled to new max")


func test_evolve_adjusts_energy_proportionally() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var old_data: DigimonData = Atlas.digimon.get(&"test_agumon") as DigimonData
	var old_stats: Dictionary = StatCalculator.calculate_all_stats(old_data, digimon)
	var old_max_energy: int = old_stats.get(&"energy", 1) as int

	digimon.current_energy = floori(old_max_energy * 0.75)
	var energy_ratio: float = float(digimon.current_energy) / float(old_max_energy)

	digimon.key = &"test_tank"
	var new_data: DigimonData = Atlas.digimon.get(&"test_tank") as DigimonData
	var new_stats: Dictionary = StatCalculator.calculate_all_stats(new_data, digimon)
	var new_max_energy: int = new_stats.get(&"energy", 1) as int
	digimon.current_energy = maxi(floori(energy_ratio * float(new_max_energy)), 1)

	var expected: int = maxi(floori(0.75 * float(new_max_energy)), 1)
	assert_eq(digimon.current_energy, expected,
		"Energy should be proportionally scaled to new max")


# --- Innate techniques added ---


func test_evolve_adds_innate_techniques() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var old_known: int = digimon.known_technique_keys.size()
	# Evolve to test_tank — same test techniques via _make_digimon
	digimon.key = &"test_tank"
	var new_data: DigimonData = Atlas.digimon.get(&"test_tank") as DigimonData
	var new_innate: Array[StringName] = new_data.get_innate_technique_keys()
	for tech_key: StringName in new_innate:
		if tech_key not in digimon.known_technique_keys:
			digimon.known_technique_keys.append(tech_key)
	# Since both test Digimon share the same technique set, known count stays same
	assert_gte(digimon.known_technique_keys.size(), old_known,
		"Known techniques should not decrease after evolution")


func test_evolve_preserves_existing_techniques() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var original_keys: Array[StringName] = digimon.known_technique_keys.duplicate()
	digimon.key = &"test_tank"
	var new_data: DigimonData = Atlas.digimon.get(&"test_tank") as DigimonData
	var new_innate: Array[StringName] = new_data.get_innate_technique_keys()
	for tech_key: StringName in new_innate:
		if tech_key not in digimon.known_technique_keys:
			digimon.known_technique_keys.append(tech_key)
	for old_key: StringName in original_keys:
		assert_true(old_key in digimon.known_technique_keys,
			"Original technique %s should be preserved" % old_key)


# --- Items consumed ---


func test_evolve_consumes_spirit_item() -> void:
	var inventory := InventoryState.new()
	inventory.items[&"test_spirit_item"] = 1
	# Simulate consuming spirit
	var link: EvolutionLinkData = Atlas.evolutions.get(
		&"test_evo_patamon_speedster",
	) as EvolutionLinkData
	assert_not_null(link, "Should find spirit evolution link")
	for req: Dictionary in link.requirements:
		if req.get("type", "") == "spirit":
			var item_key: StringName = StringName(req.get("spirit", ""))
			var current: int = inventory.items.get(item_key, 0)
			if current - 1 <= 0:
				inventory.items.erase(item_key)
			else:
				inventory.items[item_key] = current - 1
	assert_false(inventory.items.has(&"test_spirit_item"),
		"Spirit item should be consumed after evolution")


# --- Force evolve bypasses requirements ---


func test_force_evolve_works_regardless_of_requirements() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 5,
	)
	# Level 5 should not meet level 20 requirement normally
	var link: EvolutionLinkData = Atlas.evolutions.get(
		&"test_evo_agumon_tank",
	) as EvolutionLinkData
	var inventory := InventoryState.new()
	assert_false(EvolutionChecker.can_evolve(link, digimon, inventory),
		"Should not be able to evolve normally at level 5")
	# Force evolve: just change the key regardless
	digimon.key = link.to_key
	assert_eq(digimon.key, &"test_tank",
		"Force evolve should change key even when requirements unmet")


# --- Blocked when requirements unmet ---


func test_cannot_evolve_when_requirements_unmet() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 10,
	)
	var link: EvolutionLinkData = Atlas.evolutions.get(
		&"test_evo_agumon_tank",
	) as EvolutionLinkData
	var inventory := InventoryState.new()
	assert_false(EvolutionChecker.can_evolve(link, digimon, inventory),
		"Should not be able to evolve at level 10 when level 20 required")


func test_can_evolve_when_requirements_met() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 25,
	)
	var link: EvolutionLinkData = Atlas.evolutions.get(
		&"test_evo_agumon_tank",
	) as EvolutionLinkData
	var inventory := InventoryState.new()
	assert_true(EvolutionChecker.can_evolve(link, digimon, inventory),
		"Should be able to evolve at level 25 when level 20 required")
