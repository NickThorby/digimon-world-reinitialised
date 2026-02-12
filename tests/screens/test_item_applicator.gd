extends GutTest
## Unit tests for ItemApplicator — healing and outOfBattleEffect bricks.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Healing: fixed HP ---


func test_fixed_hp_healing() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_hp = max_stats["max_hp"] - 80
	var hp_before: int = digimon.current_hp
	var item: ItemData = Atlas.items[&"test_potion"] as ItemData
	var result: bool = ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_true(result, "apply should return true for valid healing")
	assert_eq(digimon.current_hp, hp_before + 50, "HP should increase by 50")


func test_fixed_hp_caps_at_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_hp = max_stats["max_hp"] - 10
	var item: ItemData = Atlas.items[&"test_potion"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(digimon.current_hp, max_stats["max_hp"], "HP should cap at max")


# --- Healing: percentage HP ---


func test_percentage_hp_healing() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_hp = 1
	var item: ItemData = Atlas.items[&"test_super_potion"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	var expected_heal: int = floori(max_stats["max_hp"] * 50 / 100.0)
	assert_eq(
		digimon.current_hp, mini(1 + expected_heal, max_stats["max_hp"]),
		"HP should increase by floor(max_hp * 50 / 100)",
	)


# --- Healing: fixed energy ---


func test_fixed_energy_healing() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_energy = max_stats["max_energy"] - 50
	var energy_before: int = digimon.current_energy
	var item: ItemData = Atlas.items[&"test_energy_drink"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(digimon.current_energy, energy_before + 30, "Energy should increase by 30")


func test_fixed_energy_caps_at_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_energy = max_stats["max_energy"] - 5
	var item: ItemData = Atlas.items[&"test_energy_drink"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(digimon.current_energy, max_stats["max_energy"], "Energy should cap at max")


# --- Healing: status cure ---


func test_status_cure_with_string() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.status_conditions = [{"key": "burned"}] as Array[Dictionary]
	var item: ItemData = Atlas.items[&"test_burn_heal"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(
		digimon.status_conditions.size(), 0,
		"Burned status should be cured",
	)


func test_status_cure_with_array() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.status_conditions = [
		{"key": "burned"}, {"key": "poisoned"}, {"key": "confused"},
	] as Array[Dictionary]
	var item: ItemData = Atlas.items[&"test_full_heal"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(
		digimon.status_conditions.size(), 1,
		"Only statuses not in the cure array should remain",
	)
	assert_eq(
		str(digimon.status_conditions[0].get("key", "")), "confused",
		"Confused should remain (not in cureStatus array)",
	)


# --- Healing: revive ---


func test_revive_heals_fainted() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_hp = 0
	var item: ItemData = Atlas.items[&"test_revive"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	var expected_hp: int = maxi(floori(max_stats["max_hp"] * 50 / 100.0), 1)
	assert_true(result, "Revive should return true for fainted Digimon")
	assert_eq(digimon.current_hp, expected_hp, "HP should be floor(max_hp * 50 / 100)")
	assert_true(digimon.current_hp >= 1, "HP should be at least 1 after revive")


func test_revive_noop_when_alive() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_hp = 50
	var item: ItemData = Atlas.items[&"test_revive"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_false(result, "Revive should return false when Digimon is alive")
	assert_eq(digimon.current_hp, 50, "HP should remain unchanged")


# --- Healing: full restore ---


func test_full_restore() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.current_hp = 1
	digimon.current_energy = 1
	digimon.status_conditions = [
		{"key": "burned"}, {"key": "poisoned"},
	] as Array[Dictionary]
	var item: ItemData = Atlas.items[&"test_full_restore"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(digimon.current_hp, max_stats["max_hp"], "HP should be fully restored")
	assert_eq(
		digimon.current_energy, max_stats["max_energy"],
		"Energy should be fully restored",
	)
	assert_eq(
		digimon.status_conditions.size(), 0,
		"All status conditions should be cleared",
	)


# --- Edge cases: empty/unknown bricks ---


func test_returns_false_on_empty_bricks() -> void:
	var item := ItemData.new()
	item.key = &"test_temp"
	item.bricks = []
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_false(result, "Empty bricks should return false")


func test_returns_false_on_unknown_brick() -> void:
	var item := ItemData.new()
	item.key = &"test_temp"
	item.bricks = [{"brick": "unknown"}]
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_false(result, "Unknown brick type should return false")


# --- OutOfBattleEffect: toggleAbility ---


func test_toggle_ability_slot_1_to_2() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.active_ability_slot = 1
	var item: ItemData = Atlas.items[&"test_ability_capsule"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "Toggle ability should return true")
	assert_eq(digimon.active_ability_slot, 2, "Slot should toggle from 1 to 2")


func test_toggle_ability_slot_2_to_1() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.active_ability_slot = 2
	var item: ItemData = Atlas.items[&"test_ability_capsule"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "Toggle ability should return true")
	assert_eq(digimon.active_ability_slot, 1, "Slot should toggle from 2 to 1")


func test_toggle_ability_noop_no_slot_2() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_tank", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.active_ability_slot = 1
	var item: ItemData = Atlas.items[&"test_ability_capsule"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_false(result, "Toggle should return false when no ability slot 2")
	assert_eq(digimon.active_ability_slot, 1, "Slot should remain unchanged")


# --- OutOfBattleEffect: switchSecretAbility ---


func test_switch_secret_ability() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	var item: ItemData = Atlas.items[&"test_secret_capsule"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "Switch secret ability should return true")
	assert_eq(digimon.active_ability_slot, 3, "Slot should be set to 3")


func test_switch_secret_noop_no_slot_3() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_gabumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	var item: ItemData = Atlas.items[&"test_secret_capsule"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_false(result, "Switch secret should return false when no ability slot 3")


# --- OutOfBattleEffect: addTv ---


func test_add_tv() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.tvs[&"attack"] = 0
	var item: ItemData = Atlas.items[&"test_tv_boost"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "addTv should return true")
	assert_eq(int(digimon.tvs[&"attack"]), 50, "Attack TV should be 50")


func test_add_tv_clamps_to_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.tvs[&"attack"] = 480
	var item: ItemData = Atlas.items[&"test_tv_boost"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(int(digimon.tvs[&"attack"]), 500, "Attack TV should clamp to max 500")


# --- OutOfBattleEffect: removeTv ---


func test_remove_tv() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.tvs[&"speed"] = 100
	var item: ItemData = Atlas.items[&"test_tv_reducer"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "removeTv should return true")
	assert_eq(int(digimon.tvs[&"speed"]), 90, "Speed TV should be reduced to 90")


func test_remove_tv_clamps_to_zero() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.tvs[&"speed"] = 5
	var item: ItemData = Atlas.items[&"test_tv_reducer"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(int(digimon.tvs[&"speed"]), 0, "Speed TV should clamp to 0")


# --- OutOfBattleEffect: addIv ---


func test_add_iv() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.ivs[&"special_attack"] = 0
	var item: ItemData = Atlas.items[&"test_iv_boost"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "addIv should return true")
	assert_eq(int(digimon.ivs[&"special_attack"]), 5, "Special Attack IV should be 5")


func test_add_iv_clamps_to_max() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.ivs[&"special_attack"] = 48
	var item: ItemData = Atlas.items[&"test_iv_boost"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(
		int(digimon.ivs[&"special_attack"]), 50,
		"Special Attack IV should clamp to max 50",
	)


# --- OutOfBattleEffect: removeIv ---


func test_remove_iv() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.ivs[&"defence"] = 10
	var item: ItemData = Atlas.items[&"test_iv_reducer"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "removeIv should return true")
	assert_eq(int(digimon.ivs[&"defence"]), 7, "Defence IV should be reduced to 7")


func test_remove_iv_clamps_to_zero() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.ivs[&"defence"] = 2
	var item: ItemData = Atlas.items[&"test_iv_reducer"] as ItemData
	ItemApplicator.apply(item, digimon, max_stats["max_hp"], max_stats["max_energy"])
	assert_eq(int(digimon.ivs[&"defence"]), 0, "Defence IV should clamp to 0")


# --- OutOfBattleEffect: changePersonality ---


func test_change_personality() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	var item: ItemData = Atlas.items[&"test_personality_mint"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "changePersonality should return true")
	assert_eq(
		digimon.personality_override_key, &"test_timid",
		"Personality override should be set to test_timid",
	)


func test_change_personality_noop_unknown() -> void:
	var item := ItemData.new()
	item.key = &"test_temp"
	item.bricks = [{"brick": "outOfBattleEffect", "effect": "changePersonality", "value": "nonexistent"}]
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_false(result, "changePersonality should return false for unknown personality")
	assert_eq(
		digimon.personality_override_key, &"",
		"Personality override should remain empty",
	)


# --- OutOfBattleEffect: clearPersonality ---


func test_clear_personality() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.personality_override_key = &"test_timid"
	var item: ItemData = Atlas.items[&"test_personality_reset"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "clearPersonality should return true")
	assert_eq(
		digimon.personality_override_key, &"",
		"Personality override should be cleared",
	)


func test_clear_personality_noop_already_clear() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.personality_override_key = &""
	var item: ItemData = Atlas.items[&"test_personality_reset"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_false(result, "clearPersonality should return false when already clear")


# --- OutOfBattleEffect: addTp ---


func test_add_tp() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon", 50)
	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	digimon.training_points = 10
	var item: ItemData = Atlas.items[&"test_tp_candy"] as ItemData
	var result: bool = ItemApplicator.apply(
		item, digimon, max_stats["max_hp"], max_stats["max_energy"],
	)
	assert_true(result, "addTp should return true")
	assert_eq(digimon.training_points, 60, "Training points should increase from 10 to 60")
