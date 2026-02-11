extends GutTest
## Unit tests for turn economy bricks: multiHit, recharge, delayedAttack,
## delayedHealing, chargeRequirement, semiInvulnerable, multiTurn, and charging
## blocks. Tests cover multi-hit damage and faint stops, recharge skipping,
## delayed effects (future sight and wish), charge-then-fire, weather skip,
## semi-invulnerability dodging, fly prep/attack, outrage locking, and
## charging blocking other actions.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- multiHit ---


func test_multi_hit_fixed_3_deals_3x_damage() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_multi_hit_3", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var total_damage: int = hp_before - target.current_hp
	# 3 hits of ~25 power each; total should be significantly more than 1 hit
	assert_gt(total_damage, 0, "Multi-hit should deal damage")
	# Check times_hit counter — should be 3
	assert_eq(
		int(target.counters.get("times_hit", 0)), 3,
		"Target should have been hit 3 times",
	)


func test_multi_hit_stops_on_faint() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Reduce target HP so it faints before 3 hits
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.current_hp = 1

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_multi_hit_3", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_true(target.is_fainted, "Target should have fainted")
	# Should have been hit once (fainted after first hit)
	assert_eq(
		int(target.counters.get("times_hit", 0)), 1,
		"Target should have been hit only once before fainting",
	)


# --- recharge ---


func test_recharge_skips_next_turn() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Turn 1: Use recharge blast
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_recharge_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_true(
		user.volatiles.get("recharging", false),
		"User should be recharging after recharge blast",
	)

	# Turn 2: Try to use tackle — should be skipped
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions_t2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t2)

	assert_eq(
		target.current_hp, hp_before,
		"Target should not take damage while user is recharging",
	)
	assert_false(
		user.volatiles.get("recharging", false),
		"Recharging flag should be cleared after skip",
	)


func test_recharge_cancelled_by_switch() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_tank"],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Turn 1: Use recharge blast
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_recharge_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	# Turn 2: Switch instead — should clear recharging and proceed
	var actions_t2: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t2)

	# Switch should have succeeded
	var new_user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_ne(
		new_user.data.key, &"test_agumon",
		"Switch should succeed during recharge turn",
	)


# --- delayedAttack (Future Sight) ---


func test_delayed_attack_hits_after_delay() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Turn 1: Use future sight (delayed 2 turns)
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_future_sight_damage", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	assert_eq(
		_battle.pending_effects.size(), 1,
		"Should have one pending delayed attack",
	)

	# Note initial damage from the immediate bricks
	var _hp_after_t1: int = target.current_hp

	# Turn 2: rest (delayed effect not yet resolved)
	var actions_t2: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t2)

	var hp_after_t2: int = target.current_hp

	# Turn 3: end of turn should resolve the delayed attack (turn 1 + 2 = turn 3)
	var actions_t3: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t3)

	assert_lt(
		target.current_hp, hp_after_t2,
		"Delayed attack should deal damage after 2 turn delay",
	)
	assert_eq(
		_battle.pending_effects.size(), 0,
		"Pending effects should be cleared after resolution",
	)


# --- delayedHealing (Wish) ---


func test_delayed_healing_heals_after_delay() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# Damage the user first
	@warning_ignore("integer_division")
	user.apply_damage(user.max_hp / 2)
	var hp_before: int = user.current_hp

	# Turn 1: Use wish (heals 50% max HP after 1 turn)
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_wish", 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	assert_eq(
		_battle.pending_effects.size(), 1,
		"Should have one pending delayed healing",
	)

	# Turn 2: end of turn should resolve the wish (turn 1 + 1 = turn 2)
	var actions_t2: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t2)

	assert_gt(
		user.current_hp, hp_before,
		"Wish should heal the user after 1 turn delay",
	)
	assert_eq(
		_battle.pending_effects.size(), 0,
		"Pending effects should be cleared after resolution",
	)


# --- chargeRequirement ---


func test_charge_requirement_charges_then_fires() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Turn 1: Use charge beam — should charge (no damage)
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_charge_beam", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	assert_eq(
		target.current_hp, hp_before,
		"No damage should be dealt on the charge turn",
	)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var charge_data: Variant = user.volatiles.get("charging")
	assert_true(
		charge_data is Dictionary and not (charge_data as Dictionary).is_empty(),
		"User should be in charging state",
	)

	# Turn 2: Charge completes — technique fires (use any action, pre-action overrides)
	var actions_t2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_charge_beam", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t2)

	assert_lt(
		target.current_hp, hp_before,
		"Charge beam should fire and deal damage on the second turn",
	)

	var charge_after: Variant = user.volatiles.get("charging")
	assert_true(
		not (charge_after is Dictionary) \
			or (charge_after as Dictionary).is_empty(),
		"Charging state should be cleared after firing",
	)


func test_charge_requirement_weather_skip_fires_immediately() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Set sun weather (solar beam skips charge in sun)
	_battle.field.set_weather(&"sun", 5, 0)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Turn 1: Use solar beam — should fire immediately in sun
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_solar_beam", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_lt(
		target.current_hp, hp_before,
		"Solar beam should fire immediately in sun weather",
	)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var charge_data: Variant = user.volatiles.get("charging")
	assert_true(
		not (charge_data is Dictionary) \
			or (charge_data as Dictionary).is_empty(),
		"User should not be in charging state after weather skip",
	)


# --- semiInvulnerable ---


func test_semi_invulnerable_dodges_attack() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	# Manually set target as semi-invulnerable (in sky)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.volatiles["semi_invulnerable"] = &"sky"
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Attack should miss a semi-invulnerable target",
	)


# --- multiTurn + semiInvulnerable (Fly pattern) ---


func test_fly_pattern_preparation_then_attack() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	# Turn 1: Fly — preparation turn (no damage, goes semi-invulnerable)
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fly", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	assert_eq(
		target.current_hp, hp_before,
		"No damage on Fly preparation turn",
	)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_eq(
		user.volatiles.get("semi_invulnerable", &"") as StringName, &"sky",
		"User should be semi-invulnerable (sky) during preparation",
	)

	# Turn 2: Fly strikes — damage dealt, lock clears
	var actions_t2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fly", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t2)

	assert_lt(
		target.current_hp, hp_before,
		"Fly should deal damage on the attack turn",
	)
	assert_eq(
		user.volatiles.get("semi_invulnerable", &"") as StringName, &"",
		"Semi-invulnerable should clear after attack turn",
	)


# --- multiTurn locks user in (Outrage pattern) ---


func test_outrage_locks_user_in() -> void:
	# Use a seed that produces a known duration for randi_range(2, 3)
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon", 42,
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Turn 1: Use outrage — deals damage and sets multi-turn lock
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_outrage", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	var _user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_after_t1: int = target.current_hp
	assert_lt(hp_after_t1, target.max_hp, "Should deal damage on first turn")

	# Turn 2: Auto-uses outrage (locked in)
	var actions_t2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t2)

	assert_lt(
		target.current_hp, hp_after_t1,
		"Should deal damage on locked-in turn",
	)


func test_multi_turn_ends_and_unlocks() -> void:
	_battle = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_gabumon", 42,
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Use outrage — after 2-3 turns the lock should clear
	var actions_t1: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_outrage", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_t1)

	# Execute additional turns until lock clears (max 3 turns total)
	for _i: int in range(3):
		var loop_user: BattleDigimonState = _battle.get_digimon_at(0, 0)
		var lock: Variant = loop_user.volatiles.get("multi_turn_lock")
		if lock is Dictionary and (lock as Dictionary).is_empty():
			break
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var final_lock: Variant = user.volatiles.get("multi_turn_lock")
	assert_true(
		not (final_lock is Dictionary) \
			or (final_lock as Dictionary).is_empty(),
		"Multi-turn lock should eventually clear",
	)


# --- Pending effects skip fainted ---


func test_delayed_attack_skips_fainted_target() -> void:
	# Use reserves so the battle doesn't end when active target faints
	_battle = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_tank"],
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Set up a delayed attack targeting side 1, slot 0
	_battle.pending_effects.append({
		"type": "delayed_attack",
		"resolve_turn": 2,
		"user_side": 0,
		"user_slot": 0,
		"technique_key": &"test_tackle",
		"target_side": 1,
		"target_slot": 0,
		"bypasses_protection": false,
	})
	_battle.turn_number = 1

	# Faint the active target before the delayed effect resolves
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.apply_damage(target.current_hp)
	target.is_fainted = true

	# Turn 2: End of turn should try to resolve but skip fainted target
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		_battle.pending_effects.size(), 0,
		"Pending effect should be removed even if target fainted",
	)


# --- Charging blocks action ---


func test_charging_blocks_technique_use() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Manually set charging state (simulating mid-charge)
	user.volatiles["charging"] = {
		"technique_key": &"test_charge_beam",
		"turns_remaining": 2,
		"skip_in_weather": "",
		"skip_in_terrain": "",
	}

	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.current_hp, hp_before,
		"Target should not take damage while user is charging",
	)
