extends GutTest
## Tests for WildBattleFactory species rolling, level rolling, format rolling,
## and encounter creation.

const DEFAULT_SEED := 12345


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- roll_species ---


func test_roll_species_respects_rarity_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var entries: Array[Dictionary] = [
		{"digimon_key": &"test_agumon", "rarity": Registry.Rarity.COMMON, "min_level": -1, "max_level": -1},
		{"digimon_key": &"test_gabumon", "rarity": Registry.Rarity.LEGENDARY, "min_level": -1, "max_level": -1},
	]

	# Run many rolls — common should appear far more often than legendary
	var counts: Dictionary = {&"test_agumon": 0, &"test_gabumon": 0}
	for i: int in 1000:
		var result: Dictionary = WildBattleFactory.roll_species(entries, rng)
		var key: StringName = result.get("digimon_key", &"")
		counts[key] = counts.get(key, 0) + 1

	assert_gt(
		counts[&"test_agumon"], counts[&"test_gabumon"],
		"Common species should appear more often than legendary (got %d vs %d)" % [
			counts[&"test_agumon"], counts[&"test_gabumon"]
		]
	)
	assert_gt(
		counts[&"test_agumon"], 800,
		"Common (weight 50) should dominate over legendary (weight 1)"
	)


func test_roll_species_returns_empty_for_empty_entries() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var entries: Array[Dictionary] = []
	var result: Dictionary = WildBattleFactory.roll_species(entries, rng)

	assert_true(result.is_empty(), "Should return empty dict for empty entries")


# --- roll_level ---


func test_roll_level_within_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := ZoneData.new()
	zone.default_min_level = 5
	zone.default_max_level = 15

	var entry := {"min_level": -1, "max_level": -1}

	for i: int in 100:
		var level: int = WildBattleFactory.roll_level(entry, zone, rng)
		assert_gte(level, 5, "Level should be >= zone min")
		assert_lte(level, 15, "Level should be <= zone max")


func test_roll_level_uses_zone_defaults_when_entry_has_minus_one() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := ZoneData.new()
	zone.default_min_level = 10
	zone.default_max_level = 20

	var entry := {"min_level": -1, "max_level": -1}
	var level: int = WildBattleFactory.roll_level(entry, zone, rng)

	assert_gte(level, 10, "Should use zone default min")
	assert_lte(level, 20, "Should use zone default max")


func test_roll_level_uses_entry_overrides() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := ZoneData.new()
	zone.default_min_level = 1
	zone.default_max_level = 5

	var entry := {"min_level": 30, "max_level": 40}

	for i: int in 50:
		var level: int = WildBattleFactory.roll_level(entry, zone, rng)
		assert_gte(level, 30, "Should use entry min override")
		assert_lte(level, 40, "Should use entry max override")


# --- roll_format ---


func test_roll_format_defaults_to_singles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var result: BattleConfig.FormatPreset = WildBattleFactory.roll_format({}, rng)

	assert_eq(
		result, BattleConfig.FormatPreset.SINGLES_1V1,
		"Empty weights should default to singles"
	)


func test_roll_format_respects_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	# 100% weight on doubles
	var weights: Dictionary = {
		BattleConfig.FormatPreset.DOUBLES_2V2: 100,
	}

	var result: BattleConfig.FormatPreset = WildBattleFactory.roll_format(
		weights, rng
	)

	assert_eq(
		result, BattleConfig.FormatPreset.DOUBLES_2V2,
		"Should return doubles when only doubles has weight"
	)


# --- create_encounter ---


func test_create_encounter_builds_valid_config() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := _make_test_zone()
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	var errors: Array[String] = config.validate()
	assert_eq(errors.size(), 0, "Config should be valid: %s" % str(errors))


func test_create_encounter_player_side_is_owned() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := _make_test_zone()
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	assert_false(
		config.side_configs[0].get("is_wild", true),
		"Player side should not be wild"
	)
	assert_true(
		config.side_configs[0].get("is_owned", false),
		"Player side should be owned"
	)


func test_create_encounter_wild_side_is_wild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := _make_test_zone()
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	assert_true(
		config.side_configs[1].get("is_wild", false),
		"Wild side should be wild"
	)
	assert_false(
		config.side_configs[1].get("is_owned", true),
		"Wild side should not be owned"
	)


func test_create_encounter_no_field_effects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := _make_test_zone()
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	assert_true(
		config.preset_field_effects.is_empty(),
		"Wild encounter should have no preset field effects"
	)
	assert_true(
		config.preset_side_effects.is_empty(),
		"Wild encounter should have no preset side effects"
	)
	assert_true(
		config.preset_hazards.is_empty(),
		"Wild encounter should have no preset hazards"
	)


func test_create_encounter_wild_party_not_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone := _make_test_zone()
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	var wild_party: Array = config.side_configs[1].get("party", [])
	assert_gt(wild_party.size(), 0, "Wild party should have at least 1 Digimon")


# --- Helpers ---


func _make_test_zone() -> ZoneData:
	var zone := ZoneData.new()
	zone.key = &"test_region/test_sector/test_zone"
	zone.name = "Test Zone"
	zone.default_min_level = 5
	zone.default_max_level = 10
	zone.encounter_entries = [
		{
			"digimon_key": &"test_agumon",
			"rarity": Registry.Rarity.COMMON,
			"min_level": -1,
			"max_level": -1,
		},
		{
			"digimon_key": &"test_gabumon",
			"rarity": Registry.Rarity.UNCOMMON,
			"min_level": -1,
			"max_level": -1,
		},
	]
	zone.format_weights = {
		BattleConfig.FormatPreset.SINGLES_1V1: 100,
	}
	return zone
