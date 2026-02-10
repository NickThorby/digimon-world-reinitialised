extends GutTest
## Unit tests for BrickExecutor brick dispatch.

var _battle: BattleState
var _user: BattleDigimonState
var _target: BattleDigimonState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()
	_user = _battle.get_digimon_at(0, 0)
	_target = _battle.get_digimon_at(1, 0)


# --- Damage brick ---


func test_damage_brick_applies_damage() -> void:
	var initial_hp: int = _target.current_hp
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var brick: Dictionary = {"brick": "damage", "type": "standard"}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, technique, _battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	assert_gt(int(result.get("damage", 0)), 0, "Should deal damage")
	assert_lt(_target.current_hp, initial_hp, "Target HP should decrease")


func test_damage_brick_increments_times_hit() -> void:
	var initial_hits: int = int(_target.counters.get("times_hit", 0))
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var brick: Dictionary = {"brick": "damage", "type": "standard"}
	BrickExecutor.execute_brick(brick, _user, _target, technique, _battle)
	assert_eq(
		int(_target.counters.get("times_hit", 0)), initial_hits + 1,
		"times_hit counter should increment",
	)


# --- StatusEffect brick ---


func test_status_effect_apply_success() -> void:
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "burned", "chance": 100,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("applied", false), "Status should be applied at 100% chance")
	assert_true(_target.has_status(&"burned"), "Target should have burned status")


func test_status_effect_chance_miss() -> void:
	# Use chance=0 to guarantee miss
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "burned", "chance": 0,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("missed", false), "Should miss at 0% chance")
	assert_false(_target.has_status(&"burned"), "Target should not have status")


func test_status_effect_remove() -> void:
	_target.add_status(&"burned")
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "burned", "action": "remove",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_false(_target.has_status(&"burned"), "Status should be removed")
	assert_eq(
		result.get("action", ""), "remove",
		"Result should indicate remove action",
	)


func test_status_effect_self_target() -> void:
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "vitalised", "chance": 100,
		"target": "self",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("applied", false), "Status should be applied")
	assert_true(_user.has_status(&"vitalised"), "User should have vitalised status")
	assert_false(_target.has_status(&"vitalised"), "Target should NOT have vitalised")


func test_status_effect_seeded_injects_seeder_info() -> void:
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "seeded", "chance": 100,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_true(_target.has_status(&"seeded"), "Target should be seeded")
	for status: Dictionary in _target.status_conditions:
		if status.get("key", &"") == &"seeded":
			assert_eq(
				int(status.get("seeder_side", -1)), _user.side_index,
				"Seeder side should match user",
			)
			assert_eq(
				int(status.get("seeder_slot", -1)), _user.slot_index,
				"Seeder slot should match user",
			)


# --- Status overrides ---


func test_burned_removes_frostbitten() -> void:
	_target.add_status(&"frostbitten")
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "burned", "chance": 100,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_true(_target.has_status(&"burned"), "Should have burned")
	assert_false(_target.has_status(&"frostbitten"), "Frostbitten should be removed")


func test_frostbitten_removes_burned() -> void:
	_target.add_status(&"burned")
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "frostbitten", "chance": 100,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_true(_target.has_status(&"frostbitten"), "Should have frostbitten")
	assert_false(_target.has_status(&"burned"), "Burned should be removed")


func test_frostbitten_upgrade_to_frozen() -> void:
	_target.add_status(&"frostbitten")
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "frostbitten", "chance": 100,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_true(_target.has_status(&"frozen"), "Double frostbitten should upgrade to frozen")
	assert_false(
		_target.has_status(&"frostbitten"), "Frostbitten should be removed",
	)


# --- StatModifier brick ---


func test_stat_modifier_increases_stage() -> void:
	var brick: Dictionary = {
		"brick": "statModifier", "modifierType": "stage",
		"stats": ["atk"], "stages": 2,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	var changes: Array = result.get("stat_changes", [])
	assert_eq(changes.size(), 1, "Should have 1 stat change")
	assert_eq(int(changes[0].get("actual", 0)), 2, "Should change by +2")
	assert_eq(_target.stat_stages[&"attack"], 2, "Target attack stage should be +2")


func test_stat_modifier_self_target() -> void:
	var brick: Dictionary = {
		"brick": "statModifier", "modifierType": "stage",
		"stats": ["atk"], "stages": 1, "target": "self",
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_eq(_user.stat_stages[&"attack"], 1, "User attack stage should be +1")
	assert_eq(_target.stat_stages[&"attack"], 0, "Target attack should be unchanged")


func test_stat_modifier_chance_miss() -> void:
	var brick: Dictionary = {
		"brick": "statModifier", "modifierType": "stage",
		"stats": ["atk"], "stages": 2, "chance": 0,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("missed", false), "Should miss at 0% chance")
	assert_eq(_target.stat_stages[&"attack"], 0, "Attack should be unchanged")


func test_stat_modifier_multiple_stats() -> void:
	var brick: Dictionary = {
		"brick": "statModifier", "modifierType": "stage",
		"stats": ["atk", "spe"], "stages": 1,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	var changes: Array = result.get("stat_changes", [])
	assert_eq(changes.size(), 2, "Should have 2 stat changes")
	assert_eq(_target.stat_stages[&"attack"], 1, "Attack stage should be +1")
	assert_eq(_target.stat_stages[&"speed"], 1, "Speed stage should be +1")


func test_stat_modifier_negative_stages() -> void:
	var brick: Dictionary = {
		"brick": "statModifier", "modifierType": "stage",
		"stats": ["def"], "stages": -2,
	}
	BrickExecutor.execute_brick(brick, _user, _target, null, _battle)
	assert_eq(_target.stat_stages[&"defence"], -2, "Defence stage should be -2")


# --- Unknown brick ---


func test_unknown_brick_returns_not_handled() -> void:
	var brick: Dictionary = {"brick": "nonexistent_brick_type"}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_false(result.get("handled", true), "Unknown brick should return handled=false")


# --- execute_bricks() (batch) ---


func test_execute_bricks_processes_all() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_ice_beam"]
	# test_ice_beam has 2 bricks: damage + statusEffect
	var results: Array[Dictionary] = BrickExecutor.execute_bricks(
		technique.bricks, _user, _target, technique, _battle,
	)
	assert_eq(results.size(), 2, "Should return 2 results for 2 bricks")
	assert_gt(int(results[0].get("damage", 0)), 0, "First brick should deal damage")


# --- damageModifier brick (standalone) ---


func test_damage_modifier_standalone_returns_skipped() -> void:
	var brick: Dictionary = {
		"brick": "damageModifier", "condition": "userHpBelow:50",
		"multiplier": 1.5,
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	assert_true(result.get("skipped", false), "Should be skipped")


# --- damageModifier via technique ---


func test_damage_with_technique_modifier_condition_passes() -> void:
	# test_first_impact has a damageModifier with condition="targetAtFullHp"
	var technique: TechniqueData = Atlas.techniques[&"test_first_impact"]
	var brick: Dictionary = {"brick": "damage", "type": "standard"}
	# Target at full HP -> modifier should apply (2x)
	var result_modified: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, technique, _battle,
	)
	# Now damage the target and try again with a fresh battle
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	target2.apply_damage(1)  # No longer at full HP
	var result_normal: Dictionary = BrickExecutor.execute_brick(
		brick, user2, target2, technique, battle2,
	)
	# Modified damage should be roughly 2x the normal damage
	var dmg_modified: int = int(result_modified.get("damage", 0))
	var dmg_normal: int = int(result_normal.get("damage", 0))
	assert_gt(dmg_modified, dmg_normal, "Modified damage should be greater")


func test_damage_with_technique_modifier_condition_fails() -> void:
	var technique: TechniqueData = Atlas.techniques[&"test_first_impact"]
	var brick: Dictionary = {"brick": "damage", "type": "standard"}
	_target.apply_damage(1)  # Not at full HP
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, technique, _battle,
	)
	assert_gt(int(result.get("damage", 0)), 0, "Should still deal base damage")


# --- damageModifier via CONTINUOUS ability ---


func test_damage_with_ability_modifier_condition_passes() -> void:
	# Give user the blaze-like ability and set HP below 50%
	_user.ability_key = &"test_ability_blaze"
	_user.current_hp = int(float(_user.max_hp) * 0.3)
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var brick: Dictionary = {"brick": "damage", "type": "standard"}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, technique, _battle,
	)
	# Create a baseline without the ability
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	user2.current_hp = int(float(user2.max_hp) * 0.3)
	var result_base: Dictionary = BrickExecutor.execute_brick(
		brick, user2, target2, technique, battle2,
	)
	var dmg_boosted: int = int(result.get("damage", 0))
	var dmg_base: int = int(result_base.get("damage", 0))
	assert_gt(dmg_boosted, dmg_base, "Blaze should increase fire damage when HP is low")


func test_damage_with_ability_modifier_condition_fails() -> void:
	# Give user blaze but keep HP at full (above 50%)
	_user.ability_key = &"test_ability_blaze"
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var brick: Dictionary = {"brick": "damage", "type": "standard"}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, technique, _battle,
	)
	# Baseline without ability
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	var result_base: Dictionary = BrickExecutor.execute_brick(
		brick, user2, target2, technique, battle2,
	)
	# Damage should be the same (condition fails, modifier not applied)
	assert_eq(
		int(result.get("damage", 0)), int(result_base.get("damage", 0)),
		"Blaze should not boost when HP is above 50%",
	)


# --- Nullified blocks CONTINUOUS modifiers ---


func test_nullified_blocks_ability_damage_modifier() -> void:
	_user.ability_key = &"test_ability_boost_fire"
	_user.add_status(&"nullified")
	var technique: TechniqueData = Atlas.techniques[&"test_fire_blast"]
	var brick: Dictionary = {"brick": "damage", "type": "standard"}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, technique, _battle,
	)
	# Baseline without ability
	var battle2: BattleState = TestBattleFactory.create_1v1_battle()
	var user2: BattleDigimonState = battle2.get_digimon_at(0, 0)
	var target2: BattleDigimonState = battle2.get_digimon_at(1, 0)
	user2.ability_key = &""
	var result_base: Dictionary = BrickExecutor.execute_brick(
		brick, user2, target2, technique, battle2,
	)
	assert_eq(
		int(result.get("damage", 0)), int(result_base.get("damage", 0)),
		"Nullified should block CONTINUOUS ability modifiers",
	)


# --- Per-brick conditions on statModifier ---


func test_stat_modifier_with_condition_passes() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.3)
	var brick: Dictionary = {
		"brick": "statModifier", "modifierType": "stage",
		"stats": ["atk"], "stages": 2, "target": "self",
		"condition": "userHpBelow:50",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	assert_false(result.has("condition_failed"), "Condition should pass")
	assert_eq(_user.stat_stages[&"attack"], 2, "Attack should be boosted")


func test_stat_modifier_with_condition_fails() -> void:
	# HP is full, above 50%
	var brick: Dictionary = {
		"brick": "statModifier", "modifierType": "stage",
		"stats": ["atk"], "stages": 2, "target": "self",
		"condition": "userHpBelow:50",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false), "Should be handled")
	assert_true(result.get("condition_failed", false), "Condition should fail")
	assert_eq(_user.stat_stages[&"attack"], 0, "Attack should be unchanged")


# --- Per-brick conditions on statusEffect ---


func test_status_effect_with_condition_passes() -> void:
	_user.current_hp = int(float(_user.max_hp) * 0.3)
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "vitalised", "chance": 100,
		"target": "self", "condition": "userHpBelow:50",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("applied", false), "Status should be applied")
	assert_true(_user.has_status(&"vitalised"), "User should be vitalised")


func test_status_effect_with_condition_fails() -> void:
	var brick: Dictionary = {
		"brick": "statusEffect", "status": "vitalised", "chance": 100,
		"target": "self", "condition": "userHpBelow:50",
	}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("condition_failed", false), "Condition should fail")
	assert_false(_user.has_status(&"vitalised"), "User should NOT be vitalised")


# --- criticalHit brick ---


func test_critical_hit_brick_returns_handled() -> void:
	var brick: Dictionary = {"brick": "criticalHit", "stages": 1}
	var result: Dictionary = BrickExecutor.execute_brick(
		brick, _user, _target, null, _battle,
	)
	assert_true(result.get("handled", false), "criticalHit brick should return handled=true")
