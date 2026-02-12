extends GutTest
## Unit tests for protection bricks: all, wide, priority types,
## consecutive use failure escalation, and counter damage.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Protection: "all" type ---


func test_protection_all_blocks_single_target_technique() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Target uses Protect, then attacker uses Tackle
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Protection (all) should block single-target technique damage",
	)


func test_protection_all_blocks_multi_target_technique() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_earthquake", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Protection (all) should block multi-target technique damage",
	)


# --- Protection: "wide" type ---


func test_protection_wide_blocks_multi_target_only() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Wide Guard should block Earthquake (ALL_FOES)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_wide_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_earthquake", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Wide Guard should block multi-target Earthquake",
	)


func test_protection_wide_does_not_block_single_target() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Wide Guard should NOT block Tackle (SINGLE_FOE)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_wide_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_lt(
		target.current_hp, hp_before,
		"Wide Guard should NOT block single-target Tackle",
	)


# --- Protection: "priority" type ---


func test_protection_priority_blocks_priority_moves() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Priority Guard should block Quick Strike (HIGH priority)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_priority_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_quick_strike", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Priority Guard should block HIGH priority Quick Strike",
	)


func test_protection_priority_does_not_block_normal_priority() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Priority Guard should NOT block Tackle (NORMAL priority)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_priority_guard", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	assert_lt(
		target.current_hp, hp_before,
		"Priority Guard should NOT block NORMAL priority Tackle",
	)


# --- Protection: consecutive use fail escalation ---


func test_protection_consecutive_uses_can_fail() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Force consecutive uses counter high to guarantee failure
	target.volatiles["consecutive_protection_uses"] = 10
	target.volatiles["used_protection_this_turn"] = true

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	# With 10 consecutive uses, pow(1/3, 10) ~ 0.000017 success rate
	# So it should almost certainly fail and damage should go through
	assert_lt(
		target.current_hp, target.max_hp,
		"Protection should fail after many consecutive uses",
	)


func test_protection_resets_consecutive_when_not_used() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var digimon: BattleDigimonState = _battle.get_digimon_at(0, 0)
	digimon.volatiles["consecutive_protection_uses"] = 3

	# Use Rest (not protection) — should reset counter next turn
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Start of next turn clears the flag, resets counter
	# We can check after the turn completes — the reset happens at start of
	# the NEXT turn. Let's run another turn to trigger the reset.
	_engine.execute_turn(actions)

	assert_eq(
		int(digimon.volatiles.get("consecutive_protection_uses", 0)), 0,
		"Consecutive protection uses should reset when not using protection",
	)


# --- Protection: counter damage ---


func test_protection_counter_damage_on_contact() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var attacker: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var attacker_hp_before: int = attacker.current_hp

	# Target uses counter protect, attacker uses contact tackle
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			1, 0, &"test_counter_protect", 1, 0,
		),
		TestBattleFactory.make_technique_action(
			0, 0, &"test_contact_tackle", 1, 0,
		),
	]
	_engine.execute_turn(actions)

	# Counter damage = 12.5% of attacker's max HP
	assert_lt(
		attacker.current_hp, attacker_hp_before,
		"Attacker should take counter damage from counter protection",
	)
