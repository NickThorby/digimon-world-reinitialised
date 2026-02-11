extends GutTest
## Integration tests for session 7 bricks: transform, copyTechnique,
## abilityManipulation, useRandomTechnique, and turnOrder.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Transform ---


func test_transform_persists_across_turns() -> void:
	# test_agumon (atk=100) transforms into test_gabumon (atk=55).
	# After transform, base_stats should reflect the target's stats.
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var target_atk: int = target.base_stats.get(&"attack", 0)

	# Turn 1: transform
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_full_transform", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.base_stats.get(&"attack", 0), target_atk,
		"User's attack should match target after full transform",
	)

	# Turn 2: rest — transformed stats should still be present
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)

	assert_eq(
		user.base_stats.get(&"attack", 0), target_atk,
		"Transformed stats should persist across turns (full transform = until switch)",
	)


func test_transform_duration_expires() -> void:
	# test_partial_transform has duration=3, copies atk and spa only.
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var original_atk: int = user.base_stats.get(&"attack", 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var target_atk: int = target.base_stats.get(&"attack", 0)

	# Turn 1: partial transform
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(
			0, 0, &"test_partial_transform", 1, 0,
		),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		user.base_stats.get(&"attack", 0), target_atk,
		"Attack should be copied after partial transform",
	)

	# Tick 3 turns to expire (duration decrements at end of each turn)
	for i: int in range(3):
		var rest: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest)

	assert_eq(
		user.base_stats.get(&"attack", 0), original_atk,
		"Attack should revert after transform duration expires",
	)


func test_transform_reverts_on_switch() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves()
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	var user: BattleDigimonState = battle.get_digimon_at(0, 0)
	var original_atk: int = user.base_stats.get(&"attack", 0)

	# Turn 1: full transform
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_full_transform", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)

	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	assert_eq(
		user.base_stats.get(&"attack", 0),
		target.base_stats.get(&"attack", 0),
		"Should be transformed",
	)

	# Turn 2: switch out (party_index 0 = first reserve = test_patamon)
	var switch_actions: Array[BattleAction] = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(switch_actions)

	# The switched-out Digimon's transform should have been reverted
	assert_eq(
		user.base_stats.get(&"attack", 0), original_atk,
		"Transform should revert on switch-out",
	)


# --- copyTechnique ---


func test_copied_technique_usable_next_turn() -> void:
	# test_mimic copies lastUsedByTarget into slot 3.
	# test_agumon (speed 80) is faster than test_gabumon (speed 60), so we
	# need the target to act first on a separate turn before mimicking.
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)

	# Turn 1: target uses tackle, user rests
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	# Turn 2: user mimics target's last technique
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_mimic", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)

	assert_eq(
		user.equipped_technique_keys[3], &"test_tackle",
		"Slot 3 should contain copied technique (test_tackle)",
	)

	# Turn 3: user can use the copied technique
	var target_hp_before: int = target.current_hp
	var actions_3: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_3)

	assert_lt(
		target.current_hp, target_hp_before,
		"Copied technique should deal damage when used next turn",
	)


func test_copied_technique_duration_expires() -> void:
	# test_mimic has duration=5. Target acts first, user mimics next turn,
	# then tick 5 turns to expire the copy.
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var original_slot3: StringName = user.equipped_technique_keys[3]

	# Turn 1: target uses tackle, user rests
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	# Turn 2: user mimics target's last technique
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_mimic", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)
	assert_eq(
		user.equipped_technique_keys[3], &"test_tackle",
		"Slot 3 should be replaced by copied technique",
	)

	# Tick 5 turns to expire the copy
	for i: int in range(5):
		var rest: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest)

	assert_eq(
		user.equipped_technique_keys[3], original_slot3,
		"Slot 3 should revert to original after copy duration expires",
	)


# --- abilityManipulation ---


func test_suppressed_ability_does_not_trigger() -> void:
	# Give target an observable ON_TURN_START ability, suppress it, verify no
	# further triggers. ON_TURN_START fires BEFORE actions, so the ability
	# triggers once on the same turn it gets suppressed.
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.ability_key = &"test_ability_on_turn_start_boost"

	# Turn 1: ON_TURN_START fires first (atk +1), then user suppresses
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_ability_suppress", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		target.ability_key, &"",
		"Target's ability should be suppressed (set to empty)",
	)
	var atk_after_suppress: int = target.stat_stages.get(&"attack", 0)
	assert_eq(
		atk_after_suppress, 1,
		"Ability should have triggered once before suppression this turn",
	)

	# Turn 2: ON_TURN_START should NOT fire (suppressed) — atk stays the same
	var actions_2: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions_2)

	assert_eq(
		target.stat_stages.get(&"attack", 0), atk_after_suppress,
		"Suppressed ability should not boost attack on subsequent turns",
	)


func test_ability_suppress_duration_expires() -> void:
	# test_ability_suppress has duration=3. Suppress, tick 3 turns, verify restored.
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.ability_key = &"test_ability_on_turn_start_boost"

	# Turn 1: suppress
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_ability_suppress", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(target.ability_key, &"", "Ability should be suppressed")

	# Tick 3 turns to expire
	for i: int in range(3):
		var rest: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(rest)

	assert_eq(
		target.ability_key, &"test_ability_on_turn_start_boost",
		"Ability should be restored after suppress duration expires",
	)


# --- useRandomTechnique ---


func test_metronome_executes_redirected_technique() -> void:
	# Metronome picks a random technique from user's known list (except itself).
	# We just verify the turn completes without error and the turn number advances.
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var _target_hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_metronome", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		_battle.turn_number, 1,
		"Turn should complete after metronome",
	)


# --- turnOrder ---


func test_quash_forces_target_last() -> void:
	# In 2v2, use Quash on a target to force them to act last.
	# Verify the quashed target's action resolves after the others.
	var battle: BattleState = TestBattleFactory.create_2v2_battle()
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	# Track action resolution order via signal
	var resolved_order: Array[Array] = []
	engine.action_resolved.connect(
		func(action: BattleAction, _results: Array[Dictionary]) -> void:
			resolved_order.append([action.user_side, action.user_slot]),
	)

	# Side 0 slot 0 quashes side 1 slot 0
	# Side 0 slot 1 rests, side 1 slot 0 tackles, side 1 slot 1 rests
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_quash", 1, 0),
		TestBattleFactory.make_rest_action(0, 1),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
		TestBattleFactory.make_rest_action(1, 1),
	]
	engine.execute_turn(actions)

	# The quashed target (side 1, slot 0) should be last in resolved order
	assert_gt(
		resolved_order.size(), 1,
		"Multiple actions should have resolved",
	)
	var last_resolved: Array = resolved_order[resolved_order.size() - 1]
	assert_eq(
		last_resolved, [1, 0] as Array,
		"Quashed target (1,0) should resolve last",
	)


# --- Bug fix verification ---


func test_last_technique_used_key_resets_between_turns() -> void:
	# Turn 1: use a technique — last_technique_used_key should be set
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		_battle.last_technique_used_key, &"test_tackle",
		"last_technique_used_key should be set after technique use",
	)

	# Turn 2: both rest — last_technique_used_key should reset at turn start
	var rest_actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(rest_actions)
	assert_eq(
		_battle.last_technique_used_key, &"",
		"last_technique_used_key should reset when no technique is used",
	)
