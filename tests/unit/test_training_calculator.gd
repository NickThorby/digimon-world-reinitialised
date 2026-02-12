extends GutTest
## Unit tests for TrainingCalculator.


# --- Cost / rate lookups ---


func test_get_tp_cost_basic() -> void:
	assert_eq(TrainingCalculator.get_tp_cost("basic"), 1,
		"Basic course should cost 1 TP")


func test_get_tp_cost_intermediate() -> void:
	assert_eq(TrainingCalculator.get_tp_cost("intermediate"), 3,
		"Intermediate course should cost 3 TP")


func test_get_tp_cost_advanced() -> void:
	assert_eq(TrainingCalculator.get_tp_cost("advanced"), 5,
		"Advanced course should cost 5 TP")


func test_get_tp_cost_unknown_returns_zero() -> void:
	assert_eq(TrainingCalculator.get_tp_cost("nonexistent"), 0,
		"Unknown difficulty should return 0 TP cost")


func test_get_tv_per_step_basic() -> void:
	assert_eq(TrainingCalculator.get_tv_per_step("basic"), 2,
		"Basic course should give 2 TV per step")


func test_get_tv_per_step_advanced() -> void:
	assert_eq(TrainingCalculator.get_tv_per_step("advanced"), 10,
		"Advanced course should give 10 TV per step")


func test_get_pass_rate_basic() -> void:
	assert_almost_eq(TrainingCalculator.get_pass_rate("basic"), 0.9, 0.001,
		"Basic course should have 0.9 pass rate")


func test_get_pass_rate_advanced() -> void:
	assert_almost_eq(TrainingCalculator.get_pass_rate("advanced"), 0.3, 0.001,
		"Advanced course should have 0.3 pass rate")


# --- run_course() with seeded RNG ---


func test_run_course_returns_three_steps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = TrainingCalculator.run_course("basic", rng)
	var steps: Array = result["steps"]
	assert_eq(steps.size(), 3,
		"Course should have exactly 3 steps")


func test_run_course_deterministic_with_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99999
	var result_a: Dictionary = TrainingCalculator.run_course("intermediate", rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99999
	var result_b: Dictionary = TrainingCalculator.run_course("intermediate", rng_b)

	assert_eq(result_a["steps"], result_b["steps"],
		"Same seed should produce same steps")
	assert_eq(result_a["tv_gained"], result_b["tv_gained"],
		"Same seed should produce same TV gained")


func test_run_course_tv_gained_matches_passed_steps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = TrainingCalculator.run_course("basic", rng)
	var steps: Array = result["steps"]
	var expected_tv: int = 0
	for step: Variant in steps:
		if step as bool:
			expected_tv += 2  # basic tv_per_step = 2
	assert_eq(int(result["tv_gained"]), expected_tv,
		"TV gained should equal passed_steps * tv_per_step")


func test_run_course_unknown_difficulty_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = TrainingCalculator.run_course("nonexistent", rng)
	assert_eq(result["steps"].size(), 0,
		"Unknown difficulty should return empty steps")
	assert_eq(int(result["tv_gained"]), 0,
		"Unknown difficulty should return 0 TV")


# --- Edge cases ---


func test_all_pass_max_tv() -> void:
	# With seed producing all passes for basic (pass_rate=0.9, very likely)
	# Run many times to find a seed that gives all passes
	var rng := RandomNumberGenerator.new()
	var found_all_pass: bool = false
	for s: int in 100:
		rng.seed = s
		var result: Dictionary = TrainingCalculator.run_course("basic", rng)
		var steps: Array = result["steps"]
		var all_pass: bool = true
		for step: Variant in steps:
			if not (step as bool):
				all_pass = false
				break
		if all_pass:
			assert_eq(int(result["tv_gained"]), 6,
				"3 passed basic steps should give 3*2=6 TV")
			found_all_pass = true
			break
	assert_true(found_all_pass,
		"Should find a seed where all 3 basic steps pass within 100 tries")


# --- Hyper training cost / rate lookups ---


func test_get_hyper_tp_cost_basic() -> void:
	assert_eq(TrainingCalculator.get_hyper_tp_cost("basic"), 10,
		"Basic hyper course should cost 1 * 10 = 10 TP")


func test_get_hyper_tp_cost_intermediate() -> void:
	assert_eq(TrainingCalculator.get_hyper_tp_cost("intermediate"), 30,
		"Intermediate hyper course should cost 3 * 10 = 30 TP")


func test_get_hyper_tp_cost_advanced() -> void:
	assert_eq(TrainingCalculator.get_hyper_tp_cost("advanced"), 50,
		"Advanced hyper course should cost 5 * 10 = 50 TP")


func test_get_hyper_iv_per_step_basic() -> void:
	assert_eq(TrainingCalculator.get_hyper_iv_per_step("basic"), 1,
		"Basic hyper course should give 1 IV per step")


func test_get_hyper_iv_per_step_advanced() -> void:
	assert_eq(TrainingCalculator.get_hyper_iv_per_step("advanced"), 3,
		"Advanced hyper course should give 3 IV per step")


func test_get_hyper_pass_rate_basic() -> void:
	assert_almost_eq(TrainingCalculator.get_hyper_pass_rate("basic"), 0.9, 0.001,
		"Basic hyper course should have 0.9 pass rate")


# --- run_hyper_course() ---


func test_run_hyper_course_returns_three_steps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = TrainingCalculator.run_hyper_course("basic", rng)
	var steps: Array = result["steps"]
	assert_eq(steps.size(), 3,
		"Hyper course should have exactly 3 steps")


func test_run_hyper_course_iv_gained_matches_passed_steps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = TrainingCalculator.run_hyper_course("basic", rng)
	var steps: Array = result["steps"]
	var expected_iv: int = 0
	for step: Variant in steps:
		if step as bool:
			expected_iv += 1  # basic iv_per_step = 1
	assert_eq(int(result["iv_gained"]), expected_iv,
		"IV gained should equal passed_steps * iv_per_step")


func test_run_hyper_course_unknown_difficulty_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = TrainingCalculator.run_hyper_course("nonexistent", rng)
	assert_eq(result["steps"].size(), 0,
		"Unknown difficulty should return empty steps")
	assert_eq(int(result["iv_gained"]), 0,
		"Unknown difficulty should return 0 IV")
