extends GutTest
## Unit tests for recoil bricks, drain healing, and criticalHit
## (alwaysCrit/neverCrit).

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


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
	var _user_hp_before: int = user.current_hp

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
	var _user_hp_before: int = user.current_hp
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
