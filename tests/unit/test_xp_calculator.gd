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
	var result: Dictionary = XPCalculator.apply_xp(state, 99999999)
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
