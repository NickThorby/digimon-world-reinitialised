extends GutTest
## Tests for session 6 bricks: elementModifier, resource, shield, synergy.


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
# elementModifier
# ===========================================================================


func test_change_technique_element_overrides_damage() -> void:
	# test_change_element: fire technique that deals ice damage
	# Gabumon resists ice (0.5) but is weak to fire (1.5)
	# With ice override, damage should use ice resistance (0.5) = less damage
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_change_element"]

	# Baseline: fire damage against gabumon (fire 1.5x = super effective)
	var baseline_tech: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var baseline: DamageResult = DamageCalculator.calculate_damage(
		user, target, baseline_tech, battle,
	)

	# With override: should use ice element (gabumon ice resist = 0.5)
	var ctx: Dictionary = {"damage_dealt": 0, "technique_missed": false}
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique.bricks, user, target, technique, battle,
	)

	# The element modifier brick should have been processed
	var damage_result: Dictionary = {}
	for r: Dictionary in results:
		if r.get("damage", 0) > 0:
			damage_result = r
	assert_true(
		damage_result.get("damage", 0) > 0,
		"Should deal some damage",
	)
	# Ice against gabumon (ice resist 0.5) should be not very effective
	assert_eq(
		damage_result.get("effectiveness", &""),
		&"not_very_effective",
		"Ice vs gabumon should be not very effective",
	)


func test_match_target_weakness_finds_weakness() -> void:
	# Use dual_mon vs dual_mon (both DATA, neutral attribute) to isolate
	# element effectiveness. dual_mon is weak to ice (1.5) and earth (1.5).
	var battle: BattleState = _create_battle(
		&"test_dual_mon", &"test_dual_mon",
	)
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_match_weakness"]

	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique.bricks, user, target, technique, battle,
	)

	# Check that the elementModifier brick found a weakness
	var modifier_result: Dictionary = {}
	for r: Dictionary in results:
		if r.has("matched_weakness"):
			modifier_result = r
	assert_true(
		modifier_result.has("matched_weakness"),
		"Should have matched a weakness",
	)

	var damage_result: Dictionary = {}
	for r: Dictionary in results:
		if r.get("damage", 0) > 0:
			damage_result = r
	assert_true(
		damage_result.get("damage", 0) > 0,
		"Should deal damage",
	)
	# With neutral attribute (DATA vs DATA) and weakness element (1.5x),
	# total_type_mult = 1.0 * 1.5 = 1.5 → super effective
	assert_eq(
		damage_result.get("effectiveness", &""),
		&"super_effective",
		"Should be super effective against target weakness",
	)


func test_add_element_grants_stab() -> void:
	# Agumon has [fire]. Add ice → now has [fire, ice]. Ice attack gets STAB.
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Before: ice NOT in user's elements
	assert_false(
		&"ice" in user.get_effective_element_traits(),
		"Agumon shouldn't have ice trait",
	)

	# Execute addElement brick
	var brick: Dictionary = {
		"brick": "elementModifier", "type": "addElement",
		"element": "ice", "target": "self",
	}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	_exec_brick(brick, user, target, technique, battle)

	# After: ice IN user's elements
	assert_true(
		&"ice" in user.get_effective_element_traits(),
		"User should now have ice trait",
	)

	# STAB check: ice attack should get STAB
	var balance: GameBalance = load(
		"res://data/config/game_balance.tres",
	) as GameBalance
	var stab: float = DamageCalculator.calculate_stab(
		&"ice", user, balance,
	)
	assert_gt(stab, 1.0, "Ice should now get STAB")


func test_remove_element_removes_stab() -> void:
	# Agumon has [fire]. Remove fire → no STAB on fire attack.
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Before: fire in user's elements
	assert_true(
		&"fire" in user.get_effective_element_traits(),
		"Agumon should have fire trait",
	)

	# Execute removeElement on user (targeting self)
	var brick: Dictionary = {
		"brick": "elementModifier", "type": "removeElement",
		"element": "fire", "target": "self",
	}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	_exec_brick(brick, user, target, technique, battle)

	# After: fire NOT in user's elements
	assert_false(
		&"fire" in user.get_effective_element_traits(),
		"Fire should be removed from user",
	)

	# STAB check: fire attack should NOT get STAB
	var balance: GameBalance = load(
		"res://data/config/game_balance.tres",
	) as GameBalance
	var stab: float = DamageCalculator.calculate_stab(
		&"fire", user, balance,
	)
	assert_eq(stab, 1.0, "Fire should no longer get STAB")


func test_replace_elements_replaces_all() -> void:
	# Agumon has [fire]. Replace all with dark.
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	# Replace target's elements
	var brick: Dictionary = {
		"brick": "elementModifier", "type": "replaceElements",
		"element": "dark", "target": "self",
	}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	_exec_brick(brick, user, target, technique, battle)

	var traits: Array[StringName] = user.get_effective_element_traits()
	assert_eq(traits.size(), 1, "Should have exactly one element")
	assert_eq(traits[0], &"dark", "Element should be dark")


func test_change_user_resistance_to_immune() -> void:
	# Agumon becomes immune to fire (0.0)
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	var brick: Dictionary = {
		"brick": "elementModifier",
		"type": "changeUserResistanceProfile",
		"element": "fire", "value": 0.0,
	}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	_exec_brick(brick, user, target, technique, battle)

	assert_eq(
		user.get_effective_resistance(&"fire"), 0.0,
		"User should be immune to fire",
	)


func test_change_target_resistance_to_weak() -> void:
	# Target becomes very weak to fire (2.0)
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)

	var brick: Dictionary = {
		"brick": "elementModifier",
		"type": "changeTargetResistanceProfile",
		"element": "fire", "value": 2.0,
	}
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	_exec_brick(brick, user, target, technique, battle)

	assert_eq(
		target.get_effective_resistance(&"fire"), 2.0,
		"Target should be very weak to fire",
	)


func test_element_modifiers_reset_on_switch() -> void:
	# All element volatiles clear on reset_volatiles()
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)

	# Set up various element modifiers
	(user.volatiles["element_traits_added"] as Array).append(&"ice")
	(user.volatiles["element_traits_removed"] as Array).append(&"fire")
	user.volatiles["element_traits_replaced"] = &"dark"
	user.volatiles["resistance_overrides"][&"fire"] = 0.0
	user.add_shield({"type": "endure"})

	# Reset
	user.reset_volatiles()

	assert_eq(
		(user.volatiles["element_traits_added"] as Array).size(), 0,
		"Added should be cleared",
	)
	assert_eq(
		(user.volatiles["element_traits_removed"] as Array).size(), 0,
		"Removed should be cleared",
	)
	assert_eq(
		user.volatiles["element_traits_replaced"], &"",
		"Replaced should be cleared",
	)
	assert_true(
		(user.volatiles["resistance_overrides"] as Dictionary).is_empty(),
		"Resistance overrides should be cleared",
	)
	assert_eq(
		(user.volatiles["shields"] as Array).size(), 0,
		"Shields should be cleared",
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
