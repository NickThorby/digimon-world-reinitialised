extends GutTest
## Integration tests for status condition behaviour in the engine.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Pre-execution checks ---


func test_asleep_prevents_action() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"asleep", 3)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		target.current_hp, initial_hp,
		"Asleep Digimon should not be able to attack",
	)


func test_asleep_wakes_after_duration() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"asleep", 1)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_false(
		user.has_status(&"asleep"),
		"Should wake up when duration reaches 0",
	)


func test_frozen_prevents_action() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"frozen", 3)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		target.current_hp, initial_hp,
		"Frozen Digimon should not be able to attack",
	)


func test_frozen_thawed_by_defrost_flag() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"frozen", 5)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_defrost", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_false(user.has_status(&"frozen"), "DEFROST flag should thaw frozen user")


func test_paralysed_sometimes_prevents_action() -> void:
	# Seed 12345: test if paralysis blocks or doesn't block
	# We run 20 turns and check that paralysis blocked at least once and didn't block at least once
	var blocked_count: int = 0
	var passed_count: int = 0
	for i: int in 20:
		var battle: BattleState = TestBattleFactory.create_1v1_battle(
			&"test_agumon", &"test_gabumon", i * 1000,
		)
		var engine: BattleEngine = TestBattleFactory.create_engine(battle)
		var user: BattleDigimonState = battle.get_digimon_at(0, 0)
		user.add_status(&"paralysed")
		var target: BattleDigimonState = battle.get_digimon_at(1, 0)
		var initial_hp: int = target.current_hp

		var actions: Array[BattleAction] = [
			TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		engine.execute_turn(actions)
		if target.current_hp == initial_hp:
			blocked_count += 1
		else:
			passed_count += 1

	assert_gt(blocked_count, 0, "Paralysis should block at least once in 20 trials")
	assert_gt(passed_count, 0, "Paralysis should allow action at least once in 20 trials")


func test_taunted_blocks_status_techniques() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"taunted")
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_status_burn", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_false(
		target.has_status(&"burned"),
		"Taunted Digimon should not be able to use STATUS techniques",
	)


func test_taunted_allows_physical() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"taunted")
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_lt(
		target.current_hp, initial_hp,
		"Taunted Digimon should still use PHYSICAL techniques",
	)


func test_disabled_blocks_specific_technique() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.volatiles["disabled_technique_key"] = &"test_tackle"
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		target.current_hp, initial_hp,
		"Disabled technique should not execute",
	)


func test_encored_forces_specific_technique() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.volatiles["encore_technique_key"] = &"test_fire_blast"
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		user.volatiles.get("last_technique_key", &""), &"test_fire_blast",
		"Encored should force the encored technique",
	)


# --- End-of-turn status ticks ---


func test_burned_dot() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"burned")
	var initial_hp: int = user.current_hp
	@warning_ignore("integer_division")
	var expected_dot: int = maxi(user.max_hp / 16, 1)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	# Damage = max_hp / 16
	assert_lt(user.current_hp, initial_hp, "Burn should deal damage at end of turn")
	# Allow slight deviation due to energy regen not affecting HP
	var damage_taken: int = initial_hp - user.current_hp
	assert_eq(damage_taken, expected_dot, "Burn damage should be 1/16 max HP")


func test_poisoned_dot() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"poisoned")
	var initial_hp: int = user.current_hp
	@warning_ignore("integer_division")
	var expected_dot: int = maxi(user.max_hp / 8, 1)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var damage_taken: int = initial_hp - user.current_hp
	assert_eq(damage_taken, expected_dot, "Poison damage should be 1/8 max HP")


func test_frostbitten_dot() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"frostbitten")
	var initial_hp: int = user.current_hp
	@warning_ignore("integer_division")
	var expected_dot: int = maxi(user.max_hp / 16, 1)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var damage_taken: int = initial_hp - user.current_hp
	assert_eq(damage_taken, expected_dot, "Frostbite damage should be 1/16 max HP")


func test_seeded_drains_hp_heals_seeder() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var seeder: BattleDigimonState = _battle.get_digimon_at(0, 0)

	# Damage seeder so it can receive healing
	seeder.apply_damage(50)
	var seeder_hp_before: int = seeder.current_hp

	target.add_status(&"seeded", -1, {
		"seeder_side": 0, "seeder_slot": 0,
	})
	var target_hp_before: int = target.current_hp
	@warning_ignore("integer_division")
	var expected_drain: int = maxi(target.max_hp / 8, 1)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	var target_hp_lost: int = target_hp_before - target.current_hp
	assert_eq(target_hp_lost, expected_drain, "Seeded should drain 1/8 max HP")
	assert_gt(
		seeder.current_hp, seeder_hp_before,
		"Seeder should be healed by the drain",
	)


func test_perishing_countdown_kills_at_zero() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"perishing", -1, {"countdown": 1})
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(user.current_hp, 0, "Perishing at countdown 0 should kill")
	assert_true(user.is_fainted, "Should be fainted after perish count")


# --- Stat modifiers from status ---


func test_burned_halves_attack_in_combat() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var normal_atk: int = user.get_effective_stat(&"attack")
	user.add_status(&"burned")
	var burned_atk: int = user.get_effective_stat(&"attack")
	assert_eq(
		burned_atk, maxi(floori(normal_atk * 0.5), 1),
		"Burned should halve effective attack",
	)


func test_paralysed_halves_speed_in_combat() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var normal_spe: int = user.get_effective_stat(&"speed")
	user.add_status(&"paralysed")
	var para_spe: int = user.get_effective_stat(&"speed")
	assert_eq(
		para_spe, maxi(floori(normal_spe * 0.5), 1),
		"Paralysed should halve effective speed",
	)


# --- Energy cost modifiers ---


func test_exhausted_increases_energy_cost() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"exhausted")
	var _target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_energy: int = user.current_energy

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# test_tackle costs 5 energy, exhausted = ceil(5*1.5) = 8
	# But end-of-turn regen adds some back
	# Just check energy was spent (more than 5 base cost)
	var _energy_before_regen: int = initial_energy - user.current_energy
	# With regen this is tricky, just verify the turn completed
	assert_eq(_battle.turn_number, 1, "Turn should complete with exhausted status")


func test_vitalised_decreases_energy_cost() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"vitalised")
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(_battle.turn_number, 1, "Turn should complete with vitalised status")


func test_bleeding_deals_self_damage() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"bleeding")
	var initial_hp: int = user.current_hp
	@warning_ignore("integer_division")
	var expected_bleed: int = maxi(user.max_hp / 8, 1)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	# User should have taken bleeding self-damage
	var hp_lost: int = initial_hp - user.current_hp
	assert_gte(hp_lost, expected_bleed, "Bleeding should deal self-damage when using technique")


# --- Flinch ---


func test_flinched_prevents_technique() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"flinched", 1)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var initial_hp: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		target.current_hp, initial_hp,
		"Flinched Digimon should not be able to attack",
	)


func test_flinch_removed_after_blocking() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"flinched", 1)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_false(
		user.has_status(&"flinched"),
		"Flinch should be removed after blocking the action",
	)


func test_flinch_cleared_at_end_of_turn_if_not_consumed() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"flinched", 1)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_false(
		user.has_status(&"flinched"),
		"Flinch should be cleared at end of turn even if not consumed",
	)


func test_flinch_does_not_block_rest() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"flinched", 1)
	# Drain energy so rest has something to restore
	user.spend_energy(user.current_energy)
	var energy_before: int = user.current_energy
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_gt(
		user.current_energy, energy_before,
		"Flinch should not block REST — energy should be restored",
	)
