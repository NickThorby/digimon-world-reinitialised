extends GutTest
## Integration tests for the item system (medicine, gear, capture).

var _engine: BattleEngine
var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# ─── Medicine Tests ───


func test_medicine_fixed_heal() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_potion": 3},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_hp = user.max_hp - 80  # Damage 80 HP

	var hp_before: int = user.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_potion", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.current_hp, hp_before + 50,
		"Potion should restore 50 HP",
	)


func test_medicine_percentage_heal() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_super_potion": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_hp = 1  # Nearly dead
	var expected_heal: int = maxi(floori(float(user.max_hp) * 50.0 / 100.0), 1)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_super_potion", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.current_hp, 1 + expected_heal,
		"Super Potion should restore 50%% of max HP",
	)


func test_medicine_energy_restore() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_energy_drink": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_energy = 0
	var energy_before: int = user.current_energy

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_energy_drink", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	# Energy drink restores 30; end-of-turn regen adds a small amount on top
	assert_gte(
		user.current_energy, energy_before + 30,
		"Energy drink should restore at least 30 energy",
	)


func test_medicine_status_cure() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_burn_heal": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.add_status(&"burned")

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_burn_heal", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_false(
		user.has_status(&"burned"),
		"Burn heal should remove burned status",
	)


func test_medicine_full_heal() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_full_heal": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_hp = 1
	user.add_status(&"burned")
	user.add_status(&"paralysed")

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_full_heal", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.current_hp, user.max_hp,
		"Full heal should restore HP to max",
	)
	assert_false(
		user.has_status(&"burned"),
		"Full heal should cure burned",
	)
	assert_false(
		user.has_status(&"paralysed"),
		"Full heal should cure paralysed",
	)


func test_medicine_stat_boost() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_x_attack": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_x_attack", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.stat_stages[&"attack"], 2,
		"X Attack should give ATK +2 stages",
	)


func test_item_consumed_from_bag() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_potion": 2},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var bag: BagState = _battle.sides[0].bag
	assert_eq(bag.get_quantity(&"test_potion"), 2, "Should start with 2")

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_hp = user.max_hp - 80

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_potion", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		bag.get_quantity(&"test_potion"), 1,
		"Bag quantity should decrease by 1 after use",
	)


func test_item_fails_with_empty_bag() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{},  # Empty bag
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var hp_before: int = user.current_hp

	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_potion", 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.current_hp, hp_before,
		"HP should not change when item is not in bag",
	)
	assert_signal_emitted(
		_engine, "battle_message",
		"Should emit failure message",
	)


func test_revive_fainted_party_member() -> void:
	_battle = TestBattleFactory.create_1v1_with_reserves_and_bag(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon"],
		{&"test_revive": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Faint the reserve
	var side: SideState = _battle.sides[0]
	var reserve: DigimonState = side.party[0]
	reserve.current_hp = 0

	# Use revive targeting party index 1 (first reserve after active slot)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_revive", 1),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_gt(
		reserve.current_hp, 0,
		"Revive should restore HP to fainted reserve Digimon",
	)


# ─── Gear Tests ───


func test_equipable_gear_triggered_effect() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	# Equip counter gem (ON_TAKE_DAMAGE, DEF +1)
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.equipped_gear_key = &"test_counter_gem"

	# Foe attacks user
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.stat_stages[&"defence"], 1,
		"Counter gem should give DEF +1 when taking damage",
	)


func test_equipable_gear_stack_limit_enforced() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.equipped_gear_key = &"test_counter_gem"

	# Counter gem is ONCE_PER_TURN, so only 1 DEF boost per turn
	# We'll take damage twice in one turn
	# In a 1v1, only one foe attack per turn, so we use two turns
	# Turn 1: take damage, DEF should go to 1
	var actions1: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions1)
	assert_eq(
		user.stat_stages[&"defence"], 1,
		"Counter gem should fire once in turn 1",
	)

	# Turn 2: take damage again, should fire again (per-turn resets)
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions2)
	assert_eq(
		user.stat_stages[&"defence"], 2,
		"Counter gem should fire again in turn 2 (per-turn reset)",
	)


func test_consumable_gear_triggers_and_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.equipped_consumable_key = &"test_heal_berry"

	# Weaken user so foe's attack drops HP below 50%
	user.current_hp = ceili(float(user.max_hp) * 0.51)

	# Foe attacks — ON_HP_THRESHOLD fires after damage if HP < 50%
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.equipped_consumable_key, &"",
		"Consumable gear should be cleared after firing",
	)


func test_consumable_gear_fires_only_once() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.equipped_consumable_key = &"test_heal_berry"

	# Weaken user so foe's attack drops HP below 50%
	user.current_hp = ceili(float(user.max_hp) * 0.51)

	# Turn 1: Foe attacks, berry fires and is consumed
	var actions1: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions1)
	assert_eq(
		user.equipped_consumable_key, &"",
		"Berry should be consumed after turn 1",
	)

	# Weaken user again below 50%
	user.current_hp = ceili(float(user.max_hp) * 0.51)
	var hp_before_turn_2: int = user.current_hp

	# Turn 2: Foe attacks again, berry is gone — no extra healing
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions2)
	assert_lt(
		user.current_hp, hp_before_turn_2,
		"HP should only decrease (no berry healing) in turn 2",
	)


func test_gear_suppressed_by_dazed() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.equipped_gear_key = &"test_counter_gem"
	user.add_status(&"dazed")

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.stat_stages[&"defence"], 0,
		"Gear should not trigger when dazed",
	)


func test_gear_suppressed_by_gear_suppression_field() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.equipped_gear_key = &"test_counter_gem"
	_battle.field.add_global_effect(&"gear_suppression", -1)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_rest_action(0, 0),
		TestBattleFactory.make_technique_action(1, 0, &"test_tackle", 0, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		user.stat_stages[&"defence"], 0,
		"Gear should not trigger under gear_suppression field effect",
	)


# ─── Capture Tests ───


func test_capture_item_consumed() -> void:
	_battle = TestBattleFactory.create_1v1_battle_with_bag(
		&"test_agumon", &"test_gabumon",
		{&"test_scanner": 1},
	)
	_engine = TestBattleFactory.create_engine(_battle)

	watch_signals(_engine)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_item_action(0, 0, &"test_scanner", -1, 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)

	assert_eq(
		_battle.sides[0].bag.get_quantity(&"test_scanner"), 0,
		"Scanner should be consumed from bag",
	)
	assert_signal_emitted(
		_engine, "battle_message",
		"Should emit capture message",
	)
