extends GutTest
## Integration tests for BattleAI.

var _battle: BattleState
var _ai: BattleAI


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_ai = BattleAI.new()
	_ai.initialise(_battle)


# --- Basic action generation ---


func test_ai_generates_one_action_per_slot() -> void:
	var actions: Array[BattleAction] = _ai.generate_actions(1)
	assert_eq(actions.size(), 1, "AI should generate 1 action for 1 active slot")


func test_ai_generates_actions_for_2v2() -> void:
	var battle: BattleState = TestBattleFactory.create_2v2_battle()
	var ai := BattleAI.new()
	ai.initialise(battle)
	var actions: Array[BattleAction] = ai.generate_actions(1)
	assert_eq(actions.size(), 2, "AI should generate 2 actions for 2 active slots in 2v2")


func test_ai_picks_from_equipped_techniques() -> void:
	var actions: Array[BattleAction] = _ai.generate_actions(1)
	if actions.size() > 0 and actions[0].action_type == BattleAction.ActionType.TECHNIQUE:
		var tech_key: StringName = actions[0].technique_key
		var mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
		assert_true(
			mon.equipped_technique_keys.has(tech_key),
			"AI should pick from equipped techniques",
		)


# --- Constraint respect ---


func test_ai_respects_encore() -> void:
	var mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	mon.volatiles["encore_technique_key"] = &"test_tackle"
	var actions: Array[BattleAction] = _ai.generate_actions(1)
	if actions.size() > 0 and actions[0].action_type == BattleAction.ActionType.TECHNIQUE:
		assert_eq(
			actions[0].technique_key, &"test_tackle",
			"AI should use encored technique",
		)


func test_ai_respects_disable() -> void:
	var mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	mon.volatiles["disabled_technique_key"] = &"test_tackle"
	# Generate many times to check disabled technique is never picked
	for i: int in 20:
		var battle: BattleState = TestBattleFactory.create_1v1_battle(
			&"test_agumon", &"test_gabumon", i * 100,
		)
		battle.get_digimon_at(1, 0).volatiles["disabled_technique_key"] = &"test_tackle"
		var ai := BattleAI.new()
		ai.initialise(battle)
		var actions: Array[BattleAction] = ai.generate_actions(1)
		if actions.size() > 0 and actions[0].action_type == BattleAction.ActionType.TECHNIQUE:
			assert_ne(
				actions[0].technique_key, &"test_tackle",
				"AI should not pick disabled technique",
			)


func test_ai_respects_taunt() -> void:
	var mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	mon.add_status(&"taunted")
	for i: int in 20:
		var battle: BattleState = TestBattleFactory.create_1v1_battle(
			&"test_agumon", &"test_gabumon", i * 100,
		)
		battle.get_digimon_at(1, 0).add_status(&"taunted")
		var ai := BattleAI.new()
		ai.initialise(battle)
		var actions: Array[BattleAction] = ai.generate_actions(1)
		if actions.size() > 0 and actions[0].action_type == BattleAction.ActionType.TECHNIQUE:
			var tech: TechniqueData = Atlas.techniques.get(
				actions[0].technique_key,
			) as TechniqueData
			if tech:
				assert_ne(
					tech.technique_class, Registry.TechniqueClass.STATUS,
					"AI should not pick STATUS techniques when taunted",
				)


# --- Fallback to rest ---


func test_ai_falls_back_to_rest() -> void:
	# Remove all equipped techniques
	var mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	mon.equipped_technique_keys.clear()
	var actions: Array[BattleAction] = _ai.generate_actions(1)
	assert_eq(actions.size(), 1, "AI should still generate an action")
	assert_eq(
		actions[0].action_type, BattleAction.ActionType.REST,
		"AI should fall back to rest when no techniques available",
	)


# --- Fainted slots ---


func test_ai_skips_fainted_slots() -> void:
	var mon: BattleDigimonState = _battle.get_digimon_at(1, 0)
	mon.is_fainted = true
	var actions: Array[BattleAction] = _ai.generate_actions(1)
	assert_eq(actions.size(), 0, "AI should not generate actions for fainted slots")
