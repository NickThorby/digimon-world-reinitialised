extends GutTest
## Unit tests for ItemMessageBuilder — snapshot and build_message.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- snapshot ---


func test_snapshot_captures_hp_and_energy() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.current_hp = 42
	digimon.current_energy = 17

	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)

	assert_eq(snap.current_hp, 42, "Should capture current_hp")
	assert_eq(snap.current_energy, 17, "Should capture current_energy")


func test_snapshot_captures_status_conditions() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.status_conditions = [{"key": "burned"}]

	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)

	assert_eq(snap.status_conditions.size(), 1, "Should capture statuses")
	assert_eq(
		str(snap.status_conditions[0].get("key", "")),
		"burned",
		"Should capture status key",
	)


func test_snapshot_captures_tvs_and_ivs() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.tvs[&"attack"] = 100
	digimon.ivs[&"speed"] = 25

	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)

	assert_eq(snap.tvs.get(&"attack", 0), 100, "Should capture TVs")
	assert_eq(snap.ivs.get(&"speed", 0), 25, "Should capture IVs")


func test_snapshot_captures_training_points() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 5

	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)

	assert_eq(snap.training_points, 5, "Should capture training_points")


func test_snapshot_captures_personality_and_ability_slot() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.personality_override_key = &"test_brave"
	digimon.active_ability_slot = 2

	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)

	assert_eq(
		snap.personality_override_key, &"test_brave",
		"Should capture personality_override_key",
	)
	assert_eq(snap.active_ability_slot, 2, "Should capture active_ability_slot")


func test_snapshot_is_independent_copy() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.tvs[&"attack"] = 100

	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.tvs[&"attack"] = 200

	assert_eq(
		snap.tvs.get(&"attack", 0), 100,
		"Snapshot should not be affected by later changes",
	)


# --- build_message: no effect ---


func test_build_message_not_applied() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Potion", snap, digimon, false,
	)

	assert_eq(msg, "It had no effect on Agumon.", "Should report no effect")


# --- build_message: HP ---


func test_build_message_hp_restored() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.current_hp = 50
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.current_hp = 100

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Potion", snap, digimon, true,
	)

	assert_string_contains(msg, "Used Potion on Agumon!", "Should have header")
	assert_string_contains(msg, "HP was restored by 50!", "Should report HP change")


# --- build_message: energy ---


func test_build_message_energy_restored() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.current_energy = 10
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.current_energy = 40

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Energy Drink", snap, digimon, true,
	)

	assert_string_contains(msg, "Used Energy Drink on Agumon!", "Should have header")
	assert_string_contains(
		msg, "Energy was restored by 30!", "Should report energy change",
	)


# --- build_message: status cured ---


func test_build_message_status_cured() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.status_conditions = [{"key": "burned"}]
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.status_conditions = []

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Burn Heal", snap, digimon, true,
	)

	assert_string_contains(msg, "Burned was cured!", "Should report status cure")


# --- build_message: TV changes ---


func test_build_message_tv_increased() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.tvs[&"attack"] = 50
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.tvs[&"attack"] = 60

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Protein", snap, digimon, true,
	)

	assert_string_contains(
		msg, "Attack TVs increased by 10!", "Should report TV increase",
	)


func test_build_message_tv_decreased() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.tvs[&"speed"] = 100
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.tvs[&"speed"] = 80

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Speed Berry", snap, digimon, true,
	)

	assert_string_contains(
		msg, "Speed TVs decreased by 20.", "Should report TV decrease",
	)


# --- build_message: IV changes ---


func test_build_message_iv_increased() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.ivs[&"hp"] = 10
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.ivs[&"hp"] = 15

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "IV Boost", snap, digimon, true,
	)

	assert_string_contains(
		msg, "Hp IVs increased by 5!", "Should report IV increase",
	)


# --- build_message: training points ---


func test_build_message_training_points_gained() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.training_points = 0
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.training_points = 3

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "TP Up", snap, digimon, true,
	)

	assert_string_contains(
		msg, "Gained 3 training points!", "Should report TP gained",
	)


# --- build_message: personality ---


func test_build_message_personality_changed() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.personality_override_key = &""
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.personality_override_key = &"test_brave"

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Personality Mint", snap, digimon, true,
	)

	assert_string_contains(
		msg, "Personality changed to Test Brave!", "Should report personality change",
	)


func test_build_message_personality_reset() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.personality_override_key = &"test_brave"
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.personality_override_key = &""

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Reset Capsule", snap, digimon, true,
	)

	assert_string_contains(
		msg, "Personality was reset!", "Should report personality reset",
	)


# --- build_message: ability slot ---


func test_build_message_ability_slot_changed() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.active_ability_slot = 1
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.active_ability_slot = 2

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Ability Toggle", snap, digimon, true,
	)

	assert_string_contains(
		msg, "Ability slot changed to 2!", "Should report ability slot change",
	)


# --- build_message: applied but no visible change ---


func test_build_message_applied_no_visible_change() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Mystery Item", snap, digimon, true,
	)

	assert_eq(
		msg, "Used Mystery Item on Agumon!",
		"Should only have header when no visible changes",
	)


# --- build_message: multiple changes ---


func test_build_message_hp_and_status_cure() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(&"test_agumon")
	digimon.current_hp = 30
	digimon.status_conditions = [{"key": "poisoned"}]
	var snap: Dictionary = ItemMessageBuilder.snapshot(digimon)
	digimon.current_hp = 80
	digimon.status_conditions = []

	var msg: String = ItemMessageBuilder.build_message(
		"Agumon", "Full Heal", snap, digimon, true,
	)

	assert_string_contains(msg, "HP was restored by 50!", "Should report HP")
	assert_string_contains(msg, "Poisoned was cured!", "Should report status cure")
