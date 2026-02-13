extends GutTest
## Tests for ZoneData parsing and level range resolution.


func test_parse_from_json_basic() -> void:
	var region := {"name": "Grassy Plains"}
	var sector := {"name": "North"}
	var zone := {
		"name": "Clearing",
		"description": "A sunny clearing.",
		"digimon": [],
	}

	var data: ZoneData = ZoneData.parse_from_json(region, sector, zone)

	assert_eq(data.name, "Clearing", "Zone name should match")
	assert_eq(data.region_name, "Grassy Plains", "Region name should match")
	assert_eq(data.sector_name, "North", "Sector name should match")
	assert_eq(data.description, "A sunny clearing.", "Description should match")


func test_composite_key_is_snake_case() -> void:
	var region := {"name": "Grassy Plains"}
	var sector := {"name": "North East"}
	var zone := {"name": "Dark Forest", "digimon": []}

	var data: ZoneData = ZoneData.parse_from_json(region, sector, zone)

	assert_eq(
		str(data.key), "grassy_plains/north_east/dark_forest",
		"Composite key should be snake_case with / separators"
	)


func test_parse_encounter_entries() -> void:
	var region := {"name": "Test Region"}
	var sector := {"name": "Test Sector"}
	var zone := {
		"name": "Test Zone",
		"digimon": [
			{"game_id": "agumon", "rarity": "Common"},
			{"game_id": "gabumon", "rarity": "Rare"},
			{"game_id": "patamon", "rarity": "Very Rare"},
		],
	}

	var data: ZoneData = ZoneData.parse_from_json(region, sector, zone)

	assert_eq(data.encounter_entries.size(), 3, "Should have 3 entries")
	assert_eq(
		data.encounter_entries[0]["digimon_key"], &"agumon",
		"First entry key should be agumon"
	)
	assert_eq(
		data.encounter_entries[0]["rarity"], Registry.Rarity.COMMON,
		"First entry rarity should be COMMON"
	)
	assert_eq(
		data.encounter_entries[1]["rarity"], Registry.Rarity.RARE,
		"Second entry rarity should be RARE"
	)
	assert_eq(
		data.encounter_entries[2]["rarity"], Registry.Rarity.VERY_RARE,
		"Third entry rarity should be VERY_RARE"
	)


func test_get_encounter_level_range_uses_entry_overrides() -> void:
	var zone := ZoneData.new()
	zone.default_min_level = 5
	zone.default_max_level = 10

	var entry := {"min_level": 8, "max_level": 15}
	var result: Dictionary = zone.get_encounter_level_range(entry)

	assert_eq(result["min"], 8, "Should use entry min_level override")
	assert_eq(result["max"], 15, "Should use entry max_level override")


func test_get_encounter_level_range_falls_back_to_zone_defaults() -> void:
	var zone := ZoneData.new()
	zone.default_min_level = 3
	zone.default_max_level = 7

	var entry := {"min_level": -1, "max_level": -1}
	var result: Dictionary = zone.get_encounter_level_range(entry)

	assert_eq(result["min"], 3, "Should fall back to zone default_min_level")
	assert_eq(result["max"], 7, "Should fall back to zone default_max_level")


func test_get_encounter_level_range_partial_override() -> void:
	var zone := ZoneData.new()
	zone.default_min_level = 5
	zone.default_max_level = 10

	var entry := {"min_level": 8, "max_level": -1}
	var result: Dictionary = zone.get_encounter_level_range(entry)

	assert_eq(result["min"], 8, "Should use entry override for min")
	assert_eq(result["max"], 10, "Should fall back to zone default for max")


func test_parse_null_description() -> void:
	var region := {"name": "Region"}
	var sector := {"name": "Sector"}
	var zone := {"name": "Zone", "description": null, "digimon": []}

	var data: ZoneData = ZoneData.parse_from_json(region, sector, zone)

	assert_eq(data.description, "", "Null description should become empty string")
