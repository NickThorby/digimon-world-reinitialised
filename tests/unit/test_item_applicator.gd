extends GutTest
## Unit tests for ItemApplicator — verifying items fail gracefully when capped.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Helpers ---


func _make_digimon_at_full() -> DigimonState:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_hp = max_stats.max_hp
	digimon.current_energy = max_stats.max_energy
	return digimon


func _apply(item_key: StringName, digimon: DigimonState) -> bool:
	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	assert_not_null(item_data, "Item '%s' should exist in Atlas" % item_key)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	return ItemApplicator.apply(item_data, digimon, max_stats.max_hp, max_stats.max_energy)


# --- HP healing at full ---


func test_potion_on_full_hp_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()

	var applied: bool = _apply(&"test_potion", digimon)

	assert_false(applied, "Potion should have no effect at full HP")


func test_super_potion_on_full_hp_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()

	var applied: bool = _apply(&"test_super_potion", digimon)

	assert_false(applied, "Super Potion should have no effect at full HP")


func test_potion_on_damaged_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.current_hp -= 10

	var applied: bool = _apply(&"test_potion", digimon)

	assert_true(applied, "Potion should work on damaged Digimon")


# --- Energy healing at full ---


func test_energy_drink_on_full_energy_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()

	var applied: bool = _apply(&"test_energy_drink", digimon)

	assert_false(applied, "Energy Drink should have no effect at full energy")


func test_energy_drink_on_low_energy_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.current_energy -= 10

	var applied: bool = _apply(&"test_energy_drink", digimon)

	assert_true(applied, "Energy Drink should work on low energy Digimon")


# --- Full restore at full ---


func test_full_restore_on_full_hp_energy_no_status_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.status_conditions = []

	var applied: bool = _apply(&"test_full_restore", digimon)

	assert_false(applied, "Full Restore should have no effect when already at max")


func test_full_restore_on_full_hp_with_status_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.status_conditions = [{"key": "burned"}]

	var applied: bool = _apply(&"test_full_restore", digimon)

	assert_true(applied, "Full Restore should work if status conditions present")


func test_full_restore_on_low_hp_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.current_hp -= 1

	var applied: bool = _apply(&"test_full_restore", digimon)

	assert_true(applied, "Full Restore should work if HP is not full")


# --- Revive ---


func test_revive_on_alive_digimon_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()

	var applied: bool = _apply(&"test_revive", digimon)

	assert_false(applied, "Revive should have no effect on alive Digimon")


func test_revive_on_fainted_digimon_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.current_hp = 0

	var applied: bool = _apply(&"test_revive", digimon)

	assert_true(applied, "Revive should work on fainted Digimon")
	assert_gt(digimon.current_hp, 0, "Digimon should have HP after revive")


# --- Status cure with no status ---


func test_burn_heal_without_burn_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.status_conditions = []

	var applied: bool = _apply(&"test_burn_heal", digimon)

	assert_false(applied, "Burn Heal should have no effect without burn status")


func test_burn_heal_with_burn_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.status_conditions = [{"key": "burned"}]

	var applied: bool = _apply(&"test_burn_heal", digimon)

	assert_true(applied, "Burn Heal should work when burned")
	assert_eq(
		digimon.status_conditions.size(), 0,
		"Burn status should be cured",
	)


# --- TVs at cap ---


func test_add_tv_at_stat_cap_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	# test_tv_boost adds 50 atk TVs; cap is 500
	digimon.tvs[&"attack"] = 500

	var applied: bool = _apply(&"test_tv_boost", digimon)

	assert_false(applied, "TV Boost should fail when stat TV is at cap")
	assert_eq(digimon.tvs[&"attack"], 500, "TVs should not change")


func test_add_tv_at_total_cap_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	# Total TV cap is 1000; fill all TVs to reach it
	digimon.tvs[&"hp"] = 200
	digimon.tvs[&"attack"] = 0
	digimon.tvs[&"defence"] = 200
	digimon.tvs[&"special_attack"] = 200
	digimon.tvs[&"special_defence"] = 200
	digimon.tvs[&"speed"] = 200

	var applied: bool = _apply(&"test_tv_boost", digimon)

	assert_false(applied, "TV Boost should fail when total TVs are at cap")
	assert_eq(digimon.tvs[&"attack"], 0, "Attack TVs should not change")


func test_add_tv_below_cap_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.tvs[&"attack"] = 0

	var applied: bool = _apply(&"test_tv_boost", digimon)

	assert_true(applied, "TV Boost should work when below cap")
	assert_eq(digimon.tvs[&"attack"], 50, "Attack TVs should increase by 50")


func test_remove_tv_at_zero_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	# test_tv_reducer removes 10 speed TVs
	digimon.tvs[&"speed"] = 0

	var applied: bool = _apply(&"test_tv_reducer", digimon)

	assert_false(applied, "TV Reducer should fail when TV is already 0")


func test_remove_tv_above_zero_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.tvs[&"speed"] = 50

	var applied: bool = _apply(&"test_tv_reducer", digimon)

	assert_true(applied, "TV Reducer should work when TV > 0")
	assert_eq(digimon.tvs[&"speed"], 40, "Speed TVs should decrease by 10")


# --- IVs at cap ---


func test_add_iv_at_cap_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	# test_iv_boost adds 5 spa IVs; cap is 50
	digimon.ivs[&"special_attack"] = 50

	var applied: bool = _apply(&"test_iv_boost", digimon)

	assert_false(applied, "IV Boost should fail when IV is at cap")
	assert_eq(digimon.ivs[&"special_attack"], 50, "IVs should not change")


func test_add_iv_below_cap_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.ivs[&"special_attack"] = 10

	var applied: bool = _apply(&"test_iv_boost", digimon)

	assert_true(applied, "IV Boost should work when below cap")
	assert_eq(digimon.ivs[&"special_attack"], 15, "IVs should increase by 5")


func test_remove_iv_at_zero_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	# test_iv_reducer removes 3 def IVs
	digimon.ivs[&"defence"] = 0

	var applied: bool = _apply(&"test_iv_reducer", digimon)

	assert_false(applied, "IV Reducer should fail when IV is already 0")


func test_remove_iv_above_zero_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.ivs[&"defence"] = 20

	var applied: bool = _apply(&"test_iv_reducer", digimon)

	assert_true(applied, "IV Reducer should work when IV > 0")
	assert_eq(digimon.ivs[&"defence"], 17, "IVs should decrease by 3")


# --- TP at cap ---


func test_add_tp_at_cap_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	# test_tp_candy adds 50 TP; cap is 999
	digimon.training_points = 999

	var applied: bool = _apply(&"test_tp_candy", digimon)

	assert_false(applied, "TP Candy should fail when TP is at cap")
	assert_eq(digimon.training_points, 999, "TP should not change")


func test_add_tp_below_cap_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.training_points = 0

	var applied: bool = _apply(&"test_tp_candy", digimon)

	assert_true(applied, "TP Candy should work when below cap")
	assert_eq(digimon.training_points, 50, "TP should increase by 50")


func test_add_tp_near_cap_clamps_to_max() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.training_points = 970

	var applied: bool = _apply(&"test_tp_candy", digimon)

	assert_true(applied, "TP Candy should work when partially below cap")
	assert_eq(digimon.training_points, 999, "TP should clamp to max")


# --- Personality ---


func test_clear_personality_without_override_returns_false() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.personality_override_key = &""

	var applied: bool = _apply(&"test_personality_reset", digimon)

	assert_false(
		applied,
		"Personality Reset should fail when no override is set",
	)


func test_clear_personality_with_override_returns_true() -> void:
	var digimon: DigimonState = _make_digimon_at_full()
	digimon.personality_override_key = &"test_brave"

	var applied: bool = _apply(&"test_personality_reset", digimon)

	assert_true(applied, "Personality Reset should work when override is set")
	assert_eq(
		digimon.personality_override_key, &"",
		"Override should be cleared",
	)
