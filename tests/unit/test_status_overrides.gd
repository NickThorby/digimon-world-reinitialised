extends GutTest
## Unit tests for status override/upgrade rules.

var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()


# --- Burned upgrade path ---


func test_burned_on_burned_upgrades_to_badly_burned() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"burned")
	assert_true(target.has_status(&"burned"), "Should start with burned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "burned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_false(target.has_status(&"burned"), "Burned should be removed after upgrade")
	assert_true(
		target.has_status(&"badly_burned"),
		"Should upgrade to badly_burned",
	)
	assert_eq(
		result.get("status", &""), &"badly_burned",
		"Result should report badly_burned",
	)

	# Verify escalation_turn metadata is set
	for status: Dictionary in target.status_conditions:
		if status.get("key", &"") == &"badly_burned":
			assert_eq(
				int(status.get("escalation_turn", -1)), 0,
				"Escalation turn should start at 0",
			)


# --- Poisoned upgrade path ---


func test_poisoned_on_poisoned_upgrades_to_badly_poisoned() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"poisoned")
	assert_true(target.has_status(&"poisoned"), "Should start with poisoned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "poisoned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_false(target.has_status(&"poisoned"), "Poisoned should be removed after upgrade")
	assert_true(
		target.has_status(&"badly_poisoned"),
		"Should upgrade to badly_poisoned",
	)
	assert_eq(
		result.get("status", &""), &"badly_poisoned",
		"Result should report badly_poisoned",
	)

	# Verify escalation_turn metadata
	for status: Dictionary in target.status_conditions:
		if status.get("key", &"") == &"badly_poisoned":
			assert_eq(
				int(status.get("escalation_turn", -1)), 0,
				"Escalation turn should start at 0",
			)


# --- Asleep on exhausted ---


func test_asleep_on_exhausted_removes_exhausted_applies_asleep() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"exhausted")
	assert_true(target.has_status(&"exhausted"), "Should start with exhausted")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "asleep", "chance": 100, "duration": 3},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_false(
		target.has_status(&"exhausted"),
		"Exhausted should be removed when asleep applied",
	)
	assert_true(target.has_status(&"asleep"), "Asleep should be applied")
	assert_true(result.get("applied", false), "Result should report applied")


# --- Existing behaviour: frostbitten upgrade ---


func test_frostbitten_on_frostbitten_upgrades_to_frozen() -> void:
	# Use non-ice target (default gabumon has ice trait, immune to frostbitten)
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.add_status(&"frostbitten")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "frostbitten", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)

	assert_false(target.has_status(&"frostbitten"), "Frostbitten should be removed")
	assert_true(target.has_status(&"frozen"), "Should upgrade to frozen")
	assert_eq(result.get("status", &""), &"frozen", "Result should report frozen")


# --- Existing behaviour: burned removes ice statuses ---


func test_burned_removes_frostbitten() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"frostbitten")

	BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "burned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_false(
		target.has_status(&"frostbitten"),
		"Burned should remove frostbitten",
	)
	assert_true(target.has_status(&"burned"), "Burned should be applied")


func test_burned_removes_frozen() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"frozen")

	BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "burned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_false(target.has_status(&"frozen"), "Burned should remove frozen")
	assert_true(target.has_status(&"burned"), "Burned should be applied")


# --- Frostbitten removes burn-family ---


func test_frostbitten_removes_burned() -> void:
	# Use non-ice target (default gabumon has ice trait, immune to frostbitten)
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.add_status(&"burned")

	BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "frostbitten", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)

	assert_false(
		target.has_status(&"burned"),
		"Frostbitten should remove burned",
	)
	assert_true(target.has_status(&"frostbitten"), "Frostbitten should be applied")


func test_frostbitten_removes_badly_burned() -> void:
	# Use non-ice target (default gabumon has ice trait, immune to frostbitten)
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.add_status(&"badly_burned", -1, {"escalation_turn": 0})

	BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "frostbitten", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)

	assert_false(
		target.has_status(&"badly_burned"),
		"Frostbitten should remove badly_burned",
	)
	assert_true(target.has_status(&"frostbitten"), "Frostbitten should be applied")


# --- canUpgrade flag ---


func test_can_upgrade_false_prevents_burned_upgrade() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"burned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "statusEffect", "status": "burned",
			"chance": 100, "canUpgrade": false,
		},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_true(
		target.has_status(&"burned"),
		"Should still have burned (not upgraded)",
	)
	assert_false(
		target.has_status(&"badly_burned"),
		"Should NOT upgrade to badly_burned",
	)
	assert_false(result.get("applied", true), "Should report not applied")


func test_can_upgrade_false_prevents_poisoned_upgrade() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"poisoned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "statusEffect", "status": "poisoned",
			"chance": 100, "canUpgrade": false,
		},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_true(
		target.has_status(&"poisoned"),
		"Should still have poisoned (not upgraded)",
	)
	assert_false(
		target.has_status(&"badly_poisoned"),
		"Should NOT upgrade to badly_poisoned",
	)
	assert_false(result.get("applied", true), "Should report not applied")


func test_can_upgrade_false_prevents_frostbitten_upgrade() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.add_status(&"frostbitten")

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "statusEffect", "status": "frostbitten",
			"chance": 100, "canUpgrade": false,
		},
		battle.get_digimon_at(0, 0), target, null, battle,
	)

	assert_true(
		target.has_status(&"frostbitten"),
		"Should still have frostbitten (not upgraded)",
	)
	assert_false(
		target.has_status(&"frozen"),
		"Should NOT upgrade to frozen",
	)
	assert_false(result.get("applied", true), "Should report not applied")


func test_can_upgrade_true_allows_upgrade_default() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"burned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "burned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_true(
		target.has_status(&"badly_burned"),
		"Default canUpgrade=true should allow upgrade",
	)
	assert_eq(
		result.get("status", &""), &"badly_burned",
		"Result should report badly_burned",
	)


func test_can_upgrade_true_explicit_allows_upgrade() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"poisoned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "statusEffect", "status": "poisoned",
			"chance": 100, "canUpgrade": true,
		},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_true(
		target.has_status(&"badly_poisoned"),
		"Explicit canUpgrade=true should allow upgrade",
	)
	assert_eq(
		result.get("status", &""), &"badly_poisoned",
		"Result should report badly_poisoned",
	)
