extends GutTest
## Unit tests for statModifier subtypes (percent, fixed, setToMax, swapWithTarget,
## scalesWithCounter), volatile reset, and statProtection bricks.

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
