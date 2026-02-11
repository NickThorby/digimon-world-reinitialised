extends GutTest
## Unit tests for statusInteraction bricks (cure, transfer, bonusDamage,
## condition_failed) and healing bricks (weather, status).

var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- statusInteraction: cure ---


func test_status_interaction_cures_target_status() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	target.add_status(&"burned")
	assert_true(target.has_status(&"burned"), "Target should be burned")

	var tech: TechniqueData = Atlas.techniques[
		&"test_status_interaction_cure"
	]
	BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)

	assert_false(
		target.has_status(&"burned"),
		"statusInteraction cure should remove burned from target",
	)


# --- statusInteraction: transfer ---


func test_status_interaction_transfers_status() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	user.add_status(&"poisoned")
	assert_true(user.has_status(&"poisoned"), "User should be poisoned")
	assert_false(
		target.has_status(&"poisoned"), "Target should not be poisoned",
	)

	var tech: TechniqueData = Atlas.techniques[
		&"test_status_interaction_transfer"
	]
	BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)

	assert_false(
		user.has_status(&"poisoned"),
		"User's poison should be removed after transfer",
	)
	assert_true(
		target.has_status(&"poisoned"),
		"Target should now be poisoned after transfer",
	)


# --- statusInteraction: bonusDamage ---


func test_status_interaction_bonus_damage_multiplier() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	var tech: TechniqueData = Atlas.techniques[
		&"test_status_interaction_bonus"
	]

	# Without paralysis — no bonus
	_battle.rng.seed = 99999
	var results_no: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)
	var dmg_no: int = 0
	for r: Dictionary in results_no:
		dmg_no += int(r.get("damage", 0))

	# Restore target HP and add paralysis
	target.restore_hp(9999)
	target.add_status(&"paralysed")

	_battle.rng.seed = 99999
	var results_yes: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)
	var dmg_yes: int = 0
	for r: Dictionary in results_yes:
		dmg_yes += int(r.get("damage", 0))

	assert_gt(
		dmg_yes, dmg_no,
		"statusInteraction bonusDamage 2.0 should deal more vs paralysed",
	)


# --- statusInteraction: condition_failed ---


func test_status_interaction_condition_failed() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Target is NOT burned
	var tech: TechniqueData = Atlas.techniques[
		&"test_status_interaction_cure"
	]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)

	assert_true(
		results[0].get("condition_failed", false),
		"statusInteraction should report condition_failed when target lacks status",
	)


# --- healing: weather ---


func test_weather_healing_more_in_sun() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	# Damage user first
	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	# Set sun weather — plant-element heal is boosted in sun
	_battle.field.set_weather(&"sun", 5, 0)

	var tech: TechniqueData = Atlas.techniques[&"test_plant_heal"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	var healed: int = user.current_hp - hp_before
	# In sun with plant element: heal_percent = 0.667, so heal ~66.7% of max HP
	var expected_min: int = floori(float(user.max_hp) * 0.6)
	assert_gt(
		healed, expected_min,
		"Plant-element weather healing in sun should heal at least 60%% of max HP (healed %d)" % healed,
	)


func test_weather_healing_less_in_sandstorm() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	# Set sandstorm weather — fire-element heal is nerfed in sandstorm
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var tech: TechniqueData = Atlas.techniques[&"test_fire_heal"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	var healed: int = user.current_hp - hp_before
	# In sandstorm with fire element: heal_percent = 0.25, so heal 25% of max HP
	var expected_max: int = ceili(float(user.max_hp) * 0.3)
	assert_lt(
		healed, expected_max,
		"Fire-element weather healing in sandstorm should heal at most 30%% of max HP (healed %d)" % healed,
	)


func test_weather_healing_normal_no_weather() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	# No weather set
	var tech: TechniqueData = Atlas.techniques[&"test_weather_heal"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	var healed: int = user.current_hp - hp_before
	# No weather: heal_percent = 0.5, so heal 50% of max HP
	var expected: int = floori(float(user.max_hp) * 0.5)
	assert_eq(
		healed, expected,
		"Weather healing with no weather should heal 50%% of max HP",
	)


# --- healing: status ---


func test_status_healing_heals_and_cures() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	# Damage and burn the user
	user.apply_damage(50)
	user.add_status(&"burned")
	var hp_before: int = user.current_hp

	var tech: TechniqueData = Atlas.techniques[&"test_status_heal"]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	assert_gt(
		user.current_hp, hp_before,
		"Status healing should restore HP",
	)
	assert_false(
		user.has_status(&"burned"),
		"Status healing should cure burned status",
	)
	# Verify healing amount is 30 (fixed)
	var heal_result: int = int(results[0].get("healing", 0))
	assert_eq(
		heal_result, 30,
		"Status healing should heal exactly 30 HP",
	)
