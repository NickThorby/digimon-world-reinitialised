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


# --- Upgraded status blocks base status application ---


func test_poisoned_blocked_when_badly_poisoned_exists() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"badly_poisoned", -1, {"escalation_turn": 0})

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "poisoned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_true(
		target.has_status(&"badly_poisoned"),
		"Should still have badly_poisoned",
	)
	assert_false(
		target.has_status(&"poisoned"),
		"Should NOT have base poisoned alongside badly_poisoned",
	)
	assert_eq(
		result.get("status", &""), &"badly_poisoned",
		"Result should report the existing badly_poisoned",
	)


func test_burned_blocked_when_badly_burned_exists() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"badly_burned", -1, {"escalation_turn": 0})

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "burned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_true(
		target.has_status(&"badly_burned"),
		"Should still have badly_burned",
	)
	assert_false(
		target.has_status(&"burned"),
		"Should NOT have base burned alongside badly_burned",
	)
	assert_eq(
		result.get("status", &""), &"badly_burned",
		"Result should report the existing badly_burned",
	)


func test_frostbitten_blocked_when_frozen_exists() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.add_status(&"frozen", 3)

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "frostbitten", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)

	assert_true(
		target.has_status(&"frozen"),
		"Should still have frozen",
	)
	assert_false(
		target.has_status(&"frostbitten"),
		"Should NOT have base frostbitten alongside frozen",
	)
	assert_eq(
		result.get("status", &""), &"frozen",
		"Result should report the existing frozen",
	)


# --- Direct upgraded status application replaces base ---


func test_badly_poisoned_replaces_poisoned() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"poisoned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "badly_poisoned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_false(
		target.has_status(&"poisoned"),
		"Poisoned should be removed when badly_poisoned applied directly",
	)
	assert_true(
		target.has_status(&"badly_poisoned"),
		"Should have badly_poisoned",
	)
	assert_true(result.get("applied", false), "Should report applied")


func test_badly_burned_replaces_burned() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.add_status(&"burned")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "badly_burned", "chance": 100},
		_battle.get_digimon_at(0, 0), target, null, _battle,
	)

	assert_false(
		target.has_status(&"burned"),
		"Burned should be removed when badly_burned applied directly",
	)
	assert_true(
		target.has_status(&"badly_burned"),
		"Should have badly_burned",
	)
	assert_true(result.get("applied", false), "Should report applied")


func test_frozen_replaces_frostbitten() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	target.add_status(&"frostbitten")

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "statusEffect", "status": "frozen", "chance": 100},
		battle.get_digimon_at(0, 0), target, null, battle,
	)

	assert_false(
		target.has_status(&"frostbitten"),
		"Frostbitten should be removed when frozen applied directly",
	)
	assert_true(
		target.has_status(&"frozen"),
		"Should have frozen",
	)
	assert_true(result.get("applied", false), "Should report applied")


# --- Triple application: base -> upgrade -> base should not stack ---


func test_triple_poison_does_not_stack() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "poisoned", "chance": 100,
	}

	# First application: adds poisoned
	BrickExecutor.execute_brick(brick, user, target, null, _battle)
	assert_true(target.has_status(&"poisoned"), "First apply: should have poisoned")

	# Second application: upgrades to badly_poisoned
	BrickExecutor.execute_brick(brick, user, target, null, _battle)
	assert_true(
		target.has_status(&"badly_poisoned"),
		"Second apply: should upgrade to badly_poisoned",
	)
	assert_false(
		target.has_status(&"poisoned"),
		"Second apply: poisoned should be removed",
	)

	# Third application: should NOT add poisoned alongside badly_poisoned
	BrickExecutor.execute_brick(brick, user, target, null, _battle)
	assert_true(
		target.has_status(&"badly_poisoned"),
		"Third apply: should still have badly_poisoned",
	)
	assert_false(
		target.has_status(&"poisoned"),
		"Third apply: should NOT have poisoned alongside badly_poisoned",
	)


func test_triple_burn_does_not_stack() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "burned", "chance": 100,
	}

	BrickExecutor.execute_brick(brick, user, target, null, _battle)
	assert_true(target.has_status(&"burned"), "First apply: should have burned")

	BrickExecutor.execute_brick(brick, user, target, null, _battle)
	assert_true(
		target.has_status(&"badly_burned"),
		"Second apply: should upgrade to badly_burned",
	)

	BrickExecutor.execute_brick(brick, user, target, null, _battle)
	assert_true(
		target.has_status(&"badly_burned"),
		"Third apply: should still have badly_burned",
	)
	assert_false(
		target.has_status(&"burned"),
		"Third apply: should NOT have burned alongside badly_burned",
	)


func test_triple_frostbite_does_not_stack() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_agumon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var user: BattleDigimonState = battle.get_digimon_at(0, 0)
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "frostbitten", "chance": 100,
	}

	BrickExecutor.execute_brick(brick, user, target, null, battle)
	assert_true(
		target.has_status(&"frostbitten"),
		"First apply: should have frostbitten",
	)

	BrickExecutor.execute_brick(brick, user, target, null, battle)
	assert_true(
		target.has_status(&"frozen"),
		"Second apply: should upgrade to frozen",
	)

	BrickExecutor.execute_brick(brick, user, target, null, battle)
	assert_true(
		target.has_status(&"frozen"),
		"Third apply: should still have frozen",
	)
	assert_false(
		target.has_status(&"frostbitten"),
		"Third apply: should NOT have frostbitten alongside frozen",
	)
