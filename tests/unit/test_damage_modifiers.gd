extends GutTest
## Unit tests for damageModifier flags, execution context threading,
## and engine integration for damage-related techniques.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


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
