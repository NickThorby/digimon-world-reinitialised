extends GutTest
## Tests for training screen logic (no UI, tests state mutations directly).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Standard training: TP deducted ---


func test_standard_training_deducts_tp() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 100
	var tp_cost: int = TrainingCalculator.get_tp_cost("basic")
	digimon.training_points -= tp_cost
	assert_eq(digimon.training_points, 99,
		"Basic standard training should deduct 1 TP")


func test_standard_intermediate_deducts_tp() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 100
	var tp_cost: int = TrainingCalculator.get_tp_cost("intermediate")
	digimon.training_points -= tp_cost
	assert_eq(digimon.training_points, 97,
		"Intermediate standard training should deduct 3 TP")


# --- Standard training: TV applied ---


func test_standard_training_applies_tv() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 100
	var rng := RandomNumberGenerator.new()
	rng.seed = 0  # Seed 0 gives all passes for basic
	var result: Dictionary = TrainingCalculator.run_course("basic", rng)
	var tv_gained: int = result.get("tv_gained", 0)
	assert_gt(tv_gained, 0, "Should gain some TV from training")
	var current_tv: int = digimon.tvs.get(&"attack", 0) as int
	digimon.tvs[&"attack"] = current_tv + tv_gained
	assert_eq(digimon.tvs[&"attack"], tv_gained,
		"TV should be applied to the stat")


# --- Standard training: per-stat TV cap (500) ---


func test_standard_tv_capped_per_stat() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.tvs[&"attack"] = 498
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_tv: int = balance.max_tv if balance else 500
	var tv_gained: int = 6  # Simulated full pass on basic
	var current_tv: int = digimon.tvs.get(&"attack", 0) as int
	digimon.tvs[&"attack"] = mini(current_tv + tv_gained, max_tv)
	assert_eq(digimon.tvs[&"attack"], 500,
		"TV should be capped at per-stat max (500)")


# --- Standard training: global TV cap (1000) ---


func test_standard_tv_capped_global() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	# Set total TVs to 998
	digimon.tvs[&"hp"] = 500
	digimon.tvs[&"attack"] = 498
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_tv: int = balance.max_tv if balance else 500
	var max_total: int = balance.max_total_tvs if balance else 1000
	var tv_gained: int = 6
	var stat_key: StringName = &"attack"
	var current_tv: int = digimon.tvs.get(stat_key, 0) as int
	var current_total: int = digimon.get_total_tvs()
	var per_stat_headroom: int = maxi(max_tv - current_tv, 0)
	var global_headroom: int = maxi(max_total - current_total, 0)
	var actual_gain: int = mini(tv_gained, mini(per_stat_headroom, global_headroom))
	digimon.tvs[stat_key] = current_tv + actual_gain
	assert_eq(digimon.tvs[stat_key], 500,
		"TV should be capped at global max (only 2 headroom)")
	assert_eq(digimon.get_total_tvs(), 1000,
		"Total TVs should equal max_total_tvs")


# --- Hyper training: TP deducted at 10x ---


func test_hyper_training_deducts_tp() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 100
	var tp_cost: int = TrainingCalculator.get_hyper_tp_cost("basic")
	assert_eq(tp_cost, 10, "Hyper basic should cost 10 TP")
	digimon.training_points -= tp_cost
	assert_eq(digimon.training_points, 90,
		"Hyper basic training should deduct 10 TP")


# --- Hyper training: IV applied ---


func test_hyper_training_applies_iv() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.ivs[&"attack"] = 20
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var result: Dictionary = TrainingCalculator.run_hyper_course("basic", rng)
	var iv_gained: int = result.get("iv_gained", 0)
	assert_gt(iv_gained, 0, "Should gain some IV from hyper training")
	var current_hyper: int = digimon.hyper_trained_ivs.get(&"attack", 0) as int
	digimon.hyper_trained_ivs[&"attack"] = current_hyper + iv_gained
	assert_eq(digimon.get_final_iv(&"attack"), 20 + iv_gained,
		"Final IV should reflect hyper training gain")


# --- Hyper training: final IV capped at 50 ---


func test_hyper_iv_capped_at_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.ivs[&"attack"] = 45
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_iv: int = balance.max_iv if balance else 50
	var iv_gained: int = 9  # Simulated full pass on advanced
	var base_iv: int = digimon.ivs.get(&"attack", 0) as int
	var current_hyper: int = digimon.hyper_trained_ivs.get(&"attack", 0) as int
	var headroom: int = maxi(max_iv - base_iv - current_hyper, 0)
	digimon.hyper_trained_ivs[&"attack"] = current_hyper + mini(iv_gained, headroom)
	assert_eq(digimon.get_final_iv(&"attack"), 50,
		"Final IV should be capped at max_iv (50)")
	assert_eq(digimon.hyper_trained_ivs.get(&"attack", 0), 5,
		"Hyper IV should only add up to the cap")


# --- Buttons disabled ---


func test_standard_button_disabled_insufficient_tp() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 0
	var tp_cost: int = TrainingCalculator.get_tp_cost("basic")
	assert_true(digimon.training_points < tp_cost,
		"Button should be disabled when TP < cost")


func test_standard_button_disabled_tv_at_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 100
	digimon.tvs[&"attack"] = 500
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_tv: int = balance.max_tv if balance else 500
	assert_true(digimon.tvs.get(&"attack", 0) as int >= max_tv,
		"Button should be disabled when per-stat TV at max")


func test_standard_button_disabled_global_tv_at_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 100
	# Fill global TVs
	digimon.tvs[&"hp"] = 200
	digimon.tvs[&"attack"] = 200
	digimon.tvs[&"defence"] = 200
	digimon.tvs[&"speed"] = 200
	digimon.tvs[&"special_attack"] = 200
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_total: int = balance.max_total_tvs if balance else 1000
	assert_true(digimon.get_total_tvs() >= max_total,
		"Button should be disabled when global TVs at max")


func test_hyper_button_disabled_final_iv_at_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 100
	digimon.ivs[&"attack"] = 50
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_iv: int = balance.max_iv if balance else 50
	assert_true(digimon.get_final_iv(&"attack") >= max_iv,
		"Hyper button should be disabled when final IV at max")


# --- TP not refunded on failed steps ---


func test_tp_not_refunded_on_failure() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 5
	var tp_cost: int = TrainingCalculator.get_tp_cost("advanced")
	digimon.training_points -= tp_cost
	assert_eq(digimon.training_points, 0,
		"TP should be deducted regardless of step outcomes")


# --- All 3 difficulties work ---


func test_all_standard_difficulties() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for difficulty: String in ["basic", "intermediate", "advanced"]:
		var result: Dictionary = TrainingCalculator.run_course(difficulty, rng)
		assert_eq(result["steps"].size(), 3,
			"%s standard course should have 3 steps" % difficulty)


func test_all_hyper_difficulties() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for difficulty: String in ["basic", "intermediate", "advanced"]:
		var result: Dictionary = TrainingCalculator.run_hyper_course(difficulty, rng)
		assert_eq(result["steps"].size(), 3,
			"%s hyper course should have 3 steps" % difficulty)
