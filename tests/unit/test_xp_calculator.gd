extends GutTest
## Unit tests for XPCalculator formulas.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- calculate_xp_gain() ---


func test_basic_xp_gain() -> void:
	# base_yield=50, defeated_level=50, victor_level=50, participants=1
	var xp: int = XPCalculator.calculate_xp_gain(50, 50, 50, 1)
	assert_gt(xp, 0, "XP gain should be positive")


func test_xp_gain_scales_with_level_difference() -> void:
	# Higher level foe should give more XP
	var xp_same: int = XPCalculator.calculate_xp_gain(50, 50, 50, 1)
	var xp_higher: int = XPCalculator.calculate_xp_gain(50, 80, 50, 1)
	assert_gt(xp_higher, xp_same, "Higher level foe should give more XP")


func test_xp_gain_reduced_by_higher_victor_level() -> void:
	# Lower level foe should give less XP
	var xp_same: int = XPCalculator.calculate_xp_gain(50, 50, 50, 1)
	var xp_lower: int = XPCalculator.calculate_xp_gain(50, 50, 80, 1)
	assert_lt(xp_lower, xp_same, "Higher victor level should reduce XP gain")


func test_xp_split_among_participants() -> void:
	var xp_solo: int = XPCalculator.calculate_xp_gain(50, 50, 50, 1)
	var xp_split: int = XPCalculator.calculate_xp_gain(50, 50, 50, 2)
	assert_lt(xp_split, xp_solo, "XP should be split among participants")
	# With 2 participants, each gets roughly half
	@warning_ignore("integer_division")
	assert_between(
		xp_split, xp_solo / 3, xp_solo,
		"Split XP should be roughly half of solo XP",
	)


func test_xp_minimum_is_1() -> void:
	var xp: int = XPCalculator.calculate_xp_gain(1, 1, 100, 10)
	assert_gte(xp, 1, "XP gain should be at least 1")


# --- total_xp_for_level() ---


func test_xp_for_level_1_is_zero() -> void:
	var xp: int = XPCalculator.total_xp_for_level(1, Registry.GrowthRate.MEDIUM_FAST)
	assert_eq(xp, 0, "Level 1 requires 0 XP")


func test_xp_for_level_increases() -> void:
	var xp_10: int = XPCalculator.total_xp_for_level(10, Registry.GrowthRate.MEDIUM_FAST)
	var xp_50: int = XPCalculator.total_xp_for_level(50, Registry.GrowthRate.MEDIUM_FAST)
	var xp_100: int = XPCalculator.total_xp_for_level(100, Registry.GrowthRate.MEDIUM_FAST)
	assert_gt(xp_50, xp_10, "Higher levels should require more XP")
	assert_gt(xp_100, xp_50, "Level 100 should require more XP than level 50")


func test_medium_fast_formula() -> void:
	# MEDIUM_FAST: n^3
	var xp: int = XPCalculator.total_xp_for_level(10, Registry.GrowthRate.MEDIUM_FAST)
	assert_eq(xp, 1000, "Level 10 MEDIUM_FAST should be 10^3 = 1000")


func test_fast_formula() -> void:
	# FAST: 4*n^3/5
	var xp: int = XPCalculator.total_xp_for_level(10, Registry.GrowthRate.FAST)
	assert_eq(xp, 800, "Level 10 FAST should be 4*1000/5 = 800")


func test_slow_formula() -> void:
	# SLOW: 5*n^3/4
	var xp: int = XPCalculator.total_xp_for_level(10, Registry.GrowthRate.SLOW)
	assert_eq(xp, 1250, "Level 10 SLOW should be 5*1000/4 = 1250")


func test_growth_rate_ordering() -> void:
	# At level 50, FAST < MEDIUM_FAST < SLOW
	var fast: int = XPCalculator.total_xp_for_level(50, Registry.GrowthRate.FAST)
	var medium_fast: int = XPCalculator.total_xp_for_level(50, Registry.GrowthRate.MEDIUM_FAST)
	var slow: int = XPCalculator.total_xp_for_level(50, Registry.GrowthRate.SLOW)
	assert_lt(fast, medium_fast, "FAST should require less XP than MEDIUM_FAST")
	assert_lt(medium_fast, slow, "MEDIUM_FAST should require less XP than SLOW")


# --- apply_xp() / level-up ---


func test_apply_xp_no_level_up() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 5)
	state.experience = 0
	var result: Dictionary = XPCalculator.apply_xp(state, 10)
	assert_eq(int(result["levels_gained"]), 0, "Small XP should not cause level up")


func test_apply_xp_causes_level_up() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 5)
	# XP needed for level 6 MEDIUM_FAST: 6^3 = 216
	state.experience = 200
	var result: Dictionary = XPCalculator.apply_xp(state, 500)
	assert_gt(int(result["levels_gained"]), 0, "Sufficient XP should cause level up")
	assert_gt(state.level, 5, "Level should increase after level up")


func test_apply_xp_multi_level_up() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 1)
	state.experience = 0
	# Give enormous XP to jump many levels
	var result: Dictionary = XPCalculator.apply_xp(state, 1000000)
	assert_gt(int(result["levels_gained"]), 5, "Large XP should cause multiple level ups")


func test_apply_xp_max_level_cap() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 99)
	state.experience = XPCalculator.total_xp_for_level(99, Registry.GrowthRate.MEDIUM_FAST)
	var _result: Dictionary = XPCalculator.apply_xp(state, 99999999)
	assert_lte(state.level, 100, "Level should not exceed max level (100)")


func test_level_up_learns_technique() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 9)
	state.experience = XPCalculator.total_xp_for_level(9, Registry.GrowthRate.MEDIUM_FAST)
	state.known_technique_keys.clear()
	state.equipped_technique_keys.clear()
	# Level 10 should learn test_level_10_tech
	var xp_needed: int = XPCalculator.total_xp_for_level(
		10, Registry.GrowthRate.MEDIUM_FAST,
	) - state.experience + 1
	var result: Dictionary = XPCalculator.apply_xp(state, xp_needed)
	assert_gte(state.level, 10, "Should reach level 10")
	var new_techs: Array = result.get("new_techniques", [])
	assert_has(
		new_techs, &"test_level_10_tech",
		"Should learn test_level_10_tech at level 10",
	)


# --- xp_to_next_level() ---


func test_xp_to_next_level() -> void:
	var needed: int = XPCalculator.xp_to_next_level(
		10, 500, Registry.GrowthRate.MEDIUM_FAST,
	)
	# Level 11 MEDIUM_FAST = 11^3 = 1331, minus 500 current = 831
	assert_eq(needed, 831, "XP to next level should be 1331 - 500 = 831")


func test_xp_to_next_level_already_enough() -> void:
	var needed: int = XPCalculator.xp_to_next_level(
		10, 99999, Registry.GrowthRate.MEDIUM_FAST,
	)
	assert_eq(needed, 0, "Should return 0 when already have enough XP")


# --- calculate_xp_awards() with retired Digimon / EXP Share ---


func _make_won_battle_with_switch() -> BattleState:
	## Build a 1v1 with reserves. Side 0 starts with agumon, switches to patamon.
	## Side 1 gabumon faints. Side 0 wins.
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon"],
	)
	# Agumon participates against gabumon
	var agumon: BattleDigimonState = battle.sides[0].slots[0].digimon
	var gabumon_source: DigimonState = battle.sides[1].slots[0].digimon.source_state
	agumon.participated_against.append(gabumon_source)
	# Simulate switching agumon out for patamon
	TestBattleFactory.simulate_switch_out(battle, 0, 0)
	# Put patamon in the slot from party
	var patamon_state: DigimonState = battle.sides[0].party[0]
	battle.sides[0].party.remove_at(0)
	var patamon: BattleDigimonState = BattleFactory.create_battle_digimon(
		patamon_state, 0, 0,
	)
	battle.sides[0].slots[0].digimon = patamon
	# Gabumon faints
	battle.sides[1].slots[0].digimon.current_hp = 0
	battle.sides[1].slots[0].digimon.is_fainted = true
	# End battle — side 0 (team 0) wins
	battle.is_battle_over = true
	battle.result = BattleResult.new()
	battle.result.outcome = BattleResult.Outcome.WIN
	battle.result.winning_team = 0
	battle.result.turn_count = 3
	return battle


func test_switched_out_digimon_gets_xp() -> void:
	var battle: BattleState = _make_won_battle_with_switch()
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(battle)
	# Agumon was retired but participated — should get XP
	var agumon_award: Dictionary = {}
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state != null and state.key == &"test_agumon":
			agumon_award = award
			break
	assert_gt(int(agumon_award.get("xp", 0)), 0,
		"Switched-out Digimon with participation should get XP")


func test_non_participant_no_xp_without_exp_share() -> void:
	var battle: BattleState = _make_won_battle_with_switch()
	# Patamon did NOT participate (no entries in participated_against)
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle, false,
	)
	var patamon_found: bool = false
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state != null and state.key == &"test_patamon":
			patamon_found = true
	assert_false(patamon_found,
		"Non-participant should get no XP without EXP Share")


func test_non_participant_half_xp_with_exp_share() -> void:
	var battle: BattleState = _make_won_battle_with_switch()
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle, true,
	)
	var agumon_xp: int = 0
	var patamon_xp: int = 0
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state == null:
			continue
		if state.key == &"test_agumon":
			agumon_xp = int(award.get("xp", 0))
		elif state.key == &"test_patamon":
			patamon_xp = int(award.get("xp", 0))
	assert_gt(patamon_xp, 0,
		"Non-participant should get XP with EXP Share")
	assert_lt(patamon_xp, agumon_xp,
		"Non-participant XP should be less than participant XP")


func test_multi_side_uses_winning_team() -> void:
	# 3-way FFA: side 0 (team 0), side 1 (team 1), side 2 (team 2)
	var battle: BattleState = TestBattleFactory.create_3_way_ffa_battle()
	# Side 1 defeats sides 0 and 2
	var side1_mon: BattleDigimonState = battle.sides[1].slots[0].digimon
	side1_mon.participated_against.append(battle.sides[0].slots[0].digimon.source_state)
	side1_mon.participated_against.append(battle.sides[2].slots[0].digimon.source_state)
	# Faint side 0 and side 2
	battle.sides[0].slots[0].digimon.current_hp = 0
	battle.sides[0].slots[0].digimon.is_fainted = true
	battle.sides[2].slots[0].digimon.current_hp = 0
	battle.sides[2].slots[0].digimon.is_fainted = true
	# Side 1 (team 1) wins
	battle.is_battle_over = true
	battle.result = BattleResult.new()
	battle.result.outcome = BattleResult.Outcome.LOSS
	battle.result.winning_team = 1
	battle.result.turn_count = 5
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(battle)
	# Only side 1's Digimon should get XP
	assert_eq(awards.size(), 1,
		"Only winning side should get XP in FFA")
	var winner_state: DigimonState = awards[0].get(
		"digimon_state",
	) as DigimonState
	assert_eq(winner_state.key, &"test_gabumon",
		"Side 1's Digimon should be the XP recipient")


func test_count_participants_includes_retired() -> void:
	var battle: BattleState = _make_won_battle_with_switch()
	# Both agumon (retired) and patamon (active) participated against gabumon
	var gabumon_source: DigimonState = \
		battle.sides[1].slots[0].digimon.source_state
	battle.sides[0].slots[0].digimon.participated_against.append(
		gabumon_source,
	)
	# Use the internal method via calculate_xp_awards result:
	# If retired counts, participant count = 2, so each gets ~half XP
	var awards_split: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle,
	)
	# Agumon solo from fresh battle
	var fresh: BattleState = TestBattleFactory.create_1v1_battle()
	fresh.sides[0].slots[0].digimon.participated_against.append(
		fresh.sides[1].slots[0].digimon.source_state,
	)
	fresh.sides[1].slots[0].digimon.current_hp = 0
	fresh.sides[1].slots[0].digimon.is_fainted = true
	fresh.is_battle_over = true
	fresh.result = BattleResult.new()
	fresh.result.outcome = BattleResult.Outcome.WIN
	fresh.result.winning_team = 0
	fresh.result.turn_count = 1
	var awards_solo: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		fresh,
	)
	# With 2 participants, each should get less than solo
	if awards_split.size() > 0 and awards_solo.size() > 0:
		var split_xp: int = int(awards_split[0].get("xp", 0))
		var solo_xp: int = int(awards_solo[0].get("xp", 0))
		assert_lt(split_xp, solo_xp,
			"XP should be split when retired Digimon is counted as participant")


func test_awards_include_old_level_and_stats() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle()
	var mon: BattleDigimonState = battle.sides[0].slots[0].digimon
	mon.participated_against.append(battle.sides[1].slots[0].digimon.source_state)
	battle.sides[1].slots[0].digimon.current_hp = 0
	battle.sides[1].slots[0].digimon.is_fainted = true
	battle.is_battle_over = true
	battle.result = BattleResult.new()
	battle.result.outcome = BattleResult.Outcome.WIN
	battle.result.winning_team = 0
	battle.result.turn_count = 1
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(battle)
	assert_gt(awards.size(), 0, "Should have at least one award")
	var award: Dictionary = awards[0]
	assert_true(award.has("old_level"), "Award should include old_level")
	assert_true(award.has("old_experience"), "Award should include old_experience")
	assert_true(award.has("old_stats"), "Award should include old_stats")
	assert_true(award.has("participated"), "Award should include participated")
	assert_true(award["participated"] as bool, "Should be marked as participant")


func test_fainted_ally_gets_no_xp() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon"],
	)
	# Agumon participated and is fainted
	var agumon: BattleDigimonState = battle.sides[0].slots[0].digimon
	var gabumon_source: DigimonState = \
		battle.sides[1].slots[0].digimon.source_state
	agumon.participated_against.append(gabumon_source)
	agumon.current_hp = 0
	agumon.is_fainted = true
	# Patamon from reserve takes over (simulate switch-in)
	TestBattleFactory.simulate_switch_out(battle, 0, 0)
	var patamon_state: DigimonState = battle.sides[0].party[0]
	battle.sides[0].party.remove_at(0)
	var patamon: BattleDigimonState = BattleFactory.create_battle_digimon(
		patamon_state, 0, 0,
	)
	patamon.participated_against.append(gabumon_source)
	battle.sides[0].slots[0].digimon = patamon
	# Gabumon faints
	battle.sides[1].slots[0].digimon.current_hp = 0
	battle.sides[1].slots[0].digimon.is_fainted = true
	battle.is_battle_over = true
	battle.result = BattleResult.new()
	battle.result.outcome = BattleResult.Outcome.WIN
	battle.result.winning_team = 0
	battle.result.turn_count = 2
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle, true,
	)
	# Agumon is fainted — should NOT get XP even with EXP Share
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state != null:
			assert_ne(state.key, &"test_agumon",
				"Fainted ally should not receive XP")


# --- 2v2 XP after fainted cleared ---


# --- Party reserve EXP Share ---


func _make_won_battle_with_reserve() -> BattleState:
	## Build a 1v1 with reserves. Side 0: Agumon (active, participated), Patamon
	## (party reserve, never entered). Side 1: Gabumon (fainted). Side 0 wins.
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon"],
	)
	var agumon: BattleDigimonState = battle.sides[0].slots[0].digimon
	var gabumon_source: DigimonState = battle.sides[1].slots[0].digimon.source_state
	agumon.participated_against.append(gabumon_source)
	battle.sides[1].slots[0].digimon.current_hp = 0
	battle.sides[1].slots[0].digimon.is_fainted = true
	battle.is_battle_over = true
	battle.result = BattleResult.new()
	battle.result.outcome = BattleResult.Outcome.WIN
	battle.result.winning_team = 0
	battle.result.turn_count = 2
	return battle


func test_party_reserve_gets_exp_share_xp() -> void:
	var battle: BattleState = _make_won_battle_with_reserve()
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle, true,
	)
	var patamon_xp: int = 0
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state != null and state.key == &"test_patamon":
			patamon_xp = int(award.get("xp", 0))
			assert_false(
				award.get("participated", true) as bool,
				"Reserve should be marked as non-participant",
			)
	assert_gt(patamon_xp, 0,
		"Party reserve should get XP with EXP Share enabled")


func test_party_reserve_no_xp_without_exp_share() -> void:
	var battle: BattleState = _make_won_battle_with_reserve()
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle, false,
	)
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state != null:
			assert_ne(state.key, &"test_patamon",
				"Party reserve should get no XP without EXP Share")


func test_fainted_party_reserve_no_xp_with_exp_share() -> void:
	var battle: BattleState = _make_won_battle_with_reserve()
	# Faint Patamon in the party reserve
	for reserve: DigimonState in battle.sides[0].party:
		if reserve.key == &"test_patamon":
			reserve.current_hp = 0
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle, true,
	)
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state != null:
			assert_ne(state.key, &"test_patamon",
				"Fainted party reserve should not get XP even with EXP Share")


func test_party_reserve_xp_is_half_of_full() -> void:
	var battle: BattleState = _make_won_battle_with_reserve()
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(
		battle, true,
	)
	var agumon_xp: int = 0
	var patamon_xp: int = 0
	for award: Dictionary in awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state == null:
			continue
		if state.key == &"test_agumon":
			agumon_xp = int(award.get("xp", 0))
		elif state.key == &"test_patamon":
			patamon_xp = int(award.get("xp", 0))
	assert_gt(agumon_xp, 0, "Agumon (participant) should get XP")
	assert_gt(patamon_xp, 0, "Patamon (reserve) should get XP")
	# Reserve gets 50% of base (unsplit), participant gets full (split by 1)
	# So reserve XP should be roughly half of participant XP
	@warning_ignore("integer_division")
	var expected_half: int = agumon_xp / 2
	assert_between(patamon_xp, maxi(expected_half - 1, 1), expected_half + 1,
		"Reserve XP should be ~50%% of participant XP")


func test_2v2_xp_awarded_after_fainted_cleared() -> void:
	## In 2v2 battles, fainted foes with no reserves are cleared from slots.
	## XP must still be awarded via retired_battle_digimon.
	var battle: BattleState = TestBattleFactory.create_2v2_battle(
		[&"test_agumon", &"test_patamon"],
		[&"test_gabumon", &"test_tank"],
	)
	var agumon: BattleDigimonState = battle.sides[0].slots[0].digimon
	var patamon: BattleDigimonState = battle.sides[0].slots[1].digimon
	var gabumon: BattleDigimonState = battle.sides[1].slots[0].digimon
	var tank: BattleDigimonState = battle.sides[1].slots[1].digimon
	# Both allies participate against both foes
	agumon.participated_against.append(gabumon.source_state)
	agumon.participated_against.append(tank.source_state)
	patamon.participated_against.append(gabumon.source_state)
	patamon.participated_against.append(tank.source_state)
	# Faint both foes
	gabumon.current_hp = 0
	gabumon.is_fainted = true
	tank.current_hp = 0
	tank.is_fainted = true
	# Simulate _clear_fainted_no_reserve: retire then null (multi-slot, no reserves)
	var foe_side: SideState = battle.sides[1]
	for slot: SlotState in foe_side.slots:
		if slot.digimon != null and slot.digimon.is_fainted:
			foe_side.retired_battle_digimon.append(slot.digimon)
			slot.digimon = null
	# End battle
	battle.is_battle_over = true
	battle.result = BattleResult.new()
	battle.result.outcome = BattleResult.Outcome.WIN
	battle.result.winning_team = 0
	battle.result.turn_count = 3
	var awards: Array[Dictionary] = XPCalculator.calculate_xp_awards(battle)
	# Both allies should receive XP
	assert_eq(awards.size(), 2, "Both allies should receive XP in 2v2")
	for award: Dictionary in awards:
		assert_gt(int(award.get("xp", 0)), 0,
			"Each ally should receive positive XP")
