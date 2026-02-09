extends GutTest
## Unit tests for BattleDigimonState methods.

var _battle: BattleState
var _mon: BattleDigimonState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_mon = _battle.get_digimon_at(0, 0)


# --- apply_damage() ---


func test_apply_damage_reduces_hp() -> void:
	var initial_hp: int = _mon.current_hp
	var actual: int = _mon.apply_damage(10)
	assert_eq(actual, 10, "Should deal 10 damage")
	assert_eq(_mon.current_hp, initial_hp - 10, "HP should be reduced by 10")


func test_apply_damage_clamps_to_zero() -> void:
	var actual: int = _mon.apply_damage(99999)
	assert_eq(_mon.current_hp, 0, "HP should clamp to 0")
	assert_lte(actual, _mon.max_hp, "Actual damage should not exceed original HP")


func test_apply_damage_sets_fainted() -> void:
	_mon.apply_damage(99999)
	assert_true(_mon.is_fainted, "Should be fainted when HP reaches 0")


func test_apply_damage_zero_does_nothing() -> void:
	var initial_hp: int = _mon.current_hp
	_mon.apply_damage(0)
	assert_eq(_mon.current_hp, initial_hp, "Zero damage should not change HP")


# --- restore_hp() ---


func test_restore_hp_increases() -> void:
	_mon.apply_damage(50)
	var restored: int = _mon.restore_hp(30)
	assert_eq(restored, 30, "Should restore 30 HP")


func test_restore_hp_clamps_to_max() -> void:
	_mon.apply_damage(10)
	var restored: int = _mon.restore_hp(99999)
	assert_eq(restored, 10, "Should only restore up to max HP")
	assert_eq(_mon.current_hp, _mon.max_hp, "HP should be at max")


func test_restore_hp_at_full_returns_zero() -> void:
	var restored: int = _mon.restore_hp(50)
	assert_eq(restored, 0, "Restoring at full HP should return 0")


# --- spend_energy() ---


func test_spend_energy_success() -> void:
	var initial: int = _mon.current_energy
	var result: bool = _mon.spend_energy(5)
	assert_true(result, "Should return true when energy is sufficient")
	assert_eq(_mon.current_energy, initial - 5, "Energy should decrease by 5")


func test_spend_energy_overexertion() -> void:
	var result: bool = _mon.spend_energy(99999)
	assert_false(result, "Should return false when overexerting")
	assert_eq(_mon.current_energy, 0, "Energy should be set to 0 on overexertion")


func test_spend_energy_exact_amount() -> void:
	var initial: int = _mon.current_energy
	var result: bool = _mon.spend_energy(initial)
	assert_true(result, "Should return true when spending exact amount")
	assert_eq(_mon.current_energy, 0, "Energy should be exactly 0")


# --- restore_energy() ---


func test_restore_energy() -> void:
	_mon.spend_energy(_mon.current_energy)
	_mon.restore_energy(10)
	assert_eq(_mon.current_energy, 10, "Energy should be restored to 10")


func test_restore_energy_clamps_to_max() -> void:
	_mon.spend_energy(5)
	_mon.restore_energy(99999)
	assert_eq(_mon.current_energy, _mon.max_energy, "Energy should clamp to max")


# --- modify_stat_stage() ---


func test_stat_stage_positive_change() -> void:
	var actual: int = _mon.modify_stat_stage(&"attack", 2)
	assert_eq(actual, 2, "Should change by +2")
	assert_eq(_mon.stat_stages[&"attack"], 2, "Attack stage should be 2")


func test_stat_stage_negative_change() -> void:
	var actual: int = _mon.modify_stat_stage(&"speed", -3)
	assert_eq(actual, -3, "Should change by -3")
	assert_eq(_mon.stat_stages[&"speed"], -3, "Speed stage should be -3")


func test_stat_stage_clamps_at_positive_6() -> void:
	_mon.modify_stat_stage(&"attack", 6)
	var actual: int = _mon.modify_stat_stage(&"attack", 3)
	assert_eq(actual, 0, "Should not go above +6")
	assert_eq(_mon.stat_stages[&"attack"], 6, "Attack stage should remain 6")


func test_stat_stage_clamps_at_negative_6() -> void:
	_mon.modify_stat_stage(&"defence", -6)
	var actual: int = _mon.modify_stat_stage(&"defence", -2)
	assert_eq(actual, 0, "Should not go below -6")
	assert_eq(_mon.stat_stages[&"defence"], -6, "Defence stage should remain -6")


func test_stat_stage_partial_clamp() -> void:
	_mon.modify_stat_stage(&"speed", 5)
	var actual: int = _mon.modify_stat_stage(&"speed", 3)
	assert_eq(actual, 1, "Should only increase by 1 (5+1=6)")
	assert_eq(_mon.stat_stages[&"speed"], 6, "Speed stage should clamp at 6")


# --- get_effective_stat() ---


func test_effective_stat_at_stage_zero() -> void:
	var base_speed: int = _mon.base_stats.get(&"speed", 0)
	var effective: int = _mon.get_effective_stat(&"speed")
	assert_eq(effective, base_speed, "At stage 0, effective should equal base")


func test_effective_stat_with_positive_stage() -> void:
	var base_atk: int = _mon.base_stats.get(&"attack", 0)
	_mon.modify_stat_stage(&"attack", 2)
	var effective: int = _mon.get_effective_stat(&"attack")
	# Stage +2 = 2.0x
	assert_eq(effective, floori(base_atk * 2.0), "Stage +2 should double attack")


func test_effective_stat_with_negative_stage() -> void:
	var base_def: int = _mon.base_stats.get(&"defence", 0)
	_mon.modify_stat_stage(&"defence", -2)
	var effective: int = _mon.get_effective_stat(&"defence")
	# Stage -2 = 0.5x
	assert_eq(effective, floori(base_def * 0.5), "Stage -2 should halve defence")


# --- Status stat modifiers ---


func test_burned_halves_attack() -> void:
	var normal_atk: int = _mon.get_effective_stat(&"attack")
	_mon.add_status(&"burned")
	var burned_atk: int = _mon.get_effective_stat(&"attack")
	assert_eq(burned_atk, maxi(floori(normal_atk * 0.5), 1), "Burned should halve attack")


func test_frostbitten_halves_special_attack() -> void:
	var normal_spa: int = _mon.get_effective_stat(&"special_attack")
	_mon.add_status(&"frostbitten")
	var frost_spa: int = _mon.get_effective_stat(&"special_attack")
	assert_eq(
		frost_spa, maxi(floori(normal_spa * 0.5), 1),
		"Frostbitten should halve special attack",
	)


func test_paralysed_halves_speed() -> void:
	var normal_spe: int = _mon.get_effective_stat(&"speed")
	_mon.add_status(&"paralysed")
	var para_spe: int = _mon.get_effective_stat(&"speed")
	assert_eq(
		para_spe, maxi(floori(normal_spe * 0.5), 1),
		"Paralysed should halve speed",
	)


# --- add_status() / remove_status() / has_status() ---


func test_add_status() -> void:
	var added: bool = _mon.add_status(&"burned")
	assert_true(added, "Should successfully add status")
	assert_true(_mon.has_status(&"burned"), "Should have burned status")


func test_add_duplicate_status_fails() -> void:
	_mon.add_status(&"burned")
	var duplicate: bool = _mon.add_status(&"burned")
	assert_false(duplicate, "Should not add duplicate status")


func test_remove_status() -> void:
	_mon.add_status(&"burned")
	_mon.remove_status(&"burned")
	assert_false(_mon.has_status(&"burned"), "Should not have burned after removal")


func test_remove_nonexistent_status_safe() -> void:
	# Should not crash
	_mon.remove_status(&"burned")
	assert_false(_mon.has_status(&"burned"), "Removing nonexistent status should be safe")


func test_has_status_false_when_empty() -> void:
	assert_false(_mon.has_status(&"burned"), "Should not have status when none applied")


func test_add_status_with_duration() -> void:
	_mon.add_status(&"asleep", 3)
	assert_true(_mon.has_status(&"asleep"), "Should have asleep status")
	# Check the duration was stored
	for status: Dictionary in _mon.status_conditions:
		if status.get("key", &"") == &"asleep":
			assert_eq(int(status.get("duration", 0)), 3, "Duration should be 3")


func test_add_status_with_extra_data() -> void:
	_mon.add_status(&"seeded", -1, {"seeder_side": 1, "seeder_slot": 0})
	assert_true(_mon.has_status(&"seeded"), "Should have seeded status")
	for status: Dictionary in _mon.status_conditions:
		if status.get("key", &"") == &"seeded":
			assert_eq(int(status.get("seeder_side", -1)), 1, "Seeder side should be 1")
			assert_eq(int(status.get("seeder_slot", -1)), 0, "Seeder slot should be 0")


# --- reset_volatiles() ---


func test_reset_volatiles_resets_stages() -> void:
	_mon.modify_stat_stage(&"attack", 3)
	_mon.modify_stat_stage(&"speed", -2)
	_mon.reset_volatiles()
	assert_eq(_mon.stat_stages[&"attack"], 0, "Attack stage should reset to 0")
	assert_eq(_mon.stat_stages[&"speed"], 0, "Speed stage should reset to 0")


func test_reset_volatiles_preserves_charges() -> void:
	_mon.volatiles["charges"] = {"fire_charge": 2}
	_mon.reset_volatiles()
	assert_eq(
		_mon.volatiles.get("charges", {}), {"fire_charge": 2},
		"Charges should persist through reset_volatiles",
	)


func test_reset_volatiles_resets_per_switch_counter() -> void:
	_mon.ability_trigger_counts["per_switch"] = 1
	_mon.reset_volatiles()
	assert_eq(
		_mon.ability_trigger_counts.get("per_switch", 99), 0,
		"Per-switch trigger counter should reset",
	)


func test_reset_volatiles_resets_turns_on_field() -> void:
	_mon.volatiles["turns_on_field"] = 5
	_mon.reset_volatiles()
	assert_eq(
		int(_mon.volatiles.get("turns_on_field", 99)), 0,
		"Turns on field should reset",
	)


# --- Ability trigger stack limits ---


func test_can_trigger_unlimited() -> void:
	assert_true(
		_mon.can_trigger_ability(Registry.StackLimit.UNLIMITED),
		"Unlimited should always be able to trigger",
	)
	_mon.record_ability_trigger(Registry.StackLimit.UNLIMITED)
	assert_true(
		_mon.can_trigger_ability(Registry.StackLimit.UNLIMITED),
		"Unlimited should still be able to trigger after recording",
	)


func test_can_trigger_once_per_turn() -> void:
	assert_true(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_TURN),
		"Should be able to trigger before first use",
	)
	_mon.record_ability_trigger(Registry.StackLimit.ONCE_PER_TURN)
	assert_false(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_TURN),
		"Should not be able to trigger after first use this turn",
	)
	# Reset turn counter
	_mon.reset_turn_trigger_count()
	assert_true(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_TURN),
		"Should be able to trigger after turn reset",
	)


func test_can_trigger_once_per_switch() -> void:
	assert_true(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_SWITCH),
		"Should be able to trigger before first use",
	)
	_mon.record_ability_trigger(Registry.StackLimit.ONCE_PER_SWITCH)
	assert_false(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_SWITCH),
		"Should not trigger after first use this switch",
	)
	# Reset volatiles (simulates switch)
	_mon.reset_volatiles()
	assert_true(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_SWITCH),
		"Should be able to trigger after switch reset",
	)


func test_can_trigger_once_per_battle() -> void:
	assert_true(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_BATTLE),
		"Should be able to trigger before first use",
	)
	_mon.record_ability_trigger(Registry.StackLimit.ONCE_PER_BATTLE)
	assert_false(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_BATTLE),
		"Should not trigger after first use this battle",
	)
	# reset_volatiles should NOT reset per_battle
	_mon.reset_volatiles()
	assert_false(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_BATTLE),
		"Should remain blocked even after switch reset",
	)


func test_nullified_blocks_all_triggers() -> void:
	_mon.add_status(&"nullified")
	assert_false(
		_mon.can_trigger_ability(Registry.StackLimit.UNLIMITED),
		"Nullified should block all ability triggers",
	)
	assert_false(
		_mon.can_trigger_ability(Registry.StackLimit.ONCE_PER_TURN),
		"Nullified should block ONCE_PER_TURN trigger",
	)


# --- check_faint() ---


func test_check_faint_at_zero_hp() -> void:
	_mon.current_hp = 0
	var fainted: bool = _mon.check_faint()
	assert_true(fainted, "Should be fainted at 0 HP")
	assert_true(_mon.is_fainted, "is_fainted should be true")


func test_check_faint_above_zero() -> void:
	var fainted: bool = _mon.check_faint()
	assert_false(fainted, "Should not be fainted above 0 HP")
	assert_false(_mon.is_fainted, "is_fainted should be false")
