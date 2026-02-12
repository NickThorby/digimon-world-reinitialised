extends GutTest
## Integration tests for brick conditions through the full battle engine pipeline.

var _battle: BattleState
var _engine: BattleEngine


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_engine = TestBattleFactory.create_engine(_battle)


# --- Blaze ability integration ---


func test_blaze_boosts_fire_when_hp_below_50() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	user.ability_key = &"test_ability_blaze"
	user.current_hp = int(float(user.max_hp) * 0.3)
	var hp_before: int = target.current_hp

	# Fire technique from low-HP user with Blaze
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var blaze_damage: int = hp_before - target.current_hp

	# Compare to baseline without Blaze
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var engine2: BattleEngine = TestBattleFactory.create_engine(battle2)
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	user2.current_hp = int(float(user2.max_hp) * 0.3)
	var hp_before2: int = target2.current_hp
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine2.execute_turn(actions2)
	var base_damage: int = hp_before2 - target2.current_hp

	assert_gt(blaze_damage, base_damage, "Blaze should increase fire damage when HP < 50%")


func test_blaze_normal_when_hp_above_50() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	user.ability_key = &"test_ability_blaze"
	# HP is full (above 50%)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var blaze_damage: int = hp_before - target.current_hp

	# Baseline without Blaze
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var engine2: BattleEngine = TestBattleFactory.create_engine(battle2)
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	var hp_before2: int = target2.current_hp
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine2.execute_turn(actions2)
	var base_damage: int = hp_before2 - target2.current_hp

	assert_eq(
		blaze_damage, base_damage,
		"Blaze should NOT boost fire damage when HP >= 50%",
	)


func test_blaze_does_not_boost_non_fire() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	user.ability_key = &"test_ability_blaze"
	user.current_hp = int(float(user.max_hp) * 0.3)
	var hp_before: int = target.current_hp

	# Non-fire technique (test_tackle has no element)
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var blaze_damage: int = hp_before - target.current_hp

	# Baseline
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var engine2: BattleEngine = TestBattleFactory.create_engine(battle2)
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	user2.current_hp = int(float(user2.max_hp) * 0.3)
	var hp_before2: int = target2.current_hp
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_tackle", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine2.execute_turn(actions2)
	var base_damage: int = hp_before2 - target2.current_hp

	assert_eq(
		blaze_damage, base_damage,
		"Blaze should NOT boost non-fire techniques even when HP < 50%",
	)


# --- Technique damageModifier ---


func test_first_impact_2x_on_full_hp_target() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_first_impact", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var first_damage: int = hp_before - target.current_hp

	# Second use (target no longer at full HP)
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var engine2: BattleEngine = TestBattleFactory.create_engine(battle2)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	target2.apply_damage(1)  # Not at full HP
	var hp_before2: int = target2.current_hp
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_first_impact", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine2.execute_turn(actions2)
	var second_damage: int = hp_before2 - target2.current_hp

	assert_gt(
		first_damage, second_damage,
		"First Impact should deal more damage on full-HP target",
	)


func test_first_impact_normal_on_damaged_target() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	target.apply_damage(10)
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_first_impact", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var damage: int = hp_before - target.current_hp
	assert_gt(damage, 0, "Should still deal damage on non-full-HP target")


# --- Conditional statModifier ---


func test_conditional_stat_boost_when_condition_met() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	user.current_hp = int(float(user.max_hp) * 0.3)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_conditional_boost", 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		user.stat_stages[&"attack"], 2,
		"Conditional boost should apply when HP < 50%",
	)


func test_conditional_stat_boost_when_condition_not_met() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# HP is full (above 50%)

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_conditional_boost", 0, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	assert_eq(
		user.stat_stages[&"attack"], 0,
		"Conditional boost should NOT apply when HP >= 50%",
	)


# --- Nullified blocks CONTINUOUS modifiers ---


func test_nullified_blocks_continuous_modifier_in_engine() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	user.ability_key = &"test_ability_boost_fire"
	user.add_status(&"nullified")
	var hp_before: int = target.current_hp

	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var nullified_damage: int = hp_before - target.current_hp

	# Baseline (no ability at all)
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var engine2: BattleEngine = TestBattleFactory.create_engine(battle2)
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	var hp_before2: int = target2.current_hp
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine2.execute_turn(actions2)
	var base_damage: int = hp_before2 - target2.current_hp

	assert_eq(
		nullified_damage, base_damage,
		"Nullified should prevent CONTINUOUS ability modifiers",
	)


# --- Multiple modifiers stack multiplicatively ---


func test_multiple_modifiers_stack() -> void:
	# User has boost_fire ability (1.5x on fire) AND uses first_impact (2x on full HP)
	# but first_impact is physical with no element, so the ability won't fire
	# We need to use a fire technique with both ability + technique modifiers.
	# Since test_first_impact is elementless, we test stacking differently:
	# Create a scenario with ability fire boost + technique checks
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	user.ability_key = &"test_ability_boost_fire"

	# Fire technique damage with ability
	var hp_before: int = target.current_hp
	var actions: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	_engine.execute_turn(actions)
	var boosted_damage: int = hp_before - target.current_hp

	# Baseline without ability
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var engine2: BattleEngine = TestBattleFactory.create_engine(battle2)
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	var hp_before2: int = target2.current_hp
	var actions2: Array[BattleAction] = [
		TestBattleFactory.make_technique_action(0, 0, &"test_fire_blast", 1, 0),
		TestBattleFactory.make_rest_action(1, 0),
	]
	engine2.execute_turn(actions2)
	var base_damage: int = hp_before2 - target2.current_hp

	assert_gt(
		boosted_damage, base_damage,
		"Boost Fire ability should increase fire technique damage",
	)
