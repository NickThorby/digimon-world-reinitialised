extends GutTest
## Unit tests for FormatUtils static formatting methods.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- format_bits() ---


func test_format_bits_zero() -> void:
	assert_eq(FormatUtils.format_bits(0), "0", "Zero should format as '0'")


func test_format_bits_below_thousand() -> void:
	assert_eq(FormatUtils.format_bits(999), "999", "999 needs no comma separator")


func test_format_bits_exactly_one_thousand() -> void:
	assert_eq(FormatUtils.format_bits(1000), "1,000", "1000 should format as '1,000'")


func test_format_bits_millions() -> void:
	assert_eq(
		FormatUtils.format_bits(1234567), "1,234,567",
		"1234567 should format as '1,234,567'",
	)


# --- format_play_time() ---


func test_format_play_time_zero() -> void:
	assert_eq(FormatUtils.format_play_time(0), "0:00:00", "Zero seconds should be '0:00:00'")


func test_format_play_time_one_minute_five_seconds() -> void:
	assert_eq(
		FormatUtils.format_play_time(65), "0:01:05",
		"65 seconds should be '0:01:05'",
	)


func test_format_play_time_one_hour_one_minute_one_second() -> void:
	assert_eq(
		FormatUtils.format_play_time(3661), "1:01:01",
		"3661 seconds should be '1:01:01'",
	)


func test_format_play_time_ten_hours() -> void:
	assert_eq(
		FormatUtils.format_play_time(36000), "10:00:00",
		"36000 seconds should be '10:00:00'",
	)


# --- format_saved_at() ---


func test_format_saved_at_zero_returns_unknown() -> void:
	assert_eq(FormatUtils.format_saved_at(0.0), "Unknown", "Zero timestamp should be 'Unknown'")


func test_format_saved_at_negative_returns_unknown() -> void:
	assert_eq(
		FormatUtils.format_saved_at(-100.0), "Unknown",
		"Negative timestamp should be 'Unknown'",
	)


func test_format_saved_at_known_timestamp() -> void:
	# 1_000_000_000 Unix = 2001-09-09 01:46:40 UTC
	var result: String = FormatUtils.format_saved_at(1_000_000_000.0)
	assert_eq(result, "09-09-2001 01:46", "Unix 1 billion should be '09-09-2001 01:46'")


# --- build_party_text() ---


func test_build_party_text_empty_dict() -> void:
	assert_eq(
		FormatUtils.build_party_text({}), "No Digimon in party",
		"Empty metadata should return 'No Digimon in party'",
	)


func test_build_party_text_empty_keys() -> void:
	var meta: Dictionary = {"party_keys": [], "party_levels": []}
	assert_eq(
		FormatUtils.build_party_text(meta), "No Digimon in party",
		"Empty party_keys should return 'No Digimon in party'",
	)


func test_build_party_text_single_member() -> void:
	var meta: Dictionary = {
		"party_keys": [&"test_agumon"],
		"party_levels": [5],
	}
	var result: String = FormatUtils.build_party_text(meta)
	assert_eq(result, "Test Agumon Lv.5", "Single party member should show name and level")


func test_build_party_text_multiple_members() -> void:
	var meta: Dictionary = {
		"party_keys": [&"test_agumon", &"test_gabumon"],
		"party_levels": [10, 7],
	}
	var result: String = FormatUtils.build_party_text(meta)
	assert_eq(
		result, "Test Agumon Lv.10, Test Gabumon Lv.7",
		"Multiple party members should be comma-separated",
	)
