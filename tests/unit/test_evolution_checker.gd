extends GutTest
## Unit tests for EvolutionChecker.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Helpers ---


func _make_link(requirements: Array[Dictionary]) -> EvolutionLinkData:
	var link := EvolutionLinkData.new()
	link.key = &"test_evo_link"
	link.from_key = &"test_agumon"
	link.to_key = &"test_gabumon"
	link.requirements = requirements
	return link


func _make_digimon(level: int = 50) -> DigimonState:
	return TestBattleFactory.make_digimon_state(&"test_agumon", level)


func _make_inventory() -> InventoryState:
	return InventoryState.new()


# --- Level requirement ---


func test_level_requirement_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "level", "level": 20}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(25)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_eq(results.size(), 1, "Should have 1 requirement result")
	assert_true(results[0]["met"] as bool, "Level 25 should meet level 20 requirement")


func test_level_requirement_not_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "level", "level": 30}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(25)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_false(results[0]["met"] as bool, "Level 25 should not meet level 30 requirement")


func test_level_requirement_exact() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "level", "level": 50}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(50)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_true(results[0]["met"] as bool, "Exact level should meet requirement")


# --- Stat requirement ---


func test_stat_requirement_met() -> void:
	# test_agumon base_attack=100, IV=0, TV=0, level=50
	# Calculated: floor(((2*100 + 0 + 0)*50)/100) + 50 + 10 = 160
	var link: EvolutionLinkData = _make_link(
		[{"type": "stat", "stat": "atk", "operator": ">=", "value": 150}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(50)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_true(results[0]["met"] as bool,
		"Attack 160 should meet >= 150 requirement")


func test_stat_requirement_not_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "stat", "stat": "atk", "operator": ">=", "value": 200}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(50)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_false(results[0]["met"] as bool,
		"Attack 160 should not meet >= 200 requirement")


func test_stat_requirement_operator_greater_than() -> void:
	# Calculated attack at level 50 with base 100 = 160
	var link: EvolutionLinkData = _make_link(
		[{"type": "stat", "stat": "atk", "operator": ">", "value": 160}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(50)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_false(results[0]["met"] as bool,
		"Attack 160 should not meet > 160 (strict greater)")


# --- Stat highest of ---


func test_stat_highest_of_met() -> void:
	# test_agumon: base_attack=100, base_defence=60, base_special_attack=50
	# At level 50: atk=160, def=120, spa=110
	var link: EvolutionLinkData = _make_link(
		[{"type": "stat_highest_of", "stat": "atk", "among": ["def", "spa"]}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(50)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_true(results[0]["met"] as bool,
		"Attack should be highest among atk/def/spa for test_agumon")


func test_stat_highest_of_not_met() -> void:
	# test_agumon: base_attack=100, base_hp=80
	# defence(60) < attack(100), so defence is NOT highest
	var link: EvolutionLinkData = _make_link(
		[{"type": "stat_highest_of", "stat": "def", "among": ["atk"]}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon(50)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_false(results[0]["met"] as bool,
		"Defence should not be highest when attack is higher")


# --- Item-based requirements ---


func test_spirit_requirement_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "spirit", "spirit": "test_spirit_fire"}] as Array[Dictionary],
	)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_spirit_fire"] = 1
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), inv,
	)
	assert_true(results[0]["met"] as bool, "Should be met when spirit item is owned")


func test_spirit_requirement_not_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "spirit", "spirit": "test_spirit_fire"}] as Array[Dictionary],
	)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), _make_inventory(),
	)
	assert_false(results[0]["met"] as bool, "Should not be met without spirit item")


func test_digimental_requirement_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "digimental", "digimental": "test_digimental_courage"}] as Array[Dictionary],
	)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), inv,
	)
	assert_true(results[0]["met"] as bool, "Should be met when digimental is owned")


func test_x_antibody_requirement_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "x_antibody", "amount": 3}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon()
	digimon.x_antibody = 5
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_true(results[0]["met"] as bool, "5 x_antibody should meet requirement of 3")


func test_x_antibody_requirement_not_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "x_antibody", "amount": 3}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon()
	digimon.x_antibody = 2
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_false(results[0]["met"] as bool, "2 x_antibody should not meet requirement of 3")


# --- Description requirement (always unmet) ---


func test_description_always_unmet() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "description", "text": "Must befriend in story"}] as Array[Dictionary],
	)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), _make_inventory(),
	)
	assert_false(results[0]["met"] as bool,
		"Description requirement should always be unmet")
	assert_eq(results[0]["description"], "Must befriend in story",
		"Description text should be preserved")


# --- can_evolve() ---


func test_can_evolve_all_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "level", "level": 20}] as Array[Dictionary],
	)
	assert_true(
		EvolutionChecker.can_evolve(link, _make_digimon(50), _make_inventory()),
		"Should be able to evolve when all requirements met",
	)


func test_can_evolve_one_unmet() -> void:
	var link: EvolutionLinkData = _make_link([
		{"type": "level", "level": 20},
		{"type": "spirit", "spirit": "missing_spirit"},
	] as Array[Dictionary])
	assert_false(
		EvolutionChecker.can_evolve(link, _make_digimon(50), _make_inventory()),
		"Should not be able to evolve with one unmet requirement",
	)


func test_can_evolve_empty_requirements_returns_false() -> void:
	var link: EvolutionLinkData = _make_link([] as Array[Dictionary])
	assert_false(
		EvolutionChecker.can_evolve(link, _make_digimon(50), _make_inventory()),
		"Empty requirements should return false (nothing to satisfy)",
	)


# --- Multiple requirements (AND logic) ---


func test_multiple_requirements_all_met() -> void:
	var link: EvolutionLinkData = _make_link([
		{"type": "level", "level": 20},
		{"type": "stat", "stat": "atk", "operator": ">=", "value": 100},
	] as Array[Dictionary])
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(50), _make_inventory(),
	)
	assert_eq(results.size(), 2, "Should have 2 requirement results")
	assert_true(results[0]["met"] as bool, "Level requirement should be met")
	assert_true(results[1]["met"] as bool, "Stat requirement should be met")


# --- X-Antibody checks Digimon field ---


func test_x_antibody_checks_digimon_field_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "x_antibody", "amount": 2}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon()
	digimon.x_antibody = 3
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_true(results[0]["met"] as bool,
		"x_antibody 3 on Digimon should meet requirement of 2")


func test_x_antibody_checks_digimon_field_not_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "x_antibody", "amount": 2}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon()
	digimon.x_antibody = 1
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, _make_inventory(),
	)
	assert_false(results[0]["met"] as bool,
		"x_antibody 1 on Digimon should not meet requirement of 2")


func test_x_antibody_ignores_inventory() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "x_antibody", "amount": 1}] as Array[Dictionary],
	)
	var digimon: DigimonState = _make_digimon()
	digimon.x_antibody = 0
	var inv: InventoryState = _make_inventory()
	inv.items[&"x_antibody"] = 99
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, digimon, inv,
	)
	assert_false(results[0]["met"] as bool,
		"x_antibody should check Digimon field, not inventory")


# --- Mode change requirement ---


func test_mode_change_requirement_met_with_item() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "mode_change", "item": "test_mode_item"}] as Array[Dictionary],
	)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_mode_item"] = 1
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), inv,
	)
	assert_true(results[0]["met"] as bool,
		"Mode change should be met when item is owned")


func test_mode_change_requirement_not_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "mode_change", "item": "test_mode_item"}] as Array[Dictionary],
	)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), _make_inventory(),
	)
	assert_false(results[0]["met"] as bool,
		"Mode change should not be met without item")


func test_mode_change_free_always_met() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "mode_change"}] as Array[Dictionary],
	)
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), _make_inventory(),
	)
	assert_true(results[0]["met"] as bool,
		"Free mode change (no item) should always be met")


# --- Spirit/digimental backward compat (item field) ---


func test_spirit_requirement_with_item_field() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "spirit", "item": "test_spirit_item"}] as Array[Dictionary],
	)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_spirit_item"] = 1
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), inv,
	)
	assert_true(results[0]["met"] as bool,
		"Spirit with 'item' field should work")


func test_digimental_requirement_with_item_field() -> void:
	var link: EvolutionLinkData = _make_link(
		[{"type": "digimental", "item": "test_digimental_courage"}] as Array[Dictionary],
	)
	var inv: InventoryState = _make_inventory()
	inv.items[&"test_digimental_courage"] = 1
	var results: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _make_digimon(), inv,
	)
	assert_true(results[0]["met"] as bool,
		"Digimental with 'item' field should work")
