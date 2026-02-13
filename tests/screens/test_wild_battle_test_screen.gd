extends GutTest
## Tests for Wild Battle Test Screen logic (no UI, tests state mutations directly).
## Verifies encounter table building, format weights, WildBattleFactory integration,
## and EncounterTableData round-trip save/load.

const DEFAULT_SEED := 12345


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	Game.state = TestScreenFactory.create_test_game_state()
	Game.builder_context = {}
	Game.picker_context = {}
	Game.picker_result = null
	Game.screen_context = {}
	Game.battle_config = null


func after_each() -> void:
	Game.state = null
	Game.builder_context = {}
	Game.picker_context = {}
	Game.picker_result = null
	Game.screen_context = {}
	Game.battle_config = null


# --- Encounter Table ---


func test_encounter_table_add_entry() -> void:
	var table: EncounterTableData = TestScreenFactory.create_test_encounter_table(3)

	assert_eq(table.entries.size(), 3, "Should have 3 entries")
	assert_eq(
		table.entries[0]["digimon_key"], &"test_agumon",
		"First entry should be test_agumon"
	)


func test_encounter_table_remove_entry() -> void:
	var table: EncounterTableData = TestScreenFactory.create_test_encounter_table(3)
	table.entries.remove_at(1)

	assert_eq(table.entries.size(), 2, "Should have 2 entries after removal")
	assert_eq(
		table.entries[0]["digimon_key"], &"test_agumon",
		"First entry should still be test_agumon"
	)
	assert_eq(
		table.entries[1]["digimon_key"], &"test_patamon",
		"Second entry should be test_patamon (gabumon removed)"
	)


# --- Format Weights ---


func test_format_weight_normalisation() -> void:
	var weights: Dictionary = {
		BattleConfig.FormatPreset.SINGLES_1V1: 85,
		BattleConfig.FormatPreset.DOUBLES_2V2: 15,
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	# With these weights, singles should dominate
	var singles_count: int = 0
	for i: int in 100:
		var result: BattleConfig.FormatPreset = WildBattleFactory.roll_format(
			weights, rng
		)
		if result == BattleConfig.FormatPreset.SINGLES_1V1:
			singles_count += 1

	assert_gt(singles_count, 70, "Singles should dominate at 85%% weight (got %d%%)" % singles_count)


# --- Roll Encounter ---


func test_roll_encounter_produces_preview() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone: ZoneData = TestScreenFactory.create_test_zone_data()
	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	var bag: BagState = BagState.from_inventory(Game.state.inventory)

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	assert_not_null(config, "Config should not be null")
	assert_eq(config.side_configs.size(), 2, "Should have 2 sides")
	var wild_party: Array = config.side_configs[1].get("party", [])
	assert_gt(wild_party.size(), 0, "Wild party should not be empty")


# --- Quick Battle ---


func test_quick_battle_builds_valid_config() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone: ZoneData = TestScreenFactory.create_test_zone_data()
	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	var bag: BagState = BagState.from_inventory(Game.state.inventory)

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	var errors: Array[String] = config.validate()
	assert_eq(
		errors.size(), 0,
		"Config should be valid: %s" % str(errors)
	)
	assert_true(
		config.side_configs[1].get("is_wild", false),
		"Wild side should be wild"
	)


# --- Field Effects ---


func test_field_effects_applied_to_config() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone: ZoneData = TestScreenFactory.create_test_zone_data()
	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	var bag: BagState = BagState.from_inventory(Game.state.inventory)

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng
	)

	# Manually apply field effects like the screen would
	config.preset_field_effects = {
		"weather": {"key": &"rain", "permanent": true},
	}

	assert_false(
		config.preset_field_effects.is_empty(),
		"Config should have field effects after manual application"
	)
	assert_eq(
		config.preset_field_effects["weather"]["key"], &"rain",
		"Weather should be rain"
	)


# --- EncounterTableData round-trip ---


func test_encounter_table_to_zone_data() -> void:
	var table: EncounterTableData = TestScreenFactory.create_test_encounter_table(3)
	var zone: ZoneData = table.to_zone_data()

	assert_eq(zone.key, table.key, "Key should match")
	assert_eq(zone.name, table.name, "Name should match")
	assert_eq(zone.default_min_level, table.default_min_level, "Min level should match")
	assert_eq(zone.default_max_level, table.default_max_level, "Max level should match")
	assert_eq(
		zone.encounter_entries.size(), table.entries.size(),
		"Entry count should match"
	)
	assert_eq(
		zone.format_weights.size(), table.format_weights.size(),
		"Format weights should match"
	)


func test_encounter_table_save_load_round_trip() -> void:
	var table := EncounterTableData.new()
	table.key = &"test_round_trip"
	table.name = "Round Trip Test"
	table.default_min_level = 3
	table.default_max_level = 12
	table.entries = [
		{
			"digimon_key": &"test_agumon",
			"rarity": Registry.Rarity.COMMON,
			"min_level": -1,
			"max_level": -1,
		},
	]
	table.format_weights = {
		BattleConfig.FormatPreset.SINGLES_1V1: 100,
	}

	# Save
	var dir_path := "user://test_encounter_tables/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var save_path: String = dir_path + "test_round_trip.tres"
	var err: Error = ResourceSaver.save(table, save_path)
	assert_eq(err, OK, "Save should succeed")

	# Load
	var loaded: EncounterTableData = load(save_path) as EncounterTableData
	assert_not_null(loaded, "Loaded table should not be null")
	assert_eq(loaded.key, &"test_round_trip", "Key should match after load")
	assert_eq(loaded.name, "Round Trip Test", "Name should match after load")
	assert_eq(loaded.default_min_level, 3, "Min level should match after load")
	assert_eq(loaded.default_max_level, 12, "Max level should match after load")
	assert_eq(loaded.entries.size(), 1, "Should have 1 entry after load")

	# Cleanup
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(dir_path)
