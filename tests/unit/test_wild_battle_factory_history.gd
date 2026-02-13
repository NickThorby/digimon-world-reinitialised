extends GutTest
## Tests that WildBattleFactory generates wild Digimon with plausible
## evolution history via DigimonFactory.create_digimon_with_history().

const DEFAULT_SEED := 12345


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Helpers ---


func _make_test_zone_with_species(
	digimon_key: StringName, min_level: int = 5, max_level: int = 10,
) -> ZoneData:
	var zone := ZoneData.new()
	zone.key = &"test_region/test_sector/test_history_zone"
	zone.name = "Test History Zone"
	zone.default_min_level = min_level
	zone.default_max_level = max_level
	zone.encounter_entries = [
		{
			"digimon_key": digimon_key,
			"rarity": Registry.Rarity.COMMON,
			"min_level": -1,
			"max_level": -1,
		},
	]
	zone.format_weights = {
		BattleConfig.FormatPreset.SINGLES_1V1: 100,
	}
	return zone


# --- Tests ---


func test_wild_digimon_with_predecessors_have_history() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	# test_tank has predecessor test_agumon via standard evo
	var zone: ZoneData = _make_test_zone_with_species(&"test_tank")
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng,
	)

	var wild_party: Array = config.side_configs[1].get("party", [])
	assert_gt(wild_party.size(), 0, "Wild party should have at least 1 Digimon")

	var wild_mon: DigimonState = wild_party[0] as DigimonState
	assert_eq(wild_mon.key, &"test_tank", "Wild mon should be test_tank")
	assert_gt(
		wild_mon.evolution_history.size(), 0,
		"Wild test_tank should have evolution history (has predecessor test_agumon)",
	)


func test_wild_digimon_history_chain_is_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	var zone: ZoneData = _make_test_zone_with_species(&"test_tank")
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_agumon", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng,
	)

	var wild_party: Array = config.side_configs[1].get("party", [])
	var wild_mon: DigimonState = wild_party[0] as DigimonState

	# Last history entry's to_key should match the species key
	if wild_mon.evolution_history.size() > 0:
		var last_entry: Dictionary = wild_mon.evolution_history[
			wild_mon.evolution_history.size() - 1
		]
		assert_eq(
			StringName(last_entry.get("to_key", "")), &"test_tank",
			"Last history entry's to_key should match the species key",
		)


func test_wild_digimon_without_predecessors_have_empty_history() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEFAULT_SEED

	# test_agumon has no predecessors in test data (all evolutions go FROM it)
	var zone: ZoneData = _make_test_zone_with_species(&"test_agumon")
	var player_party: Array[DigimonState] = [
		TestBattleFactory.make_digimon_state(&"test_tank", 50),
	]
	var bag := BagState.new()

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, rng,
	)

	var wild_party: Array = config.side_configs[1].get("party", [])
	assert_gt(wild_party.size(), 0, "Wild party should have at least 1 Digimon")

	var wild_mon: DigimonState = wild_party[0] as DigimonState
	assert_eq(wild_mon.key, &"test_agumon", "Wild mon should be test_agumon")
	assert_eq(
		wild_mon.evolution_history.size(), 0,
		"Wild test_agumon should have empty history (no predecessors in test data)",
	)
