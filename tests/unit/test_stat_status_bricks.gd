extends GutTest
## Unit tests for Session 4: statModifier subtypes (percent, fixed, setToMax,
## swapWithTarget, scalesWithCounter), statProtection, statusInteraction,
## and healing (weather, status) bricks.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- statModifier: percent ---


func test_percent_modifier_increases_effective_stat() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var base_atk: int = user.get_effective_stat(&"attack")

	var tech: TechniqueData = Atlas.techniques[&"test_stat_percent_boost"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	var boosted_atk: int = user.get_effective_stat(&"attack")
	# +50% of base value
	var expected: int = maxi(floori(float(base_atk) * 1.5), 1)
	assert_eq(
		boosted_atk, expected,
		"Percent modifier +50%% should increase ATK from %d to %d" % [
			base_atk, expected,
		],
	)


# --- statModifier: fixed ---


func test_fixed_modifier_increases_effective_stat() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var base_def: int = user.get_effective_stat(&"defence")

	var tech: TechniqueData = Atlas.techniques[&"test_stat_fixed_boost"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	var boosted_def: int = user.get_effective_stat(&"defence")
	assert_eq(
		boosted_def, base_def + 20,
		"Fixed modifier +20 should increase DEF from %d to %d" % [
			base_def, base_def + 20,
		],
	)


# --- Volatile modifiers reset on switch ---


func test_volatile_stat_modifiers_cleared_on_reset() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	# Apply a percent modifier
	var tech: TechniqueData = Atlas.techniques[&"test_stat_percent_boost"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)
	assert_false(
		user.volatile_stat_modifiers.is_empty(),
		"Should have volatile modifiers after percent boost",
	)

	# Reset volatiles (simulates switch-out)
	user.reset_volatiles()

	assert_true(
		user.volatile_stat_modifiers.is_empty(),
		"Volatile stat modifiers should be cleared after reset_volatiles()",
	)


# --- statModifier: setToMax ---


func test_set_to_max_sets_stat_stage_to_plus_six() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		user.stat_stages[&"attack"], 0,
		"ATK stage should start at 0",
	)

	var tech: TechniqueData = Atlas.techniques[&"test_stat_set_max"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	assert_eq(
		user.stat_stages[&"attack"], 6,
		"setToMax should set ATK stage to +6",
	)


# --- statModifier: swapWithTarget ---


func test_swap_with_target_exchanges_stat_stages() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Give user +2 ATK, target -1 ATK
	user.modify_stat_stage(&"attack", 2)
	target.modify_stat_stage(&"attack", -1)

	var tech: TechniqueData = Atlas.techniques[&"test_stat_swap"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)

	assert_eq(
		user.stat_stages[&"attack"], -1,
		"After swap, user ATK stage should be -1 (was target's)",
	)
	assert_eq(
		target.stat_stages[&"attack"], 2,
		"After swap, target ATK stage should be +2 (was user's)",
	)


# --- statModifier: scalesWithCounter ---


func test_scales_with_counter_uses_times_hit() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Set times_hit counter on target (user is using the technique on self,
	# but the counter resolves from target's times_hit for
	# timesHitThisBattle)
	target.counters["times_hit"] = 2

	var tech: TechniqueData = Atlas.techniques[&"test_stat_counter_scaling"]
	# scalingPerCount=1, cap=3, count=2 → stages = min(2*1, 3) = 2
	BrickExecutor.execute_bricks(
		tech.bricks, user, target, tech, _battle,
	)

	assert_eq(
		user.stat_stages[&"attack"], 2,
		"scalesWithCounter with 2 hits should give +2 ATK stages",
	)


# --- statProtection: preventLowering ---


func test_stat_protection_blocks_lowering() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Apply stat protection (preventLowering all) to target
	var prot_tech: TechniqueData = Atlas.techniques[
		&"test_stat_protection_lower"
	]
	BrickExecutor.execute_bricks(
		prot_tech.bricks, target, target, prot_tech, _battle,
	)

	# Now try to debuff target's speed
	var debuff_tech: TechniqueData = Atlas.techniques[&"test_debuff_speed"]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		debuff_tech.bricks, user, target, debuff_tech, _battle,
	)

	assert_eq(
		target.stat_stages[&"speed"], 0,
		"Stat protection (preventLowering) should block speed drop",
	)

	# Verify the result reports blocked
	var stat_changes: Variant = results[0].get("stat_changes", [])
	if stat_changes is Array and (stat_changes as Array).size() > 0:
		assert_true(
			(stat_changes as Array)[0].get("blocked", false),
			"Result should indicate the stat change was blocked",
		)


# --- statProtection: preventRaising ---


func test_stat_protection_blocks_raising() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Apply preventRaising on target's ATK and SPA
	var prot_tech: TechniqueData = Atlas.techniques[
		&"test_stat_protection_raise"
	]
	BrickExecutor.execute_bricks(
		prot_tech.bricks, user, target, prot_tech, _battle,
	)

	# Now try to boost target's ATK
	var boost_tech: TechniqueData = Atlas.techniques[&"test_boost_attack"]
	BrickExecutor.execute_bricks(
		boost_tech.bricks, target, target, boost_tech, _battle,
	)

	assert_eq(
		target.stat_stages[&"attack"], 0,
		"Stat protection (preventRaising) should block ATK boost",
	)


# --- statProtection: allows opposite direction ---


func test_stat_protection_allows_opposite_direction() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Apply preventLowering on target
	var prot_tech: TechniqueData = Atlas.techniques[
		&"test_stat_protection_lower"
	]
	BrickExecutor.execute_bricks(
		prot_tech.bricks, target, target, prot_tech, _battle,
	)

	# Try to boost target's ATK (should succeed — only lowering is blocked)
	var boost_tech: TechniqueData = Atlas.techniques[&"test_boost_attack"]
	BrickExecutor.execute_bricks(
		boost_tech.bricks, target, target, boost_tech, _battle,
	)

	assert_eq(
		target.stat_stages[&"attack"], 2,
		"preventLowering should NOT block stat raises (+2 ATK)",
	)


# --- statProtection: duration expiry ---


func test_stat_protection_expires_after_duration() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Manually set a stat protection with 1 turn remaining
	target.volatiles["stat_protections"] = [{
		"stats": "all",
		"prevent_lowering": true,
		"prevent_raising": false,
		"remaining_turns": 1,
	}]

	# Run a turn (both rest) to trigger end-of-turn tick
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var protections: Variant = target.volatiles.get("stat_protections", [])
	var prot_arr: Array = protections as Array if protections is Array else []
	assert_eq(
		prot_arr.size(), 0,
		"Stat protection should expire after its duration runs out",
	)


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

	# Set sun weather
	_battle.field.set_weather(&"sun", 5, 0)

	var tech: TechniqueData = Atlas.techniques[&"test_weather_heal"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	var healed: int = user.current_hp - hp_before
	# In sun: heal_percent = 0.667, so heal ~66.7% of max HP
	var expected_min: int = floori(float(user.max_hp) * 0.6)
	assert_gt(
		healed, expected_min,
		"Weather healing in sun should heal at least 60%% of max HP (healed %d)" % healed,
	)


func test_weather_healing_less_in_sandstorm() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	user.apply_damage(user.max_hp - 1)
	var hp_before: int = user.current_hp

	# Set sandstorm weather
	_battle.field.set_weather(&"sandstorm", 5, 0)

	var tech: TechniqueData = Atlas.techniques[&"test_weather_heal"]
	BrickExecutor.execute_bricks(
		tech.bricks, user, user, tech, _battle,
	)

	var healed: int = user.current_hp - hp_before
	# In sandstorm: heal_percent = 0.25, so heal 25% of max HP
	var expected_max: int = ceili(float(user.max_hp) * 0.3)
	assert_lt(
		healed, expected_max,
		"Weather healing in sandstorm should heal at most 30%% of max HP (healed %d)" % healed,
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
