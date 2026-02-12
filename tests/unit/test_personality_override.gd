extends GutTest
## Unit tests for DigimonState personality override system.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- get_effective_personality_key() ---


func test_effective_key_returns_base_when_no_override() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	assert_eq(state.personality_key, &"test_neutral",
		"Factory should assign test_neutral by default")
	assert_eq(state.personality_override_key, &"",
		"Override should default to empty StringName")
	assert_eq(state.get_effective_personality_key(), &"test_neutral",
		"Effective key should return base personality when no override is set")


func test_effective_key_returns_override_when_set() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	state.personality_override_key = &"test_timid"
	assert_eq(state.get_effective_personality_key(), &"test_timid",
		"Effective key should return override when one is set")


# --- Serialisation ---


func test_serialisation_round_trip() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	state.personality_override_key = &"test_brave"
	var data: Dictionary = state.to_dict()
	var restored: DigimonState = DigimonState.from_dict(data)
	assert_eq(restored.personality_key, &"test_neutral",
		"Base personality should persist through serialisation")
	assert_eq(restored.personality_override_key, &"test_brave",
		"Personality override should persist through serialisation")
	assert_eq(restored.get_effective_personality_key(), &"test_brave",
		"Effective key should use override after deserialisation")


# --- Stat calculation with override ---


func test_stat_calc_uses_override() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var digimon_data: DigimonData = Atlas.digimon.get(&"test_agumon") as DigimonData
	var base_stats: Dictionary = StatCalculator.calculate_all_stats(digimon_data, state)

	# With test_neutral, attack is both boosted and reduced — effectively 1.0x
	var neutral_personality: PersonalityData = Atlas.personalities.get(
		&"test_neutral",
	) as PersonalityData
	var neutral_attack: int = StatCalculator.apply_personality(
		base_stats[&"attack"], &"attack", neutral_personality,
	)
	var neutral_speed: int = StatCalculator.apply_personality(
		base_stats[&"speed"], &"speed", neutral_personality,
	)

	# Apply test_brave override: +10% ATK, -10% SPE
	state.personality_override_key = &"test_brave"
	var brave_personality: PersonalityData = Atlas.personalities.get(
		state.get_effective_personality_key(),
	) as PersonalityData
	var brave_attack: int = StatCalculator.apply_personality(
		base_stats[&"attack"], &"attack", brave_personality,
	)
	var brave_speed: int = StatCalculator.apply_personality(
		base_stats[&"speed"], &"speed", brave_personality,
	)

	assert_true(brave_attack > neutral_attack,
		"Brave override should boost attack above neutral")
	assert_true(brave_speed < neutral_speed,
		"Brave override should reduce speed below neutral")


# --- Personality data lookup for override ---


func test_override_personality_has_correct_stat_modifiers() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	state.personality_override_key = &"test_brave"
	var personality: PersonalityData = Atlas.personalities.get(
		state.get_effective_personality_key(),
	) as PersonalityData
	assert_not_null(personality,
		"Override personality should be found in Atlas")
	assert_eq(personality.boosted_stat, Registry.Stat.ATTACK,
		"test_brave should boost ATTACK")
	assert_eq(personality.reduced_stat, Registry.Stat.SPEED,
		"test_brave should reduce SPEED")


# --- Clear override ---


func test_clear_override_reverts() -> void:
	var state: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	assert_eq(state.get_effective_personality_key(), &"test_neutral",
		"Should start with base personality")

	state.personality_override_key = &"test_modest"
	assert_eq(state.get_effective_personality_key(), &"test_modest",
		"Should use override after setting it")

	state.personality_override_key = &""
	assert_eq(state.get_effective_personality_key(), &"test_neutral",
		"Should revert to base personality after clearing override")
