extends GutTest
## Unit tests for damage subtypes: fixed, percentage, level, scaling,
## return, counter-scaling, and last-hit tracking.

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
	var _hp_before: int = target.current_hp

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
	var _hp_before: int = target.current_hp

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
