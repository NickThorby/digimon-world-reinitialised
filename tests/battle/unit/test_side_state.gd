extends GutTest
## Unit tests for SideState (side effects, hazards, remaining count).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Side effects ---


func test_add_side_effect() -> void:
	var side := SideState.new()
	side.add_side_effect(&"physical_barrier", 5)
	assert_true(side.has_side_effect(&"physical_barrier"), "Should have effect")


func test_refresh_side_effect_duration() -> void:
	var side := SideState.new()
	side.add_side_effect(&"physical_barrier", 3)
	side.add_side_effect(&"physical_barrier", 5)
	var count: int = 0
	for effect: Dictionary in side.side_effects:
		if effect.get("key", &"") == &"physical_barrier":
			count += 1
			assert_eq(
				int(effect.get("duration", 0)), 5,
				"Duration should be refreshed to 5",
			)
	assert_eq(count, 1, "Should only have one entry")


func test_remove_side_effect() -> void:
	var side := SideState.new()
	side.add_side_effect(&"physical_barrier", 5)
	side.remove_side_effect(&"physical_barrier")
	assert_false(side.has_side_effect(&"physical_barrier"), "Effect should be removed")


func test_has_side_effect_false() -> void:
	var side := SideState.new()
	assert_false(
		side.has_side_effect(&"physical_barrier"),
		"Should not have effect initially",
	)


func test_tick_side_effect_expires() -> void:
	var side := SideState.new()
	side.add_side_effect(&"special_barrier", 1)
	var expired: Array[StringName] = side.tick_durations()
	assert_true(
		expired.has(&"special_barrier"),
		"Special barrier should be in expired list",
	)
	assert_false(
		side.has_side_effect(&"special_barrier"),
		"Should be removed after expiring",
	)


func test_tick_side_effect_decrements() -> void:
	var side := SideState.new()
	side.add_side_effect(&"dual_barrier", 3)
	side.tick_durations()
	assert_true(
		side.has_side_effect(&"dual_barrier"),
		"Should still be active after tick",
	)


# --- Hazards ---


func test_add_hazard_new() -> void:
	var side := SideState.new()
	side.add_hazard(&"entry_damage", 1)
	assert_eq(side.hazards.size(), 1, "Should have 1 hazard")
	assert_eq(int(side.hazards[0].get("layers", 0)), 1, "Should have 1 layer")


func test_add_hazard_stacks_layers() -> void:
	var side := SideState.new()
	side.add_hazard(&"entry_damage", 1)
	side.add_hazard(&"entry_damage", 2)
	assert_eq(side.hazards.size(), 1, "Should still have 1 hazard entry")
	assert_eq(int(side.hazards[0].get("layers", 0)), 3, "Should have 3 layers total")


func test_remove_hazard() -> void:
	var side := SideState.new()
	side.add_hazard(&"entry_damage", 1)
	side.remove_hazard(&"entry_damage")
	assert_eq(side.hazards.size(), 0, "Hazard should be removed")


func test_clear_hazards() -> void:
	var side := SideState.new()
	side.add_hazard(&"entry_damage", 1)
	side.add_hazard(&"entry_stat_reduction", 1)
	side.clear_hazards()
	assert_eq(side.hazards.size(), 0, "All hazards should be cleared")


# --- get_remaining_count() ---


func test_remaining_count_active_only() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle()
	var side: SideState = battle.sides[0]
	assert_eq(side.get_remaining_count(), 1, "Should count 1 active Digimon")


func test_remaining_count_with_reserves() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_with_reserves()
	var side: SideState = battle.sides[0]
	# 1 active + 1 reserve
	assert_eq(side.get_remaining_count(), 2, "Should count active + reserve")


func test_remaining_count_fainted_not_counted() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle()
	var side: SideState = battle.sides[0]
	side.slots[0].digimon.is_fainted = true
	assert_eq(side.get_remaining_count(), 0, "Fainted Digimon should not be counted")


# --- has_active_digimon() ---


func test_has_active_digimon_true() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle()
	var side: SideState = battle.sides[0]
	assert_true(side.has_active_digimon(), "Should have active Digimon")


func test_has_active_digimon_false_when_fainted() -> void:
	var battle: BattleState = TestBattleFactory.create_1v1_battle()
	var side: SideState = battle.sides[0]
	side.slots[0].digimon.is_fainted = true
	assert_false(
		side.has_active_digimon(),
		"Should not have active Digimon when all fainted",
	)
