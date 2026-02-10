extends GutTest
## Unit tests for element-trait-based status immunities.

var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()


# --- Fire trait ---


func test_fire_trait_immune_to_burned() -> void:
	# test_agumon has fire element trait
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_gabumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "burned", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(result.get("blocked", false), "Fire-trait Digimon should be immune to burned")
	assert_eq(
		result.get("reason", ""), "element_immunity",
		"Should report element_immunity reason",
	)
	assert_false(target.has_status(&"burned"), "Should not have burned status")


func test_fire_trait_immune_to_badly_burned() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_gabumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "badly_burned", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(
		result.get("blocked", false),
		"Fire-trait Digimon should be immune to badly_burned",
	)
	assert_false(target.has_status(&"badly_burned"))


# --- Ice trait ---


func test_ice_trait_immune_to_frostbitten() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_ice_mon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "frostbitten", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(
		result.get("blocked", false),
		"Ice-trait Digimon should be immune to frostbitten",
	)
	assert_false(target.has_status(&"frostbitten"))


func test_ice_trait_immune_to_frozen() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_ice_mon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "frozen", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(
		result.get("blocked", false),
		"Ice-trait Digimon should be immune to frozen",
	)
	assert_false(target.has_status(&"frozen"))


# --- Dark trait ---


func test_dark_trait_immune_to_poisoned() -> void:
	# test_tank has dark element trait
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_tank",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "poisoned", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(
		result.get("blocked", false),
		"Dark-trait Digimon should be immune to poisoned",
	)
	assert_false(target.has_status(&"poisoned"))


func test_dark_trait_immune_to_badly_poisoned() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_tank",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "badly_poisoned", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(
		result.get("blocked", false),
		"Dark-trait Digimon should be immune to badly_poisoned",
	)
	assert_false(target.has_status(&"badly_poisoned"))


# --- Lightning trait ---


func test_lightning_trait_immune_to_paralysed() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_lightning_mon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "paralysed", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(
		result.get("blocked", false),
		"Lightning-trait Digimon should be immune to paralysed",
	)
	assert_false(target.has_status(&"paralysed"))


# --- Plant trait ---


func test_plant_trait_immune_to_seeded() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_plant_mon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "seeded", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_true(
		result.get("blocked", false),
		"Plant-trait Digimon should be immune to seeded",
	)
	assert_false(target.has_status(&"seeded"))


# --- Non-immune Digimon still gets status ---


func test_non_immune_digimon_gets_status() -> void:
	# test_gabumon is ice trait — not immune to burned
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "burned", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)
	assert_false(
		result.get("blocked", false),
		"Non-immune Digimon should not be blocked",
	)
	assert_true(target.has_status(&"burned"), "Should have burned status applied")
