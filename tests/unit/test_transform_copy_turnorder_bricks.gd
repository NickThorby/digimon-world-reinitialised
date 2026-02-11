extends GutTest
## Tests for session 7 bricks: useRandomTechnique, transform, copyTechnique,
## abilityManipulation, turnOrder.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Helpers ---


func _create_battle(
	s0_key: StringName = &"test_agumon",
	s1_key: StringName = &"test_gabumon",
	rng_seed: int = TestBattleFactory.DEFAULT_SEED,
) -> BattleState:
	return TestBattleFactory.create_1v1_battle(s0_key, s1_key, rng_seed)


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
# useRandomTechnique
# ===========================================================================


func test_use_random_technique_redirects() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_metronome"]
	var ctx: Dictionary = {}
	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle, ctx,
	)
	assert_true(result.get("handled", false), "Should be handled")
	assert_true(ctx.has("redirect_technique"), "Context should have redirect")
	# The redirected technique should be from user's equipped list (minus self)
	var redirect_key: StringName = ctx["redirect_technique"] as StringName
	assert_true(
		redirect_key in user.equipped_technique_keys,
		"Redirected technique should be in user's equipped list",
	)
	assert_ne(
		redirect_key, &"test_metronome",
		"Should not pick itself",
	)


func test_use_random_technique_excludes_self() -> void:
	# userKnownExceptThis should never return the current technique
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_metronome"]
	for i: int in range(20):
		battle.rng.seed = i * 1000
		var ctx: Dictionary = {}
		_exec_brick(technique.bricks[0], user, target, technique, battle, ctx)
		if ctx.has("redirect_technique"):
			assert_ne(
				ctx["redirect_technique"] as StringName,
				&"test_metronome",
				"Iteration %d: should never pick itself" % i,
			)


func test_use_random_technique_no_candidates_fails() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	# Empty equipped list
	user.equipped_technique_keys.clear()
	var technique: TechniqueData = Atlas.techniques[&"test_metronome"]
	var ctx: Dictionary = {}
	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle, ctx,
	)
	assert_true(
		result.get("redirect_failed", false),
		"Should fail when no candidates",
	)
	assert_eq(
		result.get("reason", ""), "no_candidates",
		"Reason should be no_candidates",
	)


func test_use_random_technique_limit_to_flags() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	# Give user only two techniques: one with CONTACT, one without
	user.equipped_technique_keys = [
		&"test_contact_tackle", &"test_fire_blast",
	] as Array[StringName]
	var brick: Dictionary = {
		"brick": "useRandomTechnique",
		"source": "userKnown",
		"limitToFlags": ["contact"],
	}
	# Run multiple times — should always pick the CONTACT technique
	for i: int in range(10):
		battle.rng.seed = i * 1000
		var ctx: Dictionary = {}
		_exec_brick(brick, user, target, null, battle, ctx)
		assert_eq(
			ctx.get("redirect_technique", &"") as StringName,
			&"test_contact_tackle",
			"Iteration %d: should only pick CONTACT-flagged technique" % i,
		)


func test_use_random_technique_limit_to_flags_no_match() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	# Give user only techniques without SOUND flag
	user.equipped_technique_keys = [
		&"test_tackle", &"test_fire_blast",
	] as Array[StringName]
	var brick: Dictionary = {
		"brick": "useRandomTechnique",
		"source": "userKnown",
		"limitToFlags": ["sound"],
	}
	var ctx: Dictionary = {}
	var result: Dictionary = _exec_brick(brick, user, target, null, battle, ctx)
	assert_true(
		result.get("redirect_failed", false),
		"Should fail when no techniques match the flag filter",
	)


# ===========================================================================
# transform
# ===========================================================================


func test_transform_copies_stats() -> void:
	# Partial transform: copy only atk and spa from target
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_partial_transform"]

	var original_def: int = user.base_stats.get(&"defence", 0)
	var original_spe: int = user.base_stats.get(&"speed", 0)

	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle,
	)
	assert_true(result.get("transformed", false), "Should transform")
	# atk and spa should match target's
	assert_eq(
		user.base_stats.get(&"attack", 0),
		target.base_stats.get(&"attack", 0),
		"Attack should be copied from target",
	)
	assert_eq(
		user.base_stats.get(&"special_attack", 0),
		target.base_stats.get(&"special_attack", 0),
		"Special attack should be copied from target",
	)
	# def and spe should be unchanged
	assert_eq(
		user.base_stats.get(&"defence", 0), original_def,
		"Defence should be unchanged",
	)
	assert_eq(
		user.base_stats.get(&"speed", 0), original_spe,
		"Speed should be unchanged",
	)


func test_transform_copies_techniques() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_full_transform"]
	_exec_brick(technique.bricks[0], user, target, technique, battle)
	assert_eq(
		user.equipped_technique_keys, target.equipped_technique_keys,
		"Equipped techniques should match target's",
	)


func test_transform_copies_ability() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_full_transform"]
	_exec_brick(technique.bricks[0], user, target, technique, battle)
	assert_eq(
		user.ability_key, target.ability_key,
		"Ability should match target's",
	)


func test_transform_stores_backup_and_restores() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_full_transform"]

	var original_atk: int = user.base_stats.get(&"attack", 0)
	var original_ability: StringName = user.ability_key
	var original_techs: Array[StringName] = \
		user.equipped_technique_keys.duplicate()

	_exec_brick(technique.bricks[0], user, target, technique, battle)

	# Backup should exist
	var backup: Variant = user.volatiles.get("transform_backup", {})
	assert_true(
		backup is Dictionary and not (backup as Dictionary).is_empty(),
		"Backup should be stored",
	)

	# Restore
	user.restore_transform()
	assert_eq(
		user.base_stats.get(&"attack", 0), original_atk,
		"Attack should be restored",
	)
	assert_eq(user.ability_key, original_ability, "Ability should be restored")
	assert_eq(
		user.equipped_technique_keys, original_techs,
		"Techniques should be restored",
	)


func test_transform_blocks_double_transform() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_full_transform"]

	# First transform
	_exec_brick(technique.bricks[0], user, target, technique, battle)
	# Second transform should fail
	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle,
	)
	assert_true(
		result.get("already_transformed", false),
		"Second transform should be blocked",
	)


# ===========================================================================
# copyTechnique
# ===========================================================================


func test_copy_technique_last_used_by_target() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	# Simulate target having used a technique
	target.volatiles["last_technique_key"] = &"test_ice_beam"
	var technique: TechniqueData = Atlas.techniques[&"test_mimic"]

	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	assert_eq(
		result.get("technique_copied", ""), "test_ice_beam",
		"Should copy ice beam",
	)
	assert_eq(
		user.equipped_technique_keys[3], &"test_ice_beam",
		"Slot 3 should be replaced with ice beam",
	)


func test_copy_technique_last_used_by_any() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	# Set battle-wide last technique used
	battle.last_technique_used_key = &"test_earthquake"
	var technique: TechniqueData = Atlas.techniques[&"test_sketch"]

	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle,
	)
	assert_eq(
		result.get("technique_copied", ""), "test_earthquake",
		"Should copy earthquake",
	)
	# Permanent: no entry in copied_technique_slots
	var slots: Variant = user.volatiles.get("copied_technique_slots", [])
	assert_true(
		(slots as Array).is_empty(),
		"Permanent copy should not store in copied_technique_slots",
	)


func test_copy_technique_random_from_target() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_copy_random"]

	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	var copied_key: StringName = StringName(result.get("technique_copied", ""))
	assert_true(
		copied_key in target.equipped_technique_keys,
		"Copied technique should be from target's equipped list",
	)


func test_copy_technique_no_technique_fails() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	# lastUsedByTarget with no last technique
	target.volatiles["last_technique_key"] = &""
	var technique: TechniqueData = Atlas.techniques[&"test_mimic"]

	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle,
	)
	assert_true(
		result.get("copy_failed", false),
		"Should fail when no technique to copy",
	)


# ===========================================================================
# abilityManipulation
# ===========================================================================


func test_ability_copy() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_ability_copy"]
	var original_user_ability: StringName = user.ability_key

	_exec_brick(technique.bricks[0], user, target, technique, battle)
	assert_eq(
		user.ability_key, target.ability_key,
		"User's ability should now match target's",
	)
	assert_eq(
		user.volatiles.get("ability_backup", &"") as StringName,
		original_user_ability,
		"User's original ability should be backed up",
	)


func test_ability_swap() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_ability_swap"]
	var original_user_ability: StringName = user.ability_key
	var original_target_ability: StringName = target.ability_key

	_exec_brick(technique.bricks[0], user, target, technique, battle)
	assert_eq(
		user.ability_key, original_target_ability,
		"User should have target's original ability",
	)
	assert_eq(
		target.ability_key, original_user_ability,
		"Target should have user's original ability",
	)


func test_ability_suppress() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_ability_suppress"]
	var original_target_ability: StringName = target.ability_key

	_exec_brick(technique.bricks[0], user, target, technique, battle)
	assert_eq(
		target.ability_key, &"",
		"Target's ability should be suppressed (empty)",
	)
	assert_eq(
		target.volatiles.get("ability_backup", &"") as StringName,
		original_target_ability,
		"Target's original ability should be backed up",
	)


func test_ability_restore_on_switch_out() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_ability_suppress"]
	var original_target_ability: StringName = target.ability_key

	_exec_brick(technique.bricks[0], user, target, technique, battle)
	assert_eq(target.ability_key, &"", "Ability should be suppressed")

	# Simulate switch-out (reset_volatiles restores ability)
	target.reset_volatiles()
	assert_eq(
		target.ability_key, original_target_ability,
		"Ability should be restored after switch-out",
	)


# ===========================================================================
# turnOrder
# ===========================================================================


func test_turn_order_move_next_result() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_after_you"]
	var ctx: Dictionary = {}

	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle, ctx,
	)
	assert_eq(
		result.get("turn_order_action", ""), "moveNext",
		"Should have moveNext action",
	)
	assert_eq(
		result.get("target_side", -1), target.side_index,
		"Should target correct side",
	)
	assert_true(
		ctx.has("turn_order_move_next"),
		"Context should have turn_order_move_next",
	)


func test_turn_order_move_last_result() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	var technique: TechniqueData = Atlas.techniques[&"test_quash"]
	var ctx: Dictionary = {}

	var result: Dictionary = _exec_brick(
		technique.bricks[0], user, target, technique, battle, ctx,
	)
	assert_eq(
		result.get("turn_order_action", ""), "moveLast",
		"Should have moveLast action",
	)
	assert_true(
		ctx.has("turn_order_move_last"),
		"Context should have turn_order_move_last",
	)


func test_turn_order_repeat_result() -> void:
	var battle: BattleState = _create_battle()
	var user: BattleDigimonState = _get_user(battle)
	var target: BattleDigimonState = _get_target(battle)
	# Set target's last used technique for repeat
	target.volatiles["last_technique_key"] = &"test_tackle"
	var brick: Dictionary = {
		"brick": "turnOrder", "type": "repeatTargetMove",
	}
	var ctx: Dictionary = {}

	var result: Dictionary = _exec_brick(
		brick, user, target, null, battle, ctx,
	)
	assert_eq(
		result.get("turn_order_action", ""), "repeat",
		"Should have repeat action",
	)
	assert_eq(
		result.get("technique_key", ""), "test_tackle",
		"Should reference target's last technique",
	)
	assert_true(
		ctx.has("turn_order_repeat"),
		"Context should have turn_order_repeat",
	)


# ===========================================================================
# Integration: turn order reordering in engine
# ===========================================================================


func test_turn_order_reorder_in_engine() -> void:
	# Create a 2v2 battle for 3+ actions
	var battle: BattleState = TestBattleFactory.create_2v2_battle()
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	# Side 0 slot 0 uses After You targeting side 1 slot 0
	# Side 0 slot 1 uses tackle (should go after the forced move)
	# Side 1 slot 0 uses tackle
	# Side 1 slot 1 uses tackle
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_after_you", 1, 0),
		TestBattleFactory.make_technique_action(0, 1, &"test_tackle", 1, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
		TestBattleFactory.make_technique_action(1, 1, &"test_tackle", 0, 0),
	]

	# Track action order via signal
	var resolved_order: Array[Dictionary] = []
	engine.action_resolved.connect(
		func(action: BattleAction, _results: Array[Dictionary]) -> void:
			resolved_order.append({
				"side": action.user_side, "slot": action.user_slot,
				"tech": action.technique_key,
			})
	)

	engine.execute_turn(actions)

	# Verify the turn executed without error
	assert_true(resolved_order.size() > 0, "Actions should have resolved")
