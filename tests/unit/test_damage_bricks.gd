extends GutTest
## Unit tests for Session 2: damage subtypes, damageModifier flags, recoil,
## criticalHit (alwaysCrit/neverCrit), and drain healing.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Fixed damage ---


func test_fixed_damage_deals_exact_amount() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "damage", "type": "fixed", "amount": 40},
		_battle.get_digimon_at(0, 0), target,
		Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_eq(
		result.get("damage", 0), 40,
		"Fixed damage should deal exactly 40 HP",
	)
	assert_eq(
		target.current_hp, hp_before - 40,
		"Target HP should decrease by exactly 40",
	)


func test_fixed_damage_zero_amount_deals_nothing() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "damage", "type": "fixed", "amount": 0},
		_battle.get_digimon_at(0, 0), target,
		Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_eq(result.get("damage", 0), 0, "Fixed 0 should deal no damage")
	assert_eq(target.current_hp, hp_before, "Target HP should be unchanged")


# --- Percentage damage ---


func test_percentage_damage_target_max_hp() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var expected: int = maxi(floori(float(target.max_hp) * 25.0 / 100.0), 1)
	var hp_before: int = target.current_hp

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "damage", "type": "percentage",
			"percent": 25, "source": "targetMaxHp",
		},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_eq(
		result.get("damage", 0), expected,
		"Percentage damage should deal 25%% of target max HP (%d)" % expected,
	)
	assert_eq(
		target.current_hp, hp_before - expected,
		"Target HP should decrease by the percentage amount",
	)


func test_percentage_damage_user_current_hp() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	user.apply_damage(50)  # Reduce user HP first
	var expected: int = maxi(
		floori(float(user.current_hp) * 50.0 / 100.0), 1,
	)

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "damage", "type": "percentage",
			"percent": 50, "source": "userCurrentHp",
		},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_eq(
		result.get("damage", 0), expected,
		"Should deal 50%% of user's current HP (%d)" % expected,
	)


# --- Level damage ---


func test_level_damage_equals_user_level() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var level: int = user.source_state.level
	var hp_before: int = target.current_hp

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "damage", "type": "level"},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_eq(
		result.get("damage", 0), level,
		"Level damage should deal exactly %d (user's level)" % level,
	)
	assert_eq(
		target.current_hp, hp_before - level,
		"Target HP should decrease by user's level",
	)


# --- Scaling damage ---


func test_scaling_damage_uses_specified_stat() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "damage", "type": "scaling", "stat": "spa", "power": 80},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_gt(
		result.get("damage", 0), 0,
		"Scaling damage should deal > 0 damage",
	)
	assert_lt(
		target.current_hp, hp_before,
		"Target HP should decrease from scaling damage",
	)


# --- Return damage ---


func test_return_damage_reflects_last_hit() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Simulate target having taken 30 damage previously
	target.volatiles["last_hit"] = 30
	var hp_before: int = target.current_hp

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "damage", "type": "returnDamage",
			"damageSource": "lastHit", "returnMultiplier": 1.5,
		},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	# 30 * 1.5 = 45
	assert_eq(
		result.get("damage", 0), 45,
		"Return damage should deal 1.5x of last hit (30 * 1.5 = 45)",
	)


func test_return_damage_zero_when_no_last_hit() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "damage", "type": "returnDamage",
			"damageSource": "lastHit", "returnMultiplier": 2.0,
		},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_eq(
		result.get("damage", 0), 0,
		"Return damage should be 0 when target has no last_hit in volatiles",
	)


func test_return_damage_physical_only() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Set physical hit but not special
	target.volatiles["last_physical_hit"] = 20
	target.volatiles["last_special_hit"] = 0

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "damage", "type": "returnDamage",
			"damageSource": "lastPhysicalHit", "returnMultiplier": 2.0,
		},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	assert_eq(
		result.get("damage", 0), 40,
		"Should return 2x last physical hit (20 * 2 = 40)",
	)


# --- Counter-scaling damage ---


func test_counter_scaling_damage_with_hits() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Target has been hit 3 times
	target.counters["times_hit"] = 3

	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "damage", "type": "counterScaling",
			"basePower": 20, "scalesWithCounter": "timesHitThisBattle",
			"scalingPerCount": 20, "scalingCap": 100,
		},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	# basePower 20 + 3 * 20 = 80, should deal damage > 0
	assert_gt(
		result.get("damage", 0), 0,
		"Counter-scaling damage should deal > 0 with 3 hits",
	)


func test_counter_scaling_capped_at_scaling_cap() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Target has been hit 100 times (should cap at scalingCap)
	target.counters["times_hit"] = 100
	var hp_before: int = target.current_hp

	# Cap is 40, so bonus is 40 even with 100 * 20 = 2000
	var result: Dictionary = BrickExecutor.execute_brick(
		{
			"brick": "damage", "type": "counterScaling",
			"basePower": 20, "scalesWithCounter": "timesHitThisBattle",
			"scalingPerCount": 20, "scalingCap": 40,
		},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	# Effective power = 20 + 40 = 60 (cap prevents going higher)
	assert_gt(
		result.get("damage", 0), 0,
		"Counter-scaling should deal damage even at cap",
	)


# --- Track last hit ---


func test_standard_damage_tracks_last_hit() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "damage", "type": "standard"},
		user, target, Atlas.techniques[&"test_tackle"], _battle,
	)

	var dmg: int = result.get("damage", 0)
	assert_gt(dmg, 0, "Standard damage should deal > 0")
	assert_eq(
		int(target.volatiles.get("last_hit", 0)), dmg,
		"last_hit volatile should match damage dealt",
	)
	assert_eq(
		int(target.volatiles.get("last_physical_hit", 0)), dmg,
		"last_physical_hit should be set for physical technique",
	)


# --- Recoil bricks ---


func test_recoil_damage_percent() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var user_hp_before: int = user.current_hp

	# Execute with damage_dealt already in context (simulating prior damage)
	var context: Dictionary = {"damage_dealt": 100, "technique_missed": false}
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "recoil", "type": "damagePercent", "percent": 25},
		user, target, Atlas.techniques[&"test_tackle"], _battle, context,
	)

	# 25% of 100 = 25
	assert_eq(
		result.get("recoil", 0), 25,
		"Recoil should deal 25%% of 100 damage dealt = 25",
	)
	assert_eq(
		user.current_hp, user_hp_before - 25,
		"User HP should decrease by recoil amount",
	)


func test_recoil_fixed() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var user_hp_before: int = user.current_hp

	var context: Dictionary = {"damage_dealt": 50, "technique_missed": false}
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "recoil", "type": "fixed", "amount": 10},
		user, target, Atlas.techniques[&"test_tackle"], _battle, context,
	)

	assert_eq(
		result.get("recoil", 0), 10,
		"Fixed recoil should deal exactly 10",
	)
	assert_eq(
		user.current_hp, user_hp_before - 10,
		"User HP should decrease by fixed recoil",
	)


func test_recoil_hp_percent() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var expected: int = maxi(roundi(float(user.max_hp) * 33.0 / 100.0), 1)
	var user_hp_before: int = user.current_hp

	var context: Dictionary = {"damage_dealt": 50, "technique_missed": false}
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "recoil", "type": "hpPercent", "percent": 33},
		user, target, Atlas.techniques[&"test_tackle"], _battle, context,
	)

	assert_eq(
		result.get("recoil", 0), expected,
		"HP percent recoil should deal 33%% of max HP = %d" % expected,
	)


func test_crash_recoil_only_on_miss() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# When technique hits, crash recoil should NOT apply
	var context_hit: Dictionary = {
		"damage_dealt": 50, "technique_missed": false,
	}
	var result_hit: Dictionary = BrickExecutor.execute_brick(
		{"brick": "recoil", "type": "crash", "percent": 50},
		user, target, Atlas.techniques[&"test_tackle"], _battle, context_hit,
	)

	assert_eq(
		result_hit.get("recoil", 0), 0,
		"Crash recoil should NOT apply when technique hits",
	)

	# When technique misses, crash recoil SHOULD apply
	var user_hp_before: int = user.current_hp
	var expected: int = maxi(roundi(float(user.max_hp) * 50.0 / 100.0), 1)
	var context_miss: Dictionary = {
		"damage_dealt": 0, "technique_missed": true,
	}
	var result_miss: Dictionary = BrickExecutor.execute_brick(
		{"brick": "recoil", "type": "crash", "percent": 50},
		user, target, Atlas.techniques[&"test_tackle"], _battle, context_miss,
	)

	assert_eq(
		result_miss.get("recoil", 0), expected,
		"Crash recoil should deal 50%% max HP on miss = %d" % expected,
	)


# --- Drain healing ---


func test_drain_heals_user_based_on_damage_dealt() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Damage user first so healing is visible
	user.apply_damage(80)
	var user_hp_after_damage: int = user.current_hp

	var context: Dictionary = {"damage_dealt": 60, "technique_missed": false}
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "healing", "type": "drain", "percent": 50},
		user, target, Atlas.techniques[&"test_tackle"], _battle, context,
	)

	# 50% of 60 = 30
	var expected_heal: int = maxi(roundi(60.0 * 50.0 / 100.0), 1)
	assert_eq(
		result.get("healing", 0), expected_heal,
		"Drain should heal user by 50%% of 60 damage = %d" % expected_heal,
	)
	assert_eq(
		user.current_hp, user_hp_after_damage + expected_heal,
		"User HP should increase by drain amount",
	)


func test_drain_zero_when_no_damage_dealt() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	var context: Dictionary = {"damage_dealt": 0, "technique_missed": false}
	var result: Dictionary = BrickExecutor.execute_brick(
		{"brick": "healing", "type": "drain", "percent": 50},
		user, target, Atlas.techniques[&"test_tackle"], _battle, context,
	)

	assert_eq(
		result.get("healing", 0), 0,
		"Drain should heal 0 when no damage was dealt",
	)


# --- criticalHit: alwaysCrit / neverCrit ---


func test_always_crit_produces_critical() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Execute the technique bricks which includes criticalHit(alwaysCrit) + damage
	var technique: TechniqueData = Atlas.techniques[&"test_always_crit"]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique.bricks, user, target, technique, _battle,
	)

	# Find the damage result
	var found_crit: bool = false
	for result: Dictionary in results:
		if result.get("damage", 0) > 0:
			found_crit = result.get("was_critical", false)
			break

	assert_true(
		found_crit,
		"alwaysCrit technique should always produce a critical hit",
	)


func test_never_crit_prevents_critical() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	var technique: TechniqueData = Atlas.techniques[&"test_never_crit"]

	# Run 10 times to ensure no crits (neverCrit should block all)
	var any_crit: bool = false
	for i: int in range(10):
		# Restore target HP between runs
		target.restore_hp(9999)
		var results: Array[Dictionary] = BrickExecutor.execute_bricks(
			technique.bricks, user, target, technique, _battle,
		)
		for result: Dictionary in results:
			if result.get("was_critical", false):
				any_crit = true
				break

	assert_false(
		any_crit,
		"neverCrit technique should never produce a critical hit",
	)


# --- damageModifier flags ---


func test_extract_crit_info() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_always_crit"]
	var info: Dictionary = BrickExecutor._extract_crit_info(technique)

	assert_true(
		info.get("always_crit", false),
		"Should extract alwaysCrit from criticalHit brick",
	)
	assert_false(
		info.get("never_crit", false),
		"Should not set neverCrit when only alwaysCrit is set",
	)


func test_collect_flags_ignore_defence() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var technique: TechniqueData = Atlas.techniques[&"test_ignore_defence"]

	var flags: Dictionary = BrickExecutor.get_technique_flags(
		user, target, technique, _battle,
	)

	assert_true(
		flags.get("ignore_defence", false),
		"Should detect ignoreDefense flag on technique",
	)


func test_collect_flags_ignore_stat_boosts() -> void:
	_battle = TestBattleFactory.create_1v1_battle()

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var technique: TechniqueData = Atlas.techniques[
		&"test_ignore_stat_boosts"
	]

	var flags: Dictionary = BrickExecutor.get_technique_flags(
		user, target, technique, _battle,
	)

	assert_true(
		flags.get("ignore_stat_boosts", false),
		"Should detect ignoreStatBoosts flag on technique",
	)


func test_ignore_defence_increases_damage() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Boost target's defence to +6
	target.stat_stages[&"defence"] = 6

	# Normal tackle with boosted defence
	var technique_normal: TechniqueData = Atlas.techniques[&"test_tackle"]
	var results_normal: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique_normal.bricks, user, target, technique_normal, _battle,
	)
	var dmg_normal: int = 0
	for r: Dictionary in results_normal:
		dmg_normal += int(r.get("damage", 0))

	# Restore target HP
	target.restore_hp(9999)

	# ignoreDefence technique should deal more damage
	var technique_ignore: TechniqueData = Atlas.techniques[
		&"test_ignore_defence"
	]
	var results_ignore: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique_ignore.bricks, user, target, technique_ignore, _battle,
	)
	var dmg_ignore: int = 0
	for r: Dictionary in results_ignore:
		dmg_ignore += int(r.get("damage", 0))

	assert_gt(
		dmg_ignore, dmg_normal,
		"Ignore defence should deal more damage than normal against +6 DEF",
	)


func test_ignore_stat_boosts_negates_target_positive_stages() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Boost target's defence to +4
	target.stat_stages[&"defence"] = 4

	# Normal tackle
	var technique_normal: TechniqueData = Atlas.techniques[&"test_tackle"]
	var results_normal: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique_normal.bricks, user, target, technique_normal, _battle,
	)
	var dmg_normal: int = 0
	for r: Dictionary in results_normal:
		dmg_normal += int(r.get("damage", 0))

	target.restore_hp(9999)

	# ignoreStatBoosts technique
	var technique_ignore: TechniqueData = Atlas.techniques[
		&"test_ignore_stat_boosts"
	]
	var results_ignore: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique_ignore.bricks, user, target, technique_ignore, _battle,
	)
	var dmg_ignore: int = 0
	for r: Dictionary in results_ignore:
		dmg_ignore += int(r.get("damage", 0))

	assert_gt(
		dmg_ignore, dmg_normal,
		"Ignore stat boosts should deal more damage than normal vs +4 DEF",
	)


func test_ignore_type_immunity_deals_damage() -> void:
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_patamon",
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	# test_patamon has dark: 0.0 (immune)
	var hp_before: int = target.current_hp

	var technique: TechniqueData = Atlas.techniques[
		&"test_ignore_type_immunity"
	]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique.bricks, user, target, technique, _battle,
	)

	var total_dmg: int = 0
	for r: Dictionary in results:
		total_dmg += int(r.get("damage", 0))

	assert_gt(
		total_dmg, 0,
		"ignoreTypeImmunity should deal damage to dark-immune target",
	)


# --- Execution context threading ---


func test_execute_bricks_threads_damage_to_recoil() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var user_hp_before: int = user.current_hp

	# Use the recoil technique which has damage + recoil bricks
	var technique: TechniqueData = Atlas.techniques[&"test_recoil_percent"]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique.bricks, user, target, technique, _battle,
	)

	# Find damage and recoil results
	var damage_dealt: int = 0
	var recoil_taken: int = 0
	for r: Dictionary in results:
		if r.get("damage", 0) > 0:
			damage_dealt = int(r["damage"])
		if r.get("recoil", 0) > 0:
			recoil_taken = int(r["recoil"])

	assert_gt(damage_dealt, 0, "Technique should deal damage")
	var expected_recoil: int = maxi(
		roundi(float(damage_dealt) * 25.0 / 100.0), 1,
	)
	assert_eq(
		recoil_taken, expected_recoil,
		"Recoil should be 25%% of %d = %d" % [damage_dealt, expected_recoil],
	)
	assert_eq(
		user.current_hp, user_hp_before - recoil_taken,
		"User HP should decrease by recoil amount",
	)


func test_execute_bricks_threads_damage_to_drain() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Damage user first
	user.apply_damage(80)
	var user_hp_after_damage: int = user.current_hp

	var technique: TechniqueData = Atlas.techniques[&"test_drain"]
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique.bricks, user, target, technique, _battle,
	)

	var damage_dealt: int = 0
	var heal_amount: int = 0
	for r: Dictionary in results:
		if r.get("damage", 0) > 0:
			damage_dealt = int(r["damage"])
		if r.get("healing", 0) > 0:
			heal_amount = int(r["healing"])

	assert_gt(damage_dealt, 0, "Drain technique should deal damage")
	var expected_heal: int = maxi(
		roundi(float(damage_dealt) * 50.0 / 100.0), 1,
	)
	assert_eq(
		heal_amount, expected_heal,
		"Drain should heal 50%% of %d = %d" % [damage_dealt, expected_heal],
	)
	assert_eq(
		user.current_hp, user_hp_after_damage + heal_amount,
		"User HP should increase by drain heal amount",
	)


# --- Integration: full technique execution through engine ---


func test_recoil_technique_through_engine() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	watch_signals(_engine)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var user_hp_before: int = user.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_recoil_percent", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		user.current_hp, user_hp_before,
		"User should take recoil damage through full engine execution",
	)


func test_drain_technique_through_engine() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	watch_signals(_engine)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.apply_damage(80)
	var user_hp_after_damage: int = user.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_drain", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_gt(
		user.current_hp, user_hp_after_damage,
		"User should be healed by drain through full engine execution",
	)


func test_always_crit_through_engine() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)
	watch_signals(_engine)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_always_crit", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_signal_emitted(
		_engine, "battle_message",
		"Always-crit technique should emit a battle_message (critical hit)",
	)
