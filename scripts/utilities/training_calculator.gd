class_name TrainingCalculator
extends RefCounted
## Pure static utility for Digimon stat training courses.

const STEPS_PER_COURSE: int = 3


## Run a training course and return the results.
## Returns { "steps": Array[bool], "tv_gained": int }
## Each step is true (pass) or false (fail) based on pass_rate and RNG.
static func run_course(difficulty: String, rng: RandomNumberGenerator) -> Dictionary:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var course: Dictionary = _get_course(difficulty, balance)
	if course.is_empty():
		return {"steps": [] as Array[bool], "tv_gained": 0}

	var pass_rate: float = course.get("pass_rate", 0.5)
	var tv_per_step: int = course.get("tv_per_step", 1)

	var steps: Array[bool] = []
	var tv_gained: int = 0
	for i: int in STEPS_PER_COURSE:
		var passed: bool = rng.randf() < pass_rate
		steps.append(passed)
		if passed:
			tv_gained += tv_per_step

	return {"steps": steps, "tv_gained": tv_gained}


## Get the TP cost for a training course difficulty.
static func get_tp_cost(difficulty: String) -> int:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var course: Dictionary = _get_course(difficulty, balance)
	return course.get("tp_cost", 0)


## Get the TV gained per successful step for a difficulty.
static func get_tv_per_step(difficulty: String) -> int:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var course: Dictionary = _get_course(difficulty, balance)
	return course.get("tv_per_step", 0)


## Get the pass rate for a difficulty.
static func get_pass_rate(difficulty: String) -> float:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var course: Dictionary = _get_course(difficulty, balance)
	return course.get("pass_rate", 0.0)


## Find the course dictionary for a given difficulty from GameBalance.
static func _get_course(difficulty: String, balance: GameBalance) -> Dictionary:
	if balance == null:
		return {}
	for course: Dictionary in balance.training_courses:
		if course.get("difficulty", "") == difficulty:
			return course
	return {}
