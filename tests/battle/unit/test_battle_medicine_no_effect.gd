extends GutTest
## Tests that medicine items are NOT consumed when they have no effect.

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# ─── Active Digimon: no effect ───


func test_potion_on_full_hp_active_not_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_potion": 2},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# User is already at full HP
	assert_eq(user.current_hp, user.max_hp, "Precondition: user at full HP")

	var bag: BagState = _battle.sides[0].bag
	watch_signals(_engine)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_potion", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		bag.get_quantity(&"test_potion"), 2,
		"Potion should NOT be consumed when used on full HP active Digimon",
	)
	assert_signal_emitted(
		_engine, "battle_message",
		"Should emit a no-effect message",
	)


func test_potion_on_damaged_active_is_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_potion": 2},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_hp = user.max_hp - 80

	var bag: BagState = _battle.sides[0].bag

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_potion", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		bag.get_quantity(&"test_potion"), 1,
		"Potion should be consumed when used on damaged active Digimon",
	)


# ─── Reserve Digimon: no effect ───


func test_potion_on_full_hp_reserve_not_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves_and_bag(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon"],
		{&"test_potion": 2},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Reserve is at full HP by default
	var side: SideState = _battle.sides[0]
	var reserve: DigimonState = side.party[0]
	assert_gt(reserve.current_hp, 0, "Precondition: reserve is alive")

	var bag: BagState = side.bag
	watch_signals(_engine)

	# Party index 1 = first reserve (index 0 is the active slot)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_potion", 1),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		bag.get_quantity(&"test_potion"), 2,
		"Potion should NOT be consumed on full HP reserve",
	)
	assert_signal_emitted(
		_engine, "battle_message",
		"Should emit a no-effect message",
	)


func test_potion_on_damaged_reserve_is_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves_and_bag(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon"],
		{&"test_potion": 2},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var side: SideState = _battle.sides[0]
	var reserve: DigimonState = side.party[0]
	reserve.current_hp = 10  # Damage the reserve

	var bag: BagState = side.bag

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_potion", 1),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		bag.get_quantity(&"test_potion"), 1,
		"Potion should be consumed on damaged reserve",
	)
	assert_gt(
		reserve.current_hp, 10,
		"Reserve HP should increase after potion",
	)


# ─── Revive on alive Digimon: no effect ───


func test_revive_on_alive_active_not_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_revive": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	assert_false(user.is_fainted, "Precondition: user is alive")

	var bag: BagState = _battle.sides[0].bag
	watch_signals(_engine)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_revive", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		bag.get_quantity(&"test_revive"), 1,
		"Revive should NOT be consumed on alive active Digimon",
	)


func test_revive_on_alive_reserve_not_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves_and_bag(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon"],
		{&"test_revive": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var side: SideState = _battle.sides[0]
	var reserve: DigimonState = side.party[0]
	assert_gt(reserve.current_hp, 0, "Precondition: reserve is alive")

	var bag: BagState = side.bag

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_revive", 1),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		bag.get_quantity(&"test_revive"), 1,
		"Revive should NOT be consumed on alive reserve Digimon",
	)
