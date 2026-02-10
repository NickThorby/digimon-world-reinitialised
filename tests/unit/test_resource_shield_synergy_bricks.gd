extends GutTest
## Tests for resource, shield, and synergy bricks.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Helper ---


func _create_battle(
	s0_key: StringName = &"test_agumon",
	s1_key: StringName = &"test_gabumon",
	seed: int = TestBattleFactory.DEFAULT_SEED,
) -> BattleState:
	return TestBattleFactory.create_1v1_battle(s0_key, s1_key, seed)


func _get_user(battle: BattleState) -> BattleDigimonState:
	return battle.sides[0].slots[0].digimon


func _get_target(battle: BattleState) -> BattleDigimonState:
	return battle.sides[1].slots[0].digimon


func _exec_brick(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
	execution_context: Dictionary = {},
) -> Dictionary:
	return BrickExecutor.execute_brick(
		brick, user, target, technique, battle, execution_context,
	)


# ===========================================================================
# resource
# ===========================================================================


func test_steal_item_transfers_gear() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	target.equipped_gear_key = &"test_power_band"
	user.equipped_gear_key = &""

	var brick: Dictionary = {"brick": "resource", "stealItem": true}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: Dictionary = _exec_brick(
		brick, user, target, technique, battle,
	)

	assert_eq(
		user.equipped_gear_key, &"test_power_band",
		"User should have stolen gear",
	)
	assert_eq(
		target.equipped_gear_key, &"",
		"Target should have no gear",
	)
	assert_false(
		result.get("resource_failed", false),
		"Should not fail",
	)


func test_remove_item_destroys_gear() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	target.equipped_gear_key = &"test_power_band"

	var brick: Dictionary = {"brick": "resource", "removeItem": true}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: Dictionary = _exec_brick(
		brick, user, target, technique, battle,
	)

	assert_eq(
		target.equipped_gear_key, &"",
		"Target gear should be removed",
	)
	assert_eq(
		result.get("resource_action", ""),
		"removeItem",
		"Action should be removeItem",
	)


func test_steal_fails_when_target_has_no_item() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	target.equipped_gear_key = &""
	user.equipped_gear_key = &""

	var brick: Dictionary = {"brick": "resource", "stealItem": true}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: Dictionary = _exec_brick(
		brick, user, target, technique, battle,
	)

	assert_true(
		result.get("resource_failed", false),
		"Should fail when target has no item",
	)


# ===========================================================================
# shield
# ===========================================================================


func test_endure_survives_lethal_damage() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Set up endure shield on target
	var shield_brick: Dictionary = {
		"brick": "shield", "type": "endure",
		"oncePerBattle": true, "breakOnHit": true,
	}
	var tech: TechniqueData = Atlas.techniques[&"test_tackle"]
	_exec_brick(shield_brick, target, user, tech, battle)

	# Deal lethal damage
	target.current_hp = 10
	var technique: TechniqueData = Atlas.techniques[&"test_expensive"]
	var result: Dictionary = BrickExecutor._apply_shielded_damage(
		target, 999, technique,
	)

	assert_true(result.get("endured", false), "Should endure")
	assert_eq(target.current_hp, 1, "Should survive with 1 HP")
	assert_false(target.is_fainted, "Should not be fainted")


func test_endure_once_per_battle() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# First use: should succeed
	var tech: TechniqueData = Atlas.techniques[&"test_tackle"]
	var shield_brick: Dictionary = {
		"brick": "shield", "type": "endure",
		"oncePerBattle": true, "breakOnHit": true,
	}
	var result1: Dictionary = _exec_brick(
		shield_brick, user, target, tech, battle,
	)
	assert_true(
		result1.get("shield_applied", false),
		"First use should succeed",
	)

	# Second use: should fail
	var result2: Dictionary = _exec_brick(
		shield_brick, user, target, tech, battle,
	)
	assert_true(
		result2.get("shield_failed", false),
		"Second use should fail",
	)


func test_hp_decoy_absorbs_damage() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Set up decoy on target (Substitute)
	var shield_brick: Dictionary = {
		"brick": "shield", "type": "hpDecoy",
		"hpCost": 0.25, "blocksStatus": true,
	}
	var tech: TechniqueData = Atlas.techniques[&"test_tackle"]
	var hp_before: int = target.current_hp
	_exec_brick(shield_brick, target, user, tech, battle)

	# Verify HP cost was paid
	assert_lt(target.current_hp, hp_before, "HP cost should be deducted")

	# Deal damage that decoy should absorb
	var result: Dictionary = BrickExecutor._apply_shielded_damage(
		target, 10, tech,
	)
	assert_true(result.get("shielded", false), "Should be shielded by decoy")
	assert_eq(result.get("actual_damage", -1), 0, "No HP damage to target")


func test_hp_decoy_blocks_status() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Set up decoy with blocksStatus on target
	target.add_shield({"type": "hpDecoy", "decoy_hp": 50, "blocks_status": true})

	# Try to apply burn status to target
	var status_brick: Dictionary = {
		"brick": "statusEffect", "status": "burned", "chance": 100,
	}
	var tech: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: Dictionary = _exec_brick(
		status_brick, user, target, tech, battle,
	)

	assert_true(
		result.get("blocked", false),
		"Status should be blocked by shield",
	)
	assert_eq(
		result.get("reason", ""),
		"shield_blocks_status",
		"Reason should be shield_blocks_status",
	)
	assert_false(
		target.has_status(&"burned"),
		"Target should not be burned",
	)


func test_intact_form_guard_blocks_first_hit() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Set up intactFormGuard on target (Disguise)
	target.add_shield({
		"type": "intactFormGuard", "break_on_hit": true,
	})

	var tech: TechniqueData = Atlas.techniques[&"test_tackle"]

	# First hit: should be blocked
	var result1: Dictionary = BrickExecutor._apply_shielded_damage(
		target, 50, tech,
	)
	assert_true(
		result1.get("shielded", false),
		"First hit should be blocked",
	)
	assert_eq(
		result1.get("actual_damage", -1), 0,
		"First hit should deal no damage",
	)

	# Second hit: should connect
	var hp_before: int = target.current_hp
	var result2: Dictionary = BrickExecutor._apply_shielded_damage(
		target, 50, tech,
	)
	assert_false(
		result2.get("shielded", false),
		"Second hit should not be blocked",
	)
	assert_lt(
		target.current_hp, hp_before,
		"Second hit should deal damage",
	)


func test_negate_move_class_blocks_physical() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Set up negateOneMoveClass (physical) on target
	target.add_shield({
		"type": "negateOneMoveClass", "move_class": "physical",
	})

	var physical_tech: TechniqueData = Atlas.techniques[&"test_tackle"]
	var special_tech: TechniqueData = Atlas.techniques[&"test_fire_blast"]

	# Physical hit: should be blocked
	var result1: Dictionary = BrickExecutor._apply_shielded_damage(
		target, 50, physical_tech,
	)
	assert_true(
		result1.get("shielded", false),
		"Physical hit should be blocked",
	)
	assert_eq(
		result1.get("shield_type", ""),
		"negateOneMoveClass",
		"Shield type should be negateOneMoveClass",
	)

	# Special hit: should not be blocked (shield already consumed)
	var hp_before: int = target.current_hp
	var result2: Dictionary = BrickExecutor._apply_shielded_damage(
		target, 50, special_tech,
	)
	assert_false(
		result2.get("shielded", false),
		"Special hit should not be blocked",
	)


func test_shields_clear_on_switch() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)

	user.add_shield({"type": "endure"})
	user.add_shield({"type": "hpDecoy", "decoy_hp": 50})
	assert_eq(
		(user.volatiles["shields"] as Array).size(), 2,
		"Should have 2 shields",
	)

	user.reset_volatiles()
	assert_eq(
		(user.volatiles["shields"] as Array).size(), 0,
		"Shields should be cleared on switch",
	)


# ===========================================================================
# synergy
# ===========================================================================


func test_follow_up_bonus_applies() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Set user's last technique to test_tackle (matches partner)
	user.volatiles["last_technique_key"] = &"test_tackle"

	var technique: TechniqueData = Atlas.techniques[
		&"test_synergy_followup"
	]
	var ctx: Dictionary = {"damage_dealt": 0, "technique_missed": false}

	# Execute synergy brick
	var synergy_brick: Dictionary = technique.bricks[0]
	var result: Dictionary = _exec_brick(
		synergy_brick, user, target, technique, battle, ctx,
	)

	assert_true(result.get("synergy_met", false), "Synergy should be met")
	assert_eq(
		int(ctx.get("bonus_power", 0)), 40,
		"Bonus power should be 40",
	)


func test_follow_up_no_bonus_when_different() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Set user's last technique to something else
	user.volatiles["last_technique_key"] = &"test_fire_blast"

	var technique: TechniqueData = Atlas.techniques[
		&"test_synergy_followup"
	]
	var ctx: Dictionary = {"damage_dealt": 0, "technique_missed": false}

	var synergy_brick: Dictionary = technique.bricks[0]
	var result: Dictionary = _exec_brick(
		synergy_brick, user, target, technique, battle, ctx,
	)

	assert_false(
		result.get("synergy_met", false),
		"Synergy should not be met",
	)
	assert_eq(
		int(ctx.get("bonus_power", 0)), 0,
		"No bonus power should be applied",
	)


func test_combo_bonus_from_target_hit() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Target was last hit by test_fire_blast
	target.volatiles["last_technique_hit_by"] = &"test_fire_blast"
	user.volatiles["last_technique_key"] = &""

	var technique: TechniqueData = Atlas.techniques[
		&"test_synergy_combo"
	]
	var ctx: Dictionary = {"damage_dealt": 0, "technique_missed": false}

	var synergy_brick: Dictionary = technique.bricks[0]
	var result: Dictionary = _exec_brick(
		synergy_brick, user, target, technique, battle, ctx,
	)

	assert_true(result.get("synergy_met", false), "Combo synergy should be met")
	assert_eq(
		int(ctx.get("bonus_power", 0)), 30,
		"Bonus power should be 30",
	)


func test_combo_bonus_from_user_last() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# User's last technique was test_fire_blast
	user.volatiles["last_technique_key"] = &"test_fire_blast"
	target.volatiles["last_technique_hit_by"] = &""

	var technique: TechniqueData = Atlas.techniques[
		&"test_synergy_combo"
	]
	var ctx: Dictionary = {"damage_dealt": 0, "technique_missed": false}

	var synergy_brick: Dictionary = technique.bricks[0]
	var result: Dictionary = _exec_brick(
		synergy_brick, user, target, technique, battle, ctx,
	)

	assert_true(result.get("synergy_met", false), "Combo synergy should be met")
	assert_eq(
		int(ctx.get("bonus_power", 0)), 30,
		"Bonus power should be 30",
	)
