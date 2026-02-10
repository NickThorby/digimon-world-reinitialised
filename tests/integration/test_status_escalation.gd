extends GutTest
## Integration tests for escalating status conditions (badly_burned, badly_poisoned).

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Badly burned escalating DoT ---


func test_badly_burned_deals_escalating_damage() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"badly_burned", -1, {"escalation_turn": 0})
	var max_hp: int = user.max_hp
	var fractions: Array[float] = Registry.ESCALATION_FRACTIONS

	for turn: int in 3:
		var hp_before: int = user.current_hp
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

		var expected_dot: int = maxi(floori(float(max_hp) * fractions[turn]), 1)
		var actual_damage: int = hp_before - user.current_hp
		assert_eq(
			actual_damage, expected_dot,
			"Turn %d: badly burned should deal %d damage (1/%d max HP)" % [
				turn, expected_dot, roundi(1.0 / fractions[turn]),
			],
		)


# --- Badly poisoned escalating DoT ---


func test_badly_poisoned_deals_escalating_damage() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"badly_poisoned", -1, {"escalation_turn": 0})
	var max_hp: int = user.max_hp
	var fractions: Array[float] = Registry.ESCALATION_FRACTIONS

	for turn: int in 3:
		var hp_before: int = user.current_hp
		var actions: Array[BattleAction] = [
			TestBattleFactory.make_rest_action(0, 0),
			TestBattleFactory.make_rest_action(1, 0),
		]
		_engine.execute_turn(actions)

		var expected_dot: int = maxi(floori(float(max_hp) * fractions[turn]), 1)
		var actual_damage: int = hp_before - user.current_hp
		assert_eq(
			actual_damage, expected_dot,
			"Turn %d: badly poisoned should deal %d damage" % [turn, expected_dot],
		)


# --- Escalation counter reset on switch ---


func test_escalation_resets_on_switch_out() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_gabumon"],
		[&"test_tank", &"test_patamon"],
	)
	var engine: BattleEngine = TestBattleFactory.create_engine(battle)

	var user: BattleDigimonState = battle.get_digimon_at(0, 0)
	user.add_status(&"badly_burned", -1, {"escalation_turn": 0})
	var max_hp: int = user.max_hp
	var fractions: Array[float] = Registry.ESCALATION_FRACTIONS

	# Turn 1: escalation_turn=0 → deals 1/16 max HP
	var hp_before: int = user.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)
	var t0_damage: int = hp_before - user.current_hp
	assert_eq(
		t0_damage, maxi(floori(float(max_hp) * fractions[0]), 1),
		"Turn 0 should deal 1/16 max HP",
	)

	# Turn 2: escalation_turn=1 → deals 1/8 max HP
	hp_before = user.current_hp
	actions = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)
	var t1_damage: int = hp_before - user.current_hp
	assert_eq(
		t1_damage, maxi(floori(float(max_hp) * fractions[1]), 1),
		"Turn 1 should deal 1/8 max HP",
	)

	# Switch out (reserve at index 0 in party)
	actions = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)

	# Record HP from source state before switching back in.
	# The switch-in turn's end-of-turn tick is the first tick after reset.
	var source_hp: int = battle.sides[0].party[0].current_hp

	# Switch back in (agumon is now in reserve at index 0)
	actions = [
		TestBattleFactory.make_switch_action(0, 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine.execute_turn(actions)

	# The returning mon should have badly_burned persisting through switch
	var returned: BattleDigimonState = battle.get_digimon_at(0, 0)
	assert_true(
		returned.has_status(&"badly_burned"),
		"Badly burned should persist through switch",
	)

	# The end-of-turn tick during the switch-in turn should deal 1/16 (reset)
	var returned_max_hp: int = returned.max_hp
	var post_switch_damage: int = source_hp - returned.current_hp
	assert_eq(
		post_switch_damage,
		maxi(floori(float(returned_max_hp) * fractions[0]), 1),
		"After switch back, escalation should reset to 1/16 max HP",
	)


# --- Badly burned halves ATK ---


func test_badly_burned_halves_attack() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var normal_atk: int = user.get_effective_stat(&"attack")
	user.add_status(&"badly_burned", -1, {"escalation_turn": 0})
	var burned_atk: int = user.get_effective_stat(&"attack")
	assert_eq(
		burned_atk, maxi(floori(normal_atk * 0.5), 1),
		"Badly burned should halve effective attack",
	)
