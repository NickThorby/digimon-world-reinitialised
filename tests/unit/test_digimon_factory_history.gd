extends GutTest
## Tests for DigimonFactory.create_digimon_with_history() and the
## _backfill_evolution_history() algorithm.

const DEFAULT_SEED := 42


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Tests ---


func test_history_is_populated_for_species_with_predecessors() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	# test_tank has a predecessor (test_agumon -> test_tank, standard)
	var state: DigimonState = DigimonFactory.create_digimon_with_history(
		&"test_tank", 30, "", rng,
	)

	assert_not_null(state, "State should not be null")
	assert_gt(
		state.evolution_history.size(), 0,
		"History should not be empty for test_tank (has predecessor test_agumon)",
	)


func test_history_chain_is_plausible() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var state: DigimonState = DigimonFactory.create_digimon_with_history(
		&"test_tank", 30, "", rng,
	)

	assert_not_null(state, "State should not be null")
	assert_gt(state.evolution_history.size(), 0, "History should not be empty")

	# First entry's from_key should differ from the target species
	var first_entry: Dictionary = state.evolution_history[0]
	assert_ne(
		StringName(first_entry.get("from_key", "")), &"test_tank",
		"First entry's from_key should not be the target species itself",
	)

	# Last entry's to_key should be the target species
	var last_entry: Dictionary = state.evolution_history[state.evolution_history.size() - 1]
	assert_eq(
		StringName(last_entry.get("to_key", "")), &"test_tank",
		"Last entry's to_key should be the target species (test_tank)",
	)


func test_prefers_standard_evolutions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	# test_wall has multiple predecessors:
	#   - test_gabumon -> test_wall (STANDARD)
	#   - test_agumon -> test_wall (JOGRESS)
	#   - test_agumon -> test_wall (X_ANTIBODY)
	#   - test_speedster -> test_wall (SLIDE — skipped by backfill)
	# With 95% standard preference, most runs should pick standard.
	var standard_count: int = 0
	var total_runs: int = 50

	for i: int in total_runs:
		rng.seed = DEFAULT_SEED + i
		var state: DigimonState = DigimonFactory.create_digimon_with_history(
			&"test_wall", 30, "", rng,
		)
		if state == null or state.evolution_history.is_empty():
			continue

		# Check the last entry (the one that leads to test_wall)
		var last_entry: Dictionary = state.evolution_history[state.evolution_history.size() - 1]
		var evo_type: int = last_entry.get("evolution_type", -1) as int
		if evo_type == Registry.EvolutionType.STANDARD:
			standard_count += 1

	assert_gt(
		standard_count, total_runs / 2,
		"Standard evolutions should be picked more than half the time (got %d/%d)" % [
			standard_count, total_runs,
		],
	)


func test_stops_at_baby_stage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var state: DigimonState = DigimonFactory.create_digimon_with_history(
		&"test_tank", 30, "", rng,
	)

	assert_not_null(state, "State should not be null")

	# No entry should have a from_key pointing to a species with level <= 1
	for entry: Dictionary in state.evolution_history:
		var from_key: StringName = StringName(entry.get("from_key", ""))
		var from_data: DigimonData = Atlas.digimon.get(from_key) as DigimonData
		if from_data != null:
			assert_gt(
				from_data.level, 1,
				"No history entry should originate from a Baby I species (from_key=%s, level=%d)" % [
					from_key, from_data.level,
				],
			)


func test_no_predecessors_produces_empty_history() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	# test_agumon has no species that evolve INTO it in the test data
	# (all test evolutions go FROM test_agumon, not TO it).
	# Despite having DigimonData.level=4, there are no reverse links, so
	# the backfill should produce an empty history.
	var state: DigimonState = DigimonFactory.create_digimon_with_history(
		&"test_agumon", 30, "", rng,
	)

	assert_not_null(state, "State should not be null")
	assert_eq(
		state.evolution_history.size(), 0,
		"History should be empty for test_agumon (no predecessors in test data)",
	)


func test_rng_produces_consistent_results() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = DEFAULT_SEED
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = DEFAULT_SEED

	var state_a: DigimonState = DigimonFactory.create_digimon_with_history(
		&"test_wall", 30, "", rng_a,
	)
	var state_b: DigimonState = DigimonFactory.create_digimon_with_history(
		&"test_wall", 30, "", rng_b,
	)

	assert_not_null(state_a, "State A should not be null")
	assert_not_null(state_b, "State B should not be null")
	assert_eq(
		state_a.evolution_history.size(), state_b.evolution_history.size(),
		"Same seed should produce same history length",
	)

	for i: int in state_a.evolution_history.size():
		var entry_a: Dictionary = state_a.evolution_history[i]
		var entry_b: Dictionary = state_b.evolution_history[i]
		assert_eq(
			StringName(entry_a.get("from_key", "")),
			StringName(entry_b.get("from_key", "")),
			"Entry %d from_key should match with same seed" % i,
		)
		assert_eq(
			StringName(entry_a.get("to_key", "")),
			StringName(entry_b.get("to_key", "")),
			"Entry %d to_key should match with same seed" % i,
		)
		assert_eq(
			entry_a.get("evolution_type", -1) as int,
			entry_b.get("evolution_type", -1) as int,
			"Entry %d evolution_type should match with same seed" % i,
		)
