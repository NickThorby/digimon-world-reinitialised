extends GutTest
## Unit tests for StatCalculator pure functions.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- calculate_stat() ---


func test_base_formula_level_50() -> void:
	# FLOOR((((2 * 100 + 0 + 0) * 50) / 100)) + 50 + 10
	# = FLOOR(((200 * 50) / 100)) + 60
	# = FLOOR(100) + 60 = 160
	var result: int = StatCalculator.calculate_stat(100, 0, 0, 50)
	assert_eq(result, 160, "Base=100, IV=0, TV=0, Level=50 should equal 160")


func test_formula_with_ivs() -> void:
	# FLOOR((((2*100 + 25 + 0) * 50) / 100)) + 60
	# = FLOOR(((225 * 50) / 100)) + 60
	# = FLOOR(112.5) + 60 = 112 + 60 = 172
	var result: int = StatCalculator.calculate_stat(100, 25, 0, 50)
	assert_eq(result, 172, "Base=100, IV=25, TV=0, Level=50 should equal 172")


func test_formula_with_tvs() -> void:
	# FLOOR((((2*100 + 0 + 500/5) * 50) / 100)) + 60
	# = FLOOR((((200 + 100) * 50) / 100)) + 60
	# = FLOOR(150) + 60 = 210
	var result: int = StatCalculator.calculate_stat(100, 0, 500, 50)
	assert_eq(result, 210, "Base=100, IV=0, TV=500, Level=50 should equal 210")


func test_formula_with_ivs_and_tvs() -> void:
	# FLOOR((((2*100 + 50 + 500/5) * 50) / 100)) + 60
	# = FLOOR((((200 + 50 + 100) * 50) / 100)) + 60
	# = FLOOR(175) + 60 = 235
	var result: int = StatCalculator.calculate_stat(100, 50, 500, 50)
	assert_eq(result, 235, "Base=100, IV=50, TV=500, Level=50 should equal 235")


func test_level_1() -> void:
	# FLOOR((((200 + 0 + 0) * 1) / 100)) + 1 + 10
	# = FLOOR(2.0) + 11 = 2 + 11 = 13
	var result: int = StatCalculator.calculate_stat(100, 0, 0, 1)
	assert_eq(result, 13, "Base=100, Level=1 should equal 13")


func test_level_100() -> void:
	# FLOOR((((200 + 0 + 0) * 100) / 100)) + 100 + 10
	# = FLOOR(200) + 110 = 310
	var result: int = StatCalculator.calculate_stat(100, 0, 0, 100)
	assert_eq(result, 310, "Base=100, Level=100 should equal 310")


func test_low_base_stat() -> void:
	# FLOOR((((2*10 + 0 + 0) * 50) / 100)) + 60
	# = FLOOR(10) + 60 = 70
	var result: int = StatCalculator.calculate_stat(10, 0, 0, 50)
	assert_eq(result, 70, "Base=10, Level=50 should equal 70")


func test_high_base_stat() -> void:
	# FLOOR((((2*255 + 0 + 0) * 50) / 100)) + 60
	# = FLOOR(255) + 60 = 315
	var result: int = StatCalculator.calculate_stat(255, 0, 0, 50)
	assert_eq(result, 315, "Base=255, Level=50 should equal 315")


# --- apply_personality() ---


func test_personality_neutral() -> void:
	var personality: PersonalityData = Atlas.personalities.get(
		&"test_neutral",
	) as PersonalityData
	# Neutral: boosted == reduced (both ATTACK), so multiplier is 1.0
	var result: int = StatCalculator.apply_personality(100, &"attack", personality)
	assert_eq(result, 100, "Neutral personality should not change attack")


func test_personality_boost() -> void:
	var personality: PersonalityData = Atlas.personalities.get(
		&"test_brave",
	) as PersonalityData
	# Brave: +10% ATK, -10% SPE
	var result: int = StatCalculator.apply_personality(100, &"attack", personality)
	assert_eq(result, 110, "Brave personality should boost attack by 10%")


func test_personality_reduction() -> void:
	var personality: PersonalityData = Atlas.personalities.get(
		&"test_brave",
	) as PersonalityData
	# Brave: -10% SPE
	var result: int = StatCalculator.apply_personality(100, &"speed", personality)
	assert_eq(result, 90, "Brave personality should reduce speed by 10%")


func test_personality_unaffected_stat() -> void:
	var personality: PersonalityData = Atlas.personalities.get(
		&"test_brave",
	) as PersonalityData
	# Brave: attack +10%, speed -10%, defence unaffected
	var result: int = StatCalculator.apply_personality(100, &"defence", personality)
	assert_eq(result, 100, "Brave personality should not change defence")


func test_personality_null_returns_unchanged() -> void:
	var result: int = StatCalculator.apply_personality(100, &"attack", null)
	assert_eq(result, 100, "Null personality should return unchanged value")


# --- apply_stat_stage() ---


func test_stat_stage_zero() -> void:
	var result: int = StatCalculator.apply_stat_stage(100, 0)
	assert_eq(result, 100, "Stage 0 should return base value")


func test_stat_stage_positive_1() -> void:
	# Stage +1 = 1.5x -> floor(100 * 1.5) = 150
	var result: int = StatCalculator.apply_stat_stage(100, 1)
	assert_eq(result, 150, "Stage +1 should be 1.5x")


func test_stat_stage_positive_6() -> void:
	# Stage +6 = 4.0x -> floor(100 * 4.0) = 400
	var result: int = StatCalculator.apply_stat_stage(100, 6)
	assert_eq(result, 400, "Stage +6 should be 4.0x")


func test_stat_stage_negative_1() -> void:
	# Stage -1 = 0.67x -> floor(100 * 0.67) = 67
	var result: int = StatCalculator.apply_stat_stage(100, -1)
	assert_eq(result, 67, "Stage -1 should be 0.67x")


func test_stat_stage_negative_6() -> void:
	# Stage -6 = 0.25x -> floor(100 * 0.25) = 25
	var result: int = StatCalculator.apply_stat_stage(100, -6)
	assert_eq(result, 25, "Stage -6 should be 0.25x")


func test_stat_stage_clamps_above_6() -> void:
	# Should clamp to +6 = 4.0x
	var result: int = StatCalculator.apply_stat_stage(100, 10)
	assert_eq(result, 400, "Stage above +6 should clamp to +6")


func test_stat_stage_clamps_below_negative_6() -> void:
	# Should clamp to -6 = 0.25x
	var result: int = StatCalculator.apply_stat_stage(100, -10)
	assert_eq(result, 25, "Stage below -6 should clamp to -6")


# --- calculate_effective_speed() ---


func test_effective_speed_normal_priority() -> void:
	# NORMAL = 1.0x
	var result: float = StatCalculator.calculate_effective_speed(100, Registry.Priority.NORMAL)
	assert_eq(result, 100.0, "Normal priority should be 1.0x speed")


func test_effective_speed_high_priority() -> void:
	# HIGH = 1.5x
	var result: float = StatCalculator.calculate_effective_speed(100, Registry.Priority.HIGH)
	assert_eq(result, 150.0, "High priority should be 1.5x speed")


func test_effective_speed_very_low_priority() -> void:
	# VERY_LOW = 0.25x
	var result: float = StatCalculator.calculate_effective_speed(100, Registry.Priority.VERY_LOW)
	assert_eq(result, 25.0, "Very low priority should be 0.25x speed")


func test_effective_speed_maximum_priority() -> void:
	# MAXIMUM is not in PRIORITY_SPEED_MULTIPLIERS, defaults to 1.0x
	var result: float = StatCalculator.calculate_effective_speed(100, Registry.Priority.MAXIMUM)
	assert_eq(result, 100.0, "Maximum priority should default to 1.0x speed")
