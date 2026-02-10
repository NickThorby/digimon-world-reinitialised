class_name TestBattleFactory
extends RefCounted
## Central helper that creates synthetic test data, injects it into Atlas,
## and builds battle scenarios. All test keys are prefixed with "test_" for
## safe cleanup.

const DEFAULT_SEED: int = 12345


# --- Atlas injection / cleanup ---


## Inject all test data into Atlas dictionaries.
static func inject_all_test_data() -> void:
	_inject_personalities()
	_inject_digimon()
	_inject_techniques()
	_inject_abilities()
	_inject_items()


## Remove all test data (keys starting with "test_") from Atlas.
static func clear_test_data() -> void:
	_clear_dict(Atlas.digimon)
	_clear_dict(Atlas.techniques)
	_clear_dict(Atlas.abilities)
	_clear_dict(Atlas.personalities)
	_clear_dict(Atlas.items)


static func _clear_dict(dict: Dictionary) -> void:
	var to_erase: Array[StringName] = []
	for key: StringName in dict:
		if str(key).begins_with("test_"):
			to_erase.append(key)
	for key: StringName in to_erase:
		dict.erase(key)


# --- Personality data ---


static func _inject_personalities() -> void:
	Atlas.personalities[&"test_neutral"] = _make_personality(
		&"test_neutral", Registry.Stat.ATTACK, Registry.Stat.ATTACK,
	)
	Atlas.personalities[&"test_brave"] = _make_personality(
		&"test_brave", Registry.Stat.ATTACK, Registry.Stat.SPEED,
	)
	Atlas.personalities[&"test_modest"] = _make_personality(
		&"test_modest", Registry.Stat.SPECIAL_ATTACK, Registry.Stat.ATTACK,
	)


static func _make_personality(
	key: StringName, boosted: Registry.Stat, reduced: Registry.Stat,
) -> PersonalityData:
	var p := PersonalityData.new()
	p.key = key
	p.boosted_stat = boosted
	p.reduced_stat = reduced
	return p


# --- Digimon data ---


static func _inject_digimon() -> void:
	var agumon: DigimonData = _make_digimon(
		&"test_agumon", "Test Agumon", Registry.Attribute.VACCINE,
		[&"fire"], 80, 50, 100, 60, 50, 60, 80,
		{&"ice": 1.5, &"water": 1.5, &"fire": 0.5},
		&"test_ability_on_entry",
	)
	agumon.size_trait = &"medium"
	agumon.movement_traits = [&"terrestrial"] as Array[StringName]
	agumon.type_trait = &"dragon"
	Atlas.digimon[&"test_agumon"] = agumon

	var gabumon: DigimonData = _make_digimon(
		&"test_gabumon", "Test Gabumon", Registry.Attribute.DATA,
		[&"ice"], 75, 50, 55, 65, 100, 70, 60,
		{&"fire": 1.5, &"ice": 0.5, &"earth": 0.5},
		&"test_ability_on_turn_start",
	)
	gabumon.size_trait = &"medium"
	gabumon.movement_traits = [&"terrestrial"] as Array[StringName]
	gabumon.type_trait = &"beast"
	Atlas.digimon[&"test_gabumon"] = gabumon

	var patamon: DigimonData = _make_digimon(
		&"test_patamon", "Test Patamon", Registry.Attribute.VACCINE,
		[&"light"], 90, 50, 40, 70, 60, 80, 50,
		{&"dark": 0.0, &"light": 0.5},
		&"test_ability_on_ally_faint",
	)
	patamon.size_trait = &"small"
	patamon.movement_traits = [&"flying"] as Array[StringName]
	patamon.type_trait = &"holy"
	Atlas.digimon[&"test_patamon"] = patamon

	var tank: DigimonData = _make_digimon(
		&"test_tank", "Test Tank", Registry.Attribute.VIRUS,
		[&"dark"], 120, 50, 70, 100, 40, 100, 30,
		{&"dark": 0.0, &"light": 1.5},
		&"",
	)
	tank.size_trait = &"large"
	tank.movement_traits = [&"terrestrial"] as Array[StringName]
	tank.type_trait = &"undead"
	Atlas.digimon[&"test_tank"] = tank

	var speedster: DigimonData = _make_digimon(
		&"test_speedster", "Test Speedster", Registry.Attribute.DATA,
		[&"lightning"], 50, 50, 70, 40, 70, 40, 130,
		{&"earth": 1.5, &"lightning": 0.5},
		&"",
	)
	speedster.size_trait = &"small"
	speedster.movement_traits = [&"flying"] as Array[StringName]
	speedster.type_trait = &"insect"
	Atlas.digimon[&"test_speedster"] = speedster

	var ice_mon: DigimonData = _make_digimon(
		&"test_ice_mon", "Test Ice Mon", Registry.Attribute.DATA,
		[&"ice"], 80, 50, 60, 60, 60, 60, 60,
		{&"ice": 0.5, &"fire": 1.5},
		&"",
	)
	ice_mon.size_trait = &"medium"
	ice_mon.movement_traits = [&"terrestrial"] as Array[StringName]
	ice_mon.type_trait = &"beast"
	Atlas.digimon[&"test_ice_mon"] = ice_mon

	var earth_mon: DigimonData = _make_digimon(
		&"test_earth_mon", "Test Earth Mon", Registry.Attribute.DATA,
		[&"earth"], 80, 50, 60, 80, 50, 80, 50,
		{&"earth": 0.5, &"lightning": 1.5},
		&"",
	)
	earth_mon.size_trait = &"large"
	earth_mon.movement_traits = [&"terrestrial"] as Array[StringName]
	earth_mon.type_trait = &"mineral"
	Atlas.digimon[&"test_earth_mon"] = earth_mon

	var plant_mon: DigimonData = _make_digimon(
		&"test_plant_mon", "Test Plant Mon", Registry.Attribute.DATA,
		[&"plant"], 80, 50, 55, 65, 70, 65, 55,
		{&"plant": 0.5, &"fire": 1.5},
		&"",
	)
	plant_mon.size_trait = &"medium"
	plant_mon.movement_traits = [&"terrestrial"] as Array[StringName]
	plant_mon.type_trait = &"vegetation"
	Atlas.digimon[&"test_plant_mon"] = plant_mon

	var lightning_mon: DigimonData = _make_digimon(
		&"test_lightning_mon", "Test Lightning Mon", Registry.Attribute.DATA,
		[&"lightning"], 70, 50, 65, 50, 80, 55, 100,
		{&"lightning": 0.5, &"earth": 1.5},
		&"",
	)
	lightning_mon.size_trait = &"small"
	lightning_mon.movement_traits = [&"flying"] as Array[StringName]
	lightning_mon.type_trait = &"insect"
	Atlas.digimon[&"test_lightning_mon"] = lightning_mon

	var dual_mon: DigimonData = _make_digimon(
		&"test_dual_mon", "Test Dual Mon", Registry.Attribute.DATA,
		[&"fire", &"water"], 80, 50, 60, 60, 60, 60, 60,
		{&"fire": 0.5, &"water": 0.5, &"ice": 1.5, &"earth": 1.5},
		&"",
	)
	dual_mon.size_trait = &"medium"
	dual_mon.movement_traits = [&"terrestrial"] as Array[StringName]
	dual_mon.type_trait = &"dragon"
	Atlas.digimon[&"test_dual_mon"] = dual_mon


static func _make_digimon(
	key: StringName,
	digimon_name: String,
	attribute: Registry.Attribute,
	elements: Array[StringName],
	base_hp: int,
	base_energy: int,
	base_atk: int,
	base_def: int,
	base_spa: int,
	base_spd: int,
	base_spe: int,
	resistances: Dictionary,
	ability_key: StringName,
) -> DigimonData:
	var d := DigimonData.new()
	d.key = key
	d.dub_name = digimon_name
	d.jp_name = digimon_name
	d.attribute = attribute
	d.element_traits = elements
	d.base_hp = base_hp
	d.base_energy = base_energy
	d.base_attack = base_atk
	d.base_defence = base_def
	d.base_special_attack = base_spa
	d.base_special_defence = base_spd
	d.base_speed = base_spe
	d.resistances = resistances
	d.ability_slot_1_key = ability_key
	d.growth_rate = Registry.GrowthRate.MEDIUM_FAST
	d.base_xp_yield = 50
	# Give all test digimon access to all test techniques
	d.technique_entries = [
		{"key": &"test_tackle", "requirements": [{"type": "innate"}]},
		{"key": &"test_fire_blast", "requirements": [{"type": "innate"}]},
		{"key": &"test_ice_beam", "requirements": [{"type": "innate"}]},
		{"key": &"test_status_burn", "requirements": [{"type": "innate"}]},
		{"key": &"test_status_paralyse", "requirements": [{"type": "innate"}]},
		{"key": &"test_boost_attack", "requirements": [{"type": "innate"}]},
		{"key": &"test_debuff_speed", "requirements": [{"type": "innate"}]},
		{"key": &"test_quick_strike", "requirements": [{"type": "innate"}]},
		{"key": &"test_earthquake", "requirements": [{"type": "innate"}]},
		{"key": &"test_fire_defrost", "requirements": [{"type": "innate"}]},
		{"key": &"test_expensive", "requirements": [{"type": "innate"}]},
		{"key": &"test_heal_self", "requirements": [{"type": "innate"}]},
		{"key": &"test_level_10_tech", "requirements": [{"type": "level", "level": 10}]},
		{"key": &"test_change_element", "requirements": [{"type": "innate"}]},
		{"key": &"test_match_weakness", "requirements": [{"type": "innate"}]},
		{"key": &"test_add_element", "requirements": [{"type": "innate"}]},
		{"key": &"test_remove_element", "requirements": [{"type": "innate"}]},
		{"key": &"test_replace_elements", "requirements": [{"type": "innate"}]},
		{"key": &"test_change_user_resist", "requirements": [{"type": "innate"}]},
		{"key": &"test_change_target_resist", "requirements": [{"type": "innate"}]},
		{"key": &"test_steal_item", "requirements": [{"type": "innate"}]},
		{"key": &"test_remove_item", "requirements": [{"type": "innate"}]},
		{"key": &"test_endure", "requirements": [{"type": "innate"}]},
		{"key": &"test_decoy", "requirements": [{"type": "innate"}]},
		{"key": &"test_intact_form_guard", "requirements": [{"type": "innate"}]},
		{"key": &"test_negate_physical", "requirements": [{"type": "innate"}]},
		{"key": &"test_synergy_followup", "requirements": [{"type": "innate"}]},
		{"key": &"test_synergy_combo", "requirements": [{"type": "innate"}]},
		{"key": &"test_metronome", "requirements": [{"type": "innate"}]},
		{"key": &"test_random_damaging", "requirements": [{"type": "innate"}]},
		{"key": &"test_copycat_random", "requirements": [{"type": "innate"}]},
		{"key": &"test_full_transform", "requirements": [{"type": "innate"}]},
		{"key": &"test_partial_transform", "requirements": [{"type": "innate"}]},
		{"key": &"test_mimic", "requirements": [{"type": "innate"}]},
		{"key": &"test_sketch", "requirements": [{"type": "innate"}]},
		{"key": &"test_copy_random", "requirements": [{"type": "innate"}]},
		{"key": &"test_ability_copy", "requirements": [{"type": "innate"}]},
		{"key": &"test_ability_swap", "requirements": [{"type": "innate"}]},
		{"key": &"test_ability_suppress", "requirements": [{"type": "innate"}]},
		{"key": &"test_ability_nullify", "requirements": [{"type": "innate"}]},
		{"key": &"test_after_you", "requirements": [{"type": "innate"}]},
		{"key": &"test_quash", "requirements": [{"type": "innate"}]},
	]
	return d


# --- Technique data ---


static func _inject_techniques() -> void:
	Atlas.techniques[&"test_tackle"] = _make_technique(
		&"test_tackle", "Test Tackle",
		Registry.TechniqueClass.PHYSICAL, &"", 40, 100, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "standard"}],
	)
	Atlas.techniques[&"test_fire_blast"] = _make_technique(
		&"test_fire_blast", "Test Fire Blast",
		Registry.TechniqueClass.SPECIAL, &"fire", 90, 85, 15,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "standard"}],
	)
	Atlas.techniques[&"test_ice_beam"] = _make_technique(
		&"test_ice_beam", "Test Ice Beam",
		Registry.TechniqueClass.SPECIAL, &"ice", 80, 100, 12,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "statusEffect", "status": "frostbitten", "chance": 30},
		],
	)
	Atlas.techniques[&"test_status_burn"] = _make_technique(
		&"test_status_burn", "Test Status Burn",
		Registry.TechniqueClass.STATUS, &"fire", 0, 90, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "statusEffect", "status": "burned", "chance": 100}],
	)
	Atlas.techniques[&"test_status_paralyse"] = _make_technique(
		&"test_status_paralyse", "Test Status Paralyse",
		Registry.TechniqueClass.STATUS, &"lightning", 0, 100, 10,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "statusEffect", "status": "paralysed", "chance": 100}],
	)
	Atlas.techniques[&"test_boost_attack"] = _make_technique(
		&"test_boost_attack", "Test Boost Attack",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{"brick": "statModifier", "modifierType": "stage", "stats": ["atk"], "stages": 2, "target": "self"}],
	)
	Atlas.techniques[&"test_debuff_speed"] = _make_technique(
		&"test_debuff_speed", "Test Debuff Speed",
		Registry.TechniqueClass.STATUS, &"", 0, 100, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "statModifier", "modifierType": "stage", "stats": ["spe"], "stages": -1}],
	)
	Atlas.techniques[&"test_quick_strike"] = _make_technique(
		&"test_quick_strike", "Test Quick Strike",
		Registry.TechniqueClass.PHYSICAL, &"", 40, 100, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.HIGH,
		[], [{"brick": "damage", "type": "standard"}],
	)
	Atlas.techniques[&"test_earthquake"] = _make_technique(
		&"test_earthquake", "Test Earthquake",
		Registry.TechniqueClass.PHYSICAL, &"earth", 80, 100, 15,
		Registry.Targeting.ALL_FOES, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "standard"}],
	)
	Atlas.techniques[&"test_fire_defrost"] = _make_technique(
		&"test_fire_defrost", "Test Fire Defrost",
		Registry.TechniqueClass.PHYSICAL, &"fire", 60, 100, 10,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[Registry.TechniqueFlag.DEFROST],
		[{"brick": "damage", "type": "standard"}],
	)
	Atlas.techniques[&"test_expensive"] = _make_technique(
		&"test_expensive", "Test Expensive",
		Registry.TechniqueClass.PHYSICAL, &"", 120, 100, 999,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "standard"}],
	)
	Atlas.techniques[&"test_heal_self"] = _make_technique(
		&"test_heal_self", "Test Heal Self",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 10,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [],
	)
	Atlas.techniques[&"test_level_10_tech"] = _make_technique(
		&"test_level_10_tech", "Test Level 10 Tech",
		Registry.TechniqueClass.PHYSICAL, &"", 50, 100, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "standard"}],
	)
	# --- Weather techniques ---
	Atlas.techniques[&"test_sunny_day"] = _make_technique(
		&"test_sunny_day", "Test Sunny Day",
		Registry.TechniqueClass.STATUS, &"fire", 0, 0, 5,
		Registry.Targeting.FIELD, Registry.Priority.NORMAL,
		[], [{"brick": "fieldEffect", "type": "weather", "weather": "sun"}],
	)
	Atlas.techniques[&"test_rain_dance"] = _make_technique(
		&"test_rain_dance", "Test Rain Dance",
		Registry.TechniqueClass.STATUS, &"water", 0, 0, 5,
		Registry.Targeting.FIELD, Registry.Priority.NORMAL,
		[], [{"brick": "fieldEffect", "type": "weather", "weather": "rain"}],
	)
	Atlas.techniques[&"test_sandstorm"] = _make_technique(
		&"test_sandstorm", "Test Sandstorm",
		Registry.TechniqueClass.STATUS, &"earth", 0, 0, 5,
		Registry.Targeting.FIELD, Registry.Priority.NORMAL,
		[], [{"brick": "fieldEffect", "type": "weather", "weather": "sandstorm"}],
	)
	Atlas.techniques[&"test_hail"] = _make_technique(
		&"test_hail", "Test Hail",
		Registry.TechniqueClass.STATUS, &"ice", 0, 0, 5,
		Registry.Targeting.FIELD, Registry.Priority.NORMAL,
		[], [{"brick": "fieldEffect", "type": "weather", "weather": "hail"}],
	)
	# --- Hazard techniques ---
	Atlas.techniques[&"test_fire_hazard"] = _make_technique(
		&"test_fire_hazard", "Test Fire Hazard",
		Registry.TechniqueClass.STATUS, &"fire", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "hazard", "hazardType": "entry_damage",
			"damagePercent": 0.125, "element": "fire",
			"maxLayers": 3, "side": "target",
		}],
	)
	Atlas.techniques[&"test_stat_hazard"] = _make_technique(
		&"test_stat_hazard", "Test Stat Hazard",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "hazard", "hazardType": "entry_stat_reduction",
			"stat": "spe", "stages": -1,
			"maxLayers": 1, "side": "target",
		}],
	)
	Atlas.techniques[&"test_defog"] = _make_technique(
		&"test_defog", "Test Defog",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "hazard", "removeAll": true, "side": "target"}],
	)
	# --- Side effect techniques ---
	Atlas.techniques[&"test_physical_barrier"] = _make_technique(
		&"test_physical_barrier", "Test Physical Barrier",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.FIELD, Registry.Priority.NORMAL,
		[], [{
			"brick": "sideEffect", "effect": "physical_barrier",
			"side": "user", "duration": 5,
		}],
	)
	Atlas.techniques[&"test_special_barrier"] = _make_technique(
		&"test_special_barrier", "Test Special Barrier",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.FIELD, Registry.Priority.NORMAL,
		[], [{
			"brick": "sideEffect", "effect": "special_barrier",
			"side": "user", "duration": 5,
		}],
	)
	Atlas.techniques[&"test_water_gun"] = _make_technique(
		&"test_water_gun", "Test Water Gun",
		Registry.TechniqueClass.SPECIAL, &"water", 60, 100, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "standard"}],
	)
	# Technique with damageModifier: 2x on full-HP target
	Atlas.techniques[&"test_first_impact"] = _make_technique(
		&"test_first_impact", "Test First Impact",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 100, 10,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "damageModifier", "condition": "targetAtFullHp", "multiplier": 2.0},
		],
	)
	# Status technique with conditional stat boost
	Atlas.techniques[&"test_conditional_boost"] = _make_technique(
		&"test_conditional_boost", "Test Conditional Boost",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "statModifier", "modifierType": "stage",
			"stats": ["atk"], "stages": 2, "target": "self",
			"condition": "userHpBelow:50",
		}],
	)
	# --- Status application techniques ---
	Atlas.techniques[&"test_status_poison"] = _make_technique(
		&"test_status_poison", "Test Status Poison",
		Registry.TechniqueClass.STATUS, &"dark", 0, 0, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "statusEffect", "status": "poisoned", "chance": 100}],
	)
	Atlas.techniques[&"test_status_sleep"] = _make_technique(
		&"test_status_sleep", "Test Status Sleep",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "statusEffect", "status": "asleep", "chance": 100}],
	)
	Atlas.techniques[&"test_status_seed"] = _make_technique(
		&"test_status_seed", "Test Status Seed",
		Registry.TechniqueClass.STATUS, &"plant", 0, 0, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "statusEffect", "status": "seeded", "chance": 100}],
	)
	Atlas.techniques[&"test_status_frostbite"] = _make_technique(
		&"test_status_frostbite", "Test Status Frostbite",
		Registry.TechniqueClass.STATUS, &"ice", 0, 0, 8,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "statusEffect", "status": "frostbitten", "chance": 100}],
	)
	# --- Session 2: damage subtypes ---
	# Fixed damage: 40 flat
	Atlas.techniques[&"test_fixed_damage"] = _make_technique(
		&"test_fixed_damage", "Test Fixed Damage",
		Registry.TechniqueClass.PHYSICAL, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "fixed", "amount": 40}],
	)
	# Percentage damage: 25% of target's max HP
	Atlas.techniques[&"test_percent_damage"] = _make_technique(
		&"test_percent_damage", "Test Percent Damage",
		Registry.TechniqueClass.PHYSICAL, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "damage", "type": "percentage",
			"percent": 25, "source": "targetMaxHp",
		}],
	)
	# Level damage: damage = user's level
	Atlas.techniques[&"test_level_damage"] = _make_technique(
		&"test_level_damage", "Test Level Damage",
		Registry.TechniqueClass.PHYSICAL, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "level"}],
	)
	# Scaling damage: uses special_attack stat with power 80
	Atlas.techniques[&"test_scaling_damage"] = _make_technique(
		&"test_scaling_damage", "Test Scaling Damage",
		Registry.TechniqueClass.SPECIAL, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "damage", "type": "scaling", "stat": "spa", "power": 80}],
	)
	# Return damage: reflects 1.5x of last hit taken
	Atlas.techniques[&"test_return_damage"] = _make_technique(
		&"test_return_damage", "Test Return Damage",
		Registry.TechniqueClass.PHYSICAL, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "damage", "type": "returnDamage",
			"damageSource": "lastHit", "returnMultiplier": 1.5,
		}],
	)
	# Counter-scaling damage: basePower 20 + timesHit * 20 (cap 100)
	Atlas.techniques[&"test_counter_scaling"] = _make_technique(
		&"test_counter_scaling", "Test Counter Scaling",
		Registry.TechniqueClass.PHYSICAL, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "damage", "type": "counterScaling",
			"basePower": 20, "scalesWithCounter": "timesHitThisBattle",
			"scalingPerCount": 20, "scalingCap": 100,
		}],
	)
	# --- Session 2: recoil ---
	# Recoil: 25% of damage dealt
	Atlas.techniques[&"test_recoil_percent"] = _make_technique(
		&"test_recoil_percent", "Test Recoil Percent",
		Registry.TechniqueClass.PHYSICAL, &"", 80, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "recoil", "type": "damagePercent", "percent": 25},
		],
	)
	# Recoil: 50% max HP on miss (crash)
	Atlas.techniques[&"test_crash_recoil"] = _make_technique(
		&"test_crash_recoil", "Test Crash Recoil",
		Registry.TechniqueClass.PHYSICAL, &"", 120, 100, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "recoil", "type": "crash", "percent": 50},
		],
	)
	# Recoil: fixed 10 damage
	Atlas.techniques[&"test_recoil_fixed"] = _make_technique(
		&"test_recoil_fixed", "Test Recoil Fixed",
		Registry.TechniqueClass.PHYSICAL, &"", 80, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "recoil", "type": "fixed", "amount": 10},
		],
	)
	# --- Session 2: drain ---
	Atlas.techniques[&"test_drain"] = _make_technique(
		&"test_drain", "Test Drain",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "healing", "type": "drain", "percent": 50},
		],
	)
	# --- Session 2: criticalHit ---
	Atlas.techniques[&"test_always_crit"] = _make_technique(
		&"test_always_crit", "Test Always Crit",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "criticalHit", "alwaysCrit": true},
			{"brick": "damage", "type": "standard"},
		],
	)
	Atlas.techniques[&"test_never_crit"] = _make_technique(
		&"test_never_crit", "Test Never Crit",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "criticalHit", "neverCrit": true},
			{"brick": "damage", "type": "standard"},
		],
	)
	# --- Session 2: damageModifier flags ---
	# Technique with ignoreDefense
	Atlas.techniques[&"test_ignore_defence"] = _make_technique(
		&"test_ignore_defence", "Test Ignore Defence",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damageModifier", "ignoreDefense": true},
			{"brick": "damage", "type": "standard"},
		],
	)
	# Technique with ignoreStatBoosts
	Atlas.techniques[&"test_ignore_stat_boosts"] = _make_technique(
		&"test_ignore_stat_boosts", "Test Ignore Stat Boosts",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damageModifier", "ignoreStatBoosts": true},
			{"brick": "damage", "type": "standard"},
		],
	)
	# Technique with ignoreTypeImmunity (for testing against immune targets)
	Atlas.techniques[&"test_ignore_type_immunity"] = _make_technique(
		&"test_ignore_type_immunity", "Test Ignore Type Immunity",
		Registry.TechniqueClass.SPECIAL, &"dark", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damageModifier", "ignoreTypeImmunity": true},
			{"brick": "damage", "type": "standard"},
		],
	)
	# Technique with ignoreEvasion
	Atlas.techniques[&"test_ignore_evasion"] = _make_technique(
		&"test_ignore_evasion", "Test Ignore Evasion",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 100, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damageModifier", "ignoreEvasion": true},
			{"brick": "damage", "type": "standard"},
		],
	)
	# --- Session 3: protection ---
	# Protection: all (blocks everything)
	Atlas.techniques[&"test_protect"] = _make_technique(
		&"test_protect", "Test Protect",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.VERY_HIGH,
		[], [{"brick": "protection", "type": "all"}],
	)
	# Protection: wide (blocks multi-target only)
	Atlas.techniques[&"test_wide_guard"] = _make_technique(
		&"test_wide_guard", "Test Wide Guard",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.VERY_HIGH,
		[], [{"brick": "protection", "type": "wide"}],
	)
	# Protection: priority (blocks priority moves)
	Atlas.techniques[&"test_priority_guard"] = _make_technique(
		&"test_priority_guard", "Test Priority Guard",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.VERY_HIGH,
		[], [{"brick": "protection", "type": "priority"}],
	)
	# Protection with counter damage (10% max HP on contact)
	Atlas.techniques[&"test_counter_protect"] = _make_technique(
		&"test_counter_protect", "Test Counter Protect",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.VERY_HIGH,
		[], [{
			"brick": "protection", "type": "all",
			"counterDamage": 0.125,
		}],
	)
	# --- Session 3: requirement ---
	# Technique that fails if user HP is below 50%
	Atlas.techniques[&"test_require_hp"] = _make_technique(
		&"test_require_hp", "Test Require HP",
		Registry.TechniqueClass.PHYSICAL, &"", 80, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "requirement",
				"failCondition": "userHpBelow:50",
				"failMessage": "Not enough HP to use this technique!",
				"checkTiming": "beforeExecution",
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# --- Session 3: conditional ---
	# Conditional: +40 power if target HP is full
	Atlas.techniques[&"test_conditional_power"] = _make_technique(
		&"test_conditional_power", "Test Conditional Power",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "conditional",
				"condition": "targetAtFullHp",
				"bonusPower": 40,
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# Conditional: 2x damage if target is poisoned
	Atlas.techniques[&"test_conditional_mult"] = _make_technique(
		&"test_conditional_mult", "Test Conditional Multiplier",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "conditional",
				"condition": "targetHasStatus:poisoned",
				"damageMultiplier": 2.0,
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# Conditional with nested applyBricks: boost ATK +1 if target HP below 50%
	Atlas.techniques[&"test_conditional_nested"] = _make_technique(
		&"test_conditional_nested", "Test Conditional Nested",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "conditional",
				"condition": "targetHpBelow:50",
				"applyBricks": [{
					"brick": "statModifier", "modifierType": "stage",
					"stats": ["atk"], "stages": 1, "target": "self",
				}],
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# --- Session 3: priorityOverride ---
	# Normal priority, but gains HIGH priority if target HP < 50%
	Atlas.techniques[&"test_priority_override"] = _make_technique(
		&"test_priority_override", "Test Priority Override",
		Registry.TechniqueClass.PHYSICAL, &"", 40, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "priorityOverride",
				"condition": "targetHpBelow:50",
				"newPriority": 1,
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# --- Session 4: statModifier subtypes ---
	# statModifier percent: +50% ATK
	Atlas.techniques[&"test_stat_percent_boost"] = _make_technique(
		&"test_stat_percent_boost", "Test Stat Percent Boost",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "statModifier", "modifierType": "percent",
			"stats": ["atk"], "percent": 50, "target": "self",
		}],
	)
	# statModifier fixed: +20 DEF
	Atlas.techniques[&"test_stat_fixed_boost"] = _make_technique(
		&"test_stat_fixed_boost", "Test Stat Fixed Boost",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "statModifier", "modifierType": "fixed",
			"stats": ["def"], "value": 20, "target": "self",
		}],
	)
	# statModifier setToMax: ATK to +6
	Atlas.techniques[&"test_stat_set_max"] = _make_technique(
		&"test_stat_set_max", "Test Stat Set Max",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "statModifier", "modifierType": "stage",
			"stats": ["atk"], "setToMax": true, "target": "self",
		}],
	)
	# statModifier swapWithTarget
	Atlas.techniques[&"test_stat_swap"] = _make_technique(
		&"test_stat_swap", "Test Stat Swap",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "statModifier", "modifierType": "stage",
			"swapWithTarget": true,
		}],
	)
	# statModifier scalesWithCounter: timesHitThisBattle
	Atlas.techniques[&"test_stat_counter_scaling"] = _make_technique(
		&"test_stat_counter_scaling", "Test Stat Counter Scaling",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "statModifier", "modifierType": "stage",
			"stats": ["atk"], "scalesWithCounter": "timesHitThisBattle",
			"scalingPerCount": 1, "scalingCap": 3, "target": "self",
		}],
	)
	# --- Session 4: statProtection ---
	# statProtection: preventLowering all stats
	Atlas.techniques[&"test_stat_protection_lower"] = _make_technique(
		&"test_stat_protection_lower", "Test Stat Protection Lower",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "statProtection", "stats": "all",
			"preventLowering": true, "duration": 5, "target": "self",
		}],
	)
	# statProtection: preventRaising ATK and SPA (applied to target)
	Atlas.techniques[&"test_stat_protection_raise"] = _make_technique(
		&"test_stat_protection_raise", "Test Stat Protection Raise",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "statProtection", "stats": ["atk", "spa"],
			"preventRaising": true, "duration": 5, "target": "target",
		}],
	)
	# --- Session 4: statusInteraction ---
	# statusInteraction: cure target's burned
	Atlas.techniques[&"test_status_interaction_cure"] = _make_technique(
		&"test_status_interaction_cure", "Test Status Interaction Cure",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "statusInteraction", "ifTargetHas": "burned",
			"cure": true,
		}],
	)
	# statusInteraction: transfer user's poison to target
	Atlas.techniques[&"test_status_interaction_transfer"] = _make_technique(
		&"test_status_interaction_transfer", "Test Status Interaction Transfer",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "statusInteraction", "ifUserHas": "poisoned",
			"transfer": true,
		}],
	)
	# statusInteraction: bonusDamage 2.0 if target paralysed
	Atlas.techniques[&"test_status_interaction_bonus"] = _make_technique(
		&"test_status_interaction_bonus", "Test Status Interaction Bonus",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "statusInteraction", "ifTargetHas": "paralysed",
				"bonusDamage": 2.0,
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# --- Session 4: healing subtypes ---
	# healing weather: percent 50
	Atlas.techniques[&"test_weather_heal"] = _make_technique(
		&"test_weather_heal", "Test Weather Heal",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{"brick": "healing", "type": "weather", "percent": 50}],
	)
	# healing status: amount 30, cureStatus burned
	Atlas.techniques[&"test_status_heal"] = _make_technique(
		&"test_status_heal", "Test Status Heal",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "healing", "type": "status",
			"amount": 30, "cureStatus": "burned",
		}],
	)
	# Contact technique for counter protection tests
	Atlas.techniques[&"test_contact_tackle"] = _make_technique(
		&"test_contact_tackle", "Test Contact Tackle",
		Registry.TechniqueClass.PHYSICAL, &"", 40, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[Registry.TechniqueFlag.CONTACT],
		[{"brick": "damage", "type": "standard"}],
	)
	# --- Session 5: positionControl ---
	# forceSwitch: damage + force target to switch
	Atlas.techniques[&"test_force_switch"] = _make_technique(
		&"test_force_switch", "Test Force Switch",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "positionControl", "type": "forceSwitch"},
		],
	)
	# switchOut: damage + user switches out
	Atlas.techniques[&"test_switch_out_attack"] = _make_technique(
		&"test_switch_out_attack", "Test Switch Out Attack",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "positionControl", "type": "switchOut"},
		],
	)
	# switchOutPassStats: pass stat stages to replacement
	Atlas.techniques[&"test_baton_pass"] = _make_technique(
		&"test_baton_pass", "Test Baton Pass",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [
			{"brick": "positionControl", "type": "switchOutPassStats"},
		],
	)
	# --- Session 5: turnEconomy ---
	# multiHit: fixed 3 hits
	Atlas.techniques[&"test_multi_hit_3"] = _make_technique(
		&"test_multi_hit_3", "Test Multi Hit 3",
		Registry.TechniqueClass.PHYSICAL, &"", 25, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{
				"brick": "turnEconomy",
				"multiHit": {"fixedHits": 3},
			},
		],
	)
	# recharge: skip next turn after use
	Atlas.techniques[&"test_recharge_blast"] = _make_technique(
		&"test_recharge_blast", "Test Recharge Blast",
		Registry.TechniqueClass.PHYSICAL, &"", 120, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "turnEconomy", "recharge": true},
		],
	)
	# delayedAttack: damage hits target slot after 2 turns
	Atlas.techniques[&"test_future_sight"] = _make_technique(
		&"test_future_sight", "Test Future Sight",
		Registry.TechniqueClass.SPECIAL, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "turnEconomy",
			"delayedAttack": {"delay": 2, "targetsSlot": true},
		}],
	)
	# delayedHealing: heal 50% after 1 turn
	Atlas.techniques[&"test_wish"] = _make_technique(
		&"test_wish", "Test Wish",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "turnEconomy",
			"delayedHealing": {"delay": 1, "percent": 50, "target": "self"},
		}],
	)
	# --- Session 5: chargeRequirement ---
	# charge 1 turn, no weather skip
	Atlas.techniques[&"test_charge_beam"] = _make_technique(
		&"test_charge_beam", "Test Charge Beam",
		Registry.TechniqueClass.SPECIAL, &"", 80, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{"brick": "chargeRequirement", "turnsToCharge": 1},
		],
	)
	# charge 1 turn, skip in sun weather
	Atlas.techniques[&"test_solar_beam"] = _make_technique(
		&"test_solar_beam", "Test Solar Beam",
		Registry.TechniqueClass.SPECIAL, &"plant", 120, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{
				"brick": "chargeRequirement",
				"turnsToCharge": 1,
				"skipInWeather": "sun",
			},
		],
	)
	# multiTurn + semiInvulnerable (Fly pattern): 2-turn move
	Atlas.techniques[&"test_fly"] = _make_technique(
		&"test_fly", "Test Fly",
		Registry.TechniqueClass.PHYSICAL, &"", 80, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{
				"brick": "turnEconomy",
				"multiTurn": {"min": 2, "max": 2, "lockedIn": true},
				"semiInvulnerable": "sky",
			},
		],
	)
	# multiTurn without semiInvulnerable (Outrage pattern): 2-3 turns
	Atlas.techniques[&"test_outrage"] = _make_technique(
		&"test_outrage", "Test Outrage",
		Registry.TechniqueClass.PHYSICAL, &"", 90, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{
				"brick": "turnEconomy",
				"multiTurn": {"min": 2, "max": 3, "lockedIn": true},
			},
		],
	)
	# Simple damage technique for testing delayed attacks
	Atlas.techniques[&"test_future_sight_damage"] = _make_technique(
		&"test_future_sight_damage", "Test Future Sight Damage",
		Registry.TechniqueClass.SPECIAL, &"", 100, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "damage", "type": "standard"},
			{
				"brick": "turnEconomy",
				"delayedAttack": {"delay": 2, "targetsSlot": true},
			},
		],
	)
	# --- Session 6: elementModifier ---
	# changeTechniqueElement: fire technique deals ice damage
	Atlas.techniques[&"test_change_element"] = _make_technique(
		&"test_change_element", "Test Change Element",
		Registry.TechniqueClass.SPECIAL, &"fire", 80, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "elementModifier", "type": "changeTechniqueElement",
				"element": "ice",
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# matchTargetWeakness: finds target's weakness
	Atlas.techniques[&"test_match_weakness"] = _make_technique(
		&"test_match_weakness", "Test Match Weakness",
		Registry.TechniqueClass.SPECIAL, &"", 80, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{"brick": "elementModifier", "type": "matchTargetWeakness"},
			{"brick": "damage", "type": "standard"},
		],
	)
	# addElement: add ice to self
	Atlas.techniques[&"test_add_element"] = _make_technique(
		&"test_add_element", "Test Add Element",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "elementModifier", "type": "addElement",
			"element": "ice", "target": "self",
		}],
	)
	# removeElement: strip fire from target
	Atlas.techniques[&"test_remove_element"] = _make_technique(
		&"test_remove_element", "Test Remove Element",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "elementModifier", "type": "removeElement",
			"element": "fire", "target": "target",
		}],
	)
	# replaceElements: replace all with dark
	Atlas.techniques[&"test_replace_elements"] = _make_technique(
		&"test_replace_elements", "Test Replace Elements",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "elementModifier", "type": "replaceElements",
			"element": "dark", "target": "target",
		}],
	)
	# changeUserResistanceProfile: user immune to fire
	Atlas.techniques[&"test_change_user_resist"] = _make_technique(
		&"test_change_user_resist", "Test Change User Resist",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "elementModifier",
			"type": "changeUserResistanceProfile",
			"element": "fire", "value": 0.0,
		}],
	)
	# changeTargetResistanceProfile: target very weak to fire
	Atlas.techniques[&"test_change_target_resist"] = _make_technique(
		&"test_change_target_resist", "Test Change Target Resist",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "elementModifier",
			"type": "changeTargetResistanceProfile",
			"element": "fire", "value": 2.0,
		}],
	)
	# --- Session 6: resource ---
	# stealItem
	Atlas.techniques[&"test_steal_item"] = _make_technique(
		&"test_steal_item", "Test Steal Item",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "resource", "stealItem": true}],
	)
	# removeItem
	Atlas.techniques[&"test_remove_item"] = _make_technique(
		&"test_remove_item", "Test Remove Item",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "resource", "removeItem": true}],
	)
	# --- Session 6: shield ---
	# endure: survive with 1 HP, once per battle
	Atlas.techniques[&"test_endure"] = _make_technique(
		&"test_endure", "Test Endure",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.VERY_HIGH,
		[], [{
			"brick": "shield", "type": "endure",
			"oncePerBattle": true, "breakOnHit": true,
		}],
	)
	# hpDecoy: Substitute — 25% HP cost, absorbs damage, blocks status
	Atlas.techniques[&"test_decoy"] = _make_technique(
		&"test_decoy", "Test Decoy",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "shield", "type": "hpDecoy",
			"hpCost": 0.25, "blocksStatus": true,
		}],
	)
	# intactFormGuard: Disguise — blocks first hit unconditionally
	Atlas.techniques[&"test_intact_form_guard"] = _make_technique(
		&"test_intact_form_guard", "Test Intact Form Guard",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "shield", "type": "intactFormGuard",
			"breakOnHit": true,
		}],
	)
	# negateOneMoveClass: blocks one physical hit
	Atlas.techniques[&"test_negate_physical"] = _make_technique(
		&"test_negate_physical", "Test Negate Physical",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "shield", "type": "negateOneMoveClass",
			"moveClass": "physical",
		}],
	)
	# --- Session 6: synergy ---
	# followUp: bonus power when last technique was test_tackle
	Atlas.techniques[&"test_synergy_followup"] = _make_technique(
		&"test_synergy_followup", "Test Synergy Follow Up",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "synergy", "synergyType": "followUp",
				"partnerTechniques": ["test_tackle"], "bonusPower": 40,
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# combo: bonus power when user or target last hit by test_fire_blast
	Atlas.techniques[&"test_synergy_combo"] = _make_technique(
		&"test_synergy_combo", "Test Synergy Combo",
		Registry.TechniqueClass.PHYSICAL, &"", 60, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [
			{
				"brick": "synergy", "synergyType": "combo",
				"partnerTechniques": ["test_fire_blast"], "bonusPower": 30,
			},
			{"brick": "damage", "type": "standard"},
		],
	)
	# --- Session 7: useRandomTechnique ---
	# Metronome: pick random from user's known (excluding self)
	Atlas.techniques[&"test_metronome"] = _make_technique(
		&"test_metronome", "Test Metronome",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{"brick": "useRandomTechnique", "source": "userKnownExceptThis"}],
	)
	# Random damaging: pick from all techniques, only damaging
	Atlas.techniques[&"test_random_damaging"] = _make_technique(
		&"test_random_damaging", "Test Random Damaging",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SELF, Registry.Priority.NORMAL,
		[], [{
			"brick": "useRandomTechnique",
			"source": "allTechniques", "onlyDamaging": true,
		}],
	)
	# Copycat: pick from target's known techniques
	Atlas.techniques[&"test_copycat_random"] = _make_technique(
		&"test_copycat_random", "Test Copycat Random",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "useRandomTechnique", "source": "targetKnown"}],
	)
	# --- Session 7: transform ---
	# Full transform: copy all aspects
	Atlas.techniques[&"test_full_transform"] = _make_technique(
		&"test_full_transform", "Test Full Transform",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "transform",
			"copyStats": ["atk", "def", "spa", "spd", "spe"],
			"copyTechniques": true, "copyAbility": true,
			"copyResistances": true, "copyElementTraits": true,
			"copyAppearance": true,
		}],
	)
	# Partial transform: copy only atk/spa + techniques, with duration
	Atlas.techniques[&"test_partial_transform"] = _make_technique(
		&"test_partial_transform", "Test Partial Transform",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "transform",
			"copyStats": ["atk", "spa"],
			"copyTechniques": true, "duration": 3,
		}],
	)
	# --- Session 7: copyTechnique ---
	# Mimic: copy last used by target, temporary
	Atlas.techniques[&"test_mimic"] = _make_technique(
		&"test_mimic", "Test Mimic",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "copyTechnique",
			"source": "lastUsedByTarget", "replaceSlot": 3, "duration": 5,
		}],
	)
	# Sketch: copy last used by any, permanent
	Atlas.techniques[&"test_sketch"] = _make_technique(
		&"test_sketch", "Test Sketch",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "copyTechnique",
			"source": "lastUsedByAny", "permanent": true, "replaceSlot": 3,
		}],
	)
	# Copy random from target
	Atlas.techniques[&"test_copy_random"] = _make_technique(
		&"test_copy_random", "Test Copy Random",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "copyTechnique",
			"source": "randomFromTarget", "replaceSlot": 3,
		}],
	)
	# --- Session 7: abilityManipulation ---
	Atlas.techniques[&"test_ability_copy"] = _make_technique(
		&"test_ability_copy", "Test Ability Copy",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "abilityManipulation", "type": "copy"}],
	)
	Atlas.techniques[&"test_ability_swap"] = _make_technique(
		&"test_ability_swap", "Test Ability Swap",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "abilityManipulation", "type": "swap"}],
	)
	Atlas.techniques[&"test_ability_suppress"] = _make_technique(
		&"test_ability_suppress", "Test Ability Suppress",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{
			"brick": "abilityManipulation", "type": "suppress",
			"duration": 3,
		}],
	)
	Atlas.techniques[&"test_ability_nullify"] = _make_technique(
		&"test_ability_nullify", "Test Ability Nullify",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "abilityManipulation", "type": "nullify"}],
	)
	# --- Session 7: turnOrder ---
	Atlas.techniques[&"test_after_you"] = _make_technique(
		&"test_after_you", "Test After You",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "turnOrder", "type": "makeTargetMoveNext"}],
	)
	Atlas.techniques[&"test_quash"] = _make_technique(
		&"test_quash", "Test Quash",
		Registry.TechniqueClass.STATUS, &"", 0, 0, 5,
		Registry.Targeting.SINGLE_FOE, Registry.Priority.NORMAL,
		[], [{"brick": "turnOrder", "type": "makeTargetMoveLast"}],
	)


static func _make_technique(
	key: StringName,
	technique_name: String,
	technique_class: Registry.TechniqueClass,
	element_key: StringName,
	power: int,
	accuracy: int,
	energy_cost: int,
	targeting: Registry.Targeting,
	priority: Registry.Priority,
	flags: Array,
	bricks: Array,
) -> TechniqueData:
	var t := TechniqueData.new()
	t.key = key
	t.dub_name = technique_name
	t.jp_name = technique_name
	t.technique_class = technique_class
	t.element_key = element_key
	t.power = power
	t.accuracy = accuracy
	t.energy_cost = energy_cost
	t.targeting = targeting
	t.priority = priority
	for flag: Variant in flags:
		t.flags.append(flag as Registry.TechniqueFlag)
	for brick: Variant in bricks:
		t.bricks.append(brick as Dictionary)
	return t


# --- Ability data ---


static func _inject_abilities() -> void:
	Atlas.abilities[&"test_ability_on_entry"] = _make_ability(
		&"test_ability_on_entry", "Test Entry Ability",
		Registry.AbilityTrigger.ON_ENTRY,
		Registry.StackLimit.ONCE_PER_SWITCH,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["atk"], "stages": 1, "target": "self"}],
	)
	Atlas.abilities[&"test_ability_on_damage"] = _make_ability(
		&"test_ability_on_damage", "Test On Damage Ability",
		Registry.AbilityTrigger.ON_TAKE_DAMAGE,
		Registry.StackLimit.ONCE_PER_TURN,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["spe"], "stages": 1, "target": "self"}],
	)
	Atlas.abilities[&"test_ability_on_turn_start"] = _make_ability(
		&"test_ability_on_turn_start", "Test Turn Start Ability",
		Registry.AbilityTrigger.ON_TURN_START,
		Registry.StackLimit.UNLIMITED,
		[],
	)
	Atlas.abilities[&"test_ability_on_ally_faint"] = _make_ability(
		&"test_ability_on_ally_faint", "Test Ally Faint Ability",
		Registry.AbilityTrigger.ON_ALLY_FAINT,
		Registry.StackLimit.ONCE_PER_TURN,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["atk"], "stages": 1, "target": "self"}],
	)
	Atlas.abilities[&"test_ability_on_faint"] = _make_ability(
		&"test_ability_on_faint", "Test On Faint Ability",
		Registry.AbilityTrigger.ON_FAINT,
		Registry.StackLimit.ONCE_PER_BATTLE,
		[],
	)
	Atlas.abilities[&"test_ability_on_status"] = _make_ability(
		&"test_ability_on_status", "Test On Status Ability",
		Registry.AbilityTrigger.ON_STATUS_APPLIED,
		Registry.StackLimit.ONCE_PER_TURN,
		[],
	)
	# ON_EXIT: boost DEF +1 on switch-out
	Atlas.abilities[&"test_ability_on_exit"] = _make_ability(
		&"test_ability_on_exit", "Test Exit Ability",
		Registry.AbilityTrigger.ON_EXIT,
		Registry.StackLimit.ONCE_PER_SWITCH,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["def"], "stages": 1, "target": "self"}],
	)
	# ON_BEFORE_HIT: boost DEF +1 before being hit
	Atlas.abilities[&"test_ability_on_before_hit"] = _make_ability(
		&"test_ability_on_before_hit", "Test Before Hit Ability",
		Registry.AbilityTrigger.ON_BEFORE_HIT,
		Registry.StackLimit.ONCE_PER_TURN,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["def"], "stages": 1, "target": "self"}],
	)
	# ON_AFTER_HIT: boost SPE +1 after being hit
	Atlas.abilities[&"test_ability_on_after_hit"] = _make_ability(
		&"test_ability_on_after_hit", "Test After Hit Ability",
		Registry.AbilityTrigger.ON_AFTER_HIT,
		Registry.StackLimit.ONCE_PER_TURN,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["spe"], "stages": 1, "target": "self"}],
	)
	# ON_STAT_CHANGE: boost SPE +1 when any stat changes
	Atlas.abilities[&"test_ability_on_stat_change"] = _make_ability(
		&"test_ability_on_stat_change", "Test Stat Change Ability",
		Registry.AbilityTrigger.ON_STAT_CHANGE,
		Registry.StackLimit.ONCE_PER_TURN,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["spe"], "stages": 1, "target": "self"}],
	)
	# ON_STATUS_INFLICTED: boost ATK +1 when user inflicts a status on a foe
	Atlas.abilities[&"test_ability_on_status_inflicted"] = _make_ability(
		&"test_ability_on_status_inflicted", "Test Status Inflicted Ability",
		Registry.AbilityTrigger.ON_STATUS_INFLICTED,
		Registry.StackLimit.ONCE_PER_TURN,
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["atk"], "stages": 1, "target": "self"}],
	)
	# CONTINUOUS damageModifier: 1.5x fire damage when HP < 50%
	Atlas.abilities[&"test_ability_blaze"] = _make_ability(
		&"test_ability_blaze", "Test Blaze",
		Registry.AbilityTrigger.CONTINUOUS,
		Registry.StackLimit.UNLIMITED,
		[{
			"brick": "damageModifier",
			"condition": "damageTypeIs:fire|userHpBelow:50",
			"multiplier": 1.5,
		}],
	)
	# CONTINUOUS damageModifier: 1.5x fire damage (no HP condition)
	Atlas.abilities[&"test_ability_boost_fire"] = _make_ability(
		&"test_ability_boost_fire", "Test Boost Fire",
		Registry.AbilityTrigger.CONTINUOUS,
		Registry.StackLimit.UNLIMITED,
		[{
			"brick": "damageModifier",
			"condition": "damageTypeIs:fire",
			"multiplier": 1.5,
		}],
	)


static func _make_ability(
	key: StringName,
	ability_name: String,
	trigger: Registry.AbilityTrigger,
	stack_limit: Registry.StackLimit,
	bricks: Array,
	trigger_condition: String = "",
) -> AbilityData:
	var a := AbilityData.new()
	a.key = key
	a.name = ability_name
	a.trigger = trigger
	a.stack_limit = stack_limit
	a.trigger_condition = trigger_condition
	for brick: Variant in bricks:
		a.bricks.append(brick as Dictionary)
	return a


# --- Item data ---


static func _inject_items() -> void:
	# Medicine: fixed HP heal
	Atlas.items[&"test_potion"] = _make_medicine(
		&"test_potion", "Test Potion",
		[{"brick": "healing", "type": "fixed", "amount": 50}],
	)
	# Medicine: percentage HP heal
	Atlas.items[&"test_super_potion"] = _make_medicine(
		&"test_super_potion", "Test Super Potion",
		[{"brick": "healing", "type": "percentage", "percent": 50}],
	)
	# Medicine: fixed energy restore
	Atlas.items[&"test_energy_drink"] = _make_medicine(
		&"test_energy_drink", "Test Energy Drink",
		[{"brick": "healing", "type": "energy_fixed", "amount": 30}],
	)
	# Medicine: cure burned status
	Atlas.items[&"test_burn_heal"] = _make_medicine(
		&"test_burn_heal", "Test Burn Heal",
		[{"brick": "healing", "type": "fixed", "amount": 0, "cureStatus": "burned"}],
	)
	# Medicine: full heal (100% HP + cure major statuses)
	Atlas.items[&"test_full_heal"] = _make_medicine(
		&"test_full_heal", "Test Full Heal",
		[{"brick": "healing", "type": "percentage", "percent": 100, "cureStatus": ["burned", "paralysed", "poisoned", "frostbitten"]}],
	)
	# Medicine: revive (50% HP to fainted Digimon)
	Atlas.items[&"test_revive"] = _make_medicine(
		&"test_revive", "Test Revive",
		[{"brick": "healing", "type": "percentage", "percent": 50}],
		true,  # is_revive
	)
	# Medicine: stat boost (ATK +2)
	Atlas.items[&"test_x_attack"] = _make_medicine(
		&"test_x_attack", "Test X Attack",
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["atk"], "stages": 2, "target": "self"}],
	)
	# Equipable gear: CONTINUOUS 1.2x damage
	Atlas.items[&"test_power_band"] = _make_gear(
		&"test_power_band", "Test Power Band",
		Registry.GearSlot.EQUIPABLE,
		Registry.AbilityTrigger.CONTINUOUS,
		Registry.StackLimit.UNLIMITED,
		"",
		[{"brick": "damageModifier", "multiplier": 1.2}],
	)
	# Equipable gear: ON_TAKE_DAMAGE DEF +1
	Atlas.items[&"test_counter_gem"] = _make_gear(
		&"test_counter_gem", "Test Counter Gem",
		Registry.GearSlot.EQUIPABLE,
		Registry.AbilityTrigger.ON_TAKE_DAMAGE,
		Registry.StackLimit.ONCE_PER_TURN,
		"",
		[{"brick": "statModifier", "modifierType": "stage", "stats": ["def"], "stages": 1, "target": "self"}],
	)
	# Consumable gear: ON_HP_THRESHOLD (<50% HP) heal 25%
	Atlas.items[&"test_heal_berry"] = _make_gear(
		&"test_heal_berry", "Test Heal Berry",
		Registry.GearSlot.CONSUMABLE,
		Registry.AbilityTrigger.ON_HP_THRESHOLD,
		Registry.StackLimit.ONCE_PER_BATTLE,
		"userHpBelow:50",
		[{"brick": "healing", "type": "percentage", "percent": 25}],
	)
	# Consumable gear: ON_BEFORE_HIT reduce super-effective by 0.5x
	Atlas.items[&"test_element_guard"] = _make_gear(
		&"test_element_guard", "Test Element Guard",
		Registry.GearSlot.CONSUMABLE,
		Registry.AbilityTrigger.CONTINUOUS,
		Registry.StackLimit.UNLIMITED,
		"",
		[{"brick": "damageModifier", "condition": "damageIsSuperEffective", "multiplier": 0.5}],
	)
	# Capture/scan item
	Atlas.items[&"test_scanner"] = _make_capture_item(
		&"test_scanner", "Test Scanner",
	)


static func _make_medicine(
	key: StringName,
	item_name: String,
	bricks: Array,
	is_revive: bool = false,
) -> ItemData:
	var item := ItemData.new()
	item.key = key
	item.name = item_name
	item.category = Registry.ItemCategory.MEDICINE
	item.is_consumable = true
	item.is_combat_usable = true
	item.is_revive = is_revive
	for brick: Variant in bricks:
		item.bricks.append(brick as Dictionary)
	return item


static func _make_gear(
	key: StringName,
	gear_name: String,
	slot: Registry.GearSlot,
	trigger: Registry.AbilityTrigger,
	stack_limit: Registry.StackLimit,
	trigger_condition: String,
	bricks: Array,
) -> GearData:
	var gear := GearData.new()
	gear.key = key
	gear.name = gear_name
	gear.category = Registry.ItemCategory.GEAR
	gear.is_consumable = (slot == Registry.GearSlot.CONSUMABLE)
	gear.is_combat_usable = false
	gear.gear_slot = slot
	gear.trigger = trigger
	gear.stack_limit = stack_limit
	gear.trigger_condition = trigger_condition
	for brick: Variant in bricks:
		gear.bricks.append(brick as Dictionary)
	return gear


static func _make_capture_item(
	key: StringName,
	item_name: String,
) -> ItemData:
	var item := ItemData.new()
	item.key = key
	item.name = item_name
	item.category = Registry.ItemCategory.CAPTURE_SCAN
	item.is_consumable = true
	item.is_combat_usable = true
	return item


# --- DigimonState creation ---


## Create a DigimonState with predictable values (IV=0, TV=0, test_neutral personality).
static func make_digimon_state(
	key: StringName,
	level: int = 50,
	personality_key: StringName = &"test_neutral",
	techniques: Array[StringName] = [],
) -> DigimonState:
	var state := DigimonState.new()
	state.key = key
	state.level = level
	state.personality_key = personality_key
	state.ivs = {
		&"hp": 0, &"energy": 0, &"attack": 0, &"defence": 0,
		&"special_attack": 0, &"special_defence": 0, &"speed": 0,
	}
	state.tvs = {
		&"hp": 0, &"energy": 0, &"attack": 0, &"defence": 0,
		&"special_attack": 0, &"special_defence": 0, &"speed": 0,
	}
	state.active_ability_slot = 1

	# Default equipped techniques
	if techniques.is_empty():
		state.equipped_technique_keys = [
			&"test_tackle", &"test_fire_blast", &"test_status_burn", &"test_boost_attack",
		]
	else:
		state.equipped_technique_keys = techniques.duplicate()
	state.known_technique_keys = state.equipped_technique_keys.duplicate()

	# Calculate HP/energy from formula
	var data: DigimonData = Atlas.digimon.get(key) as DigimonData
	if data != null:
		var stats: Dictionary = StatCalculator.calculate_all_stats(data, state)
		var personality: PersonalityData = Atlas.personalities.get(
			personality_key,
		) as PersonalityData
		for stat_key: StringName in stats:
			stats[stat_key] = StatCalculator.apply_personality(
				stats[stat_key], stat_key, personality,
			)
		state.current_hp = stats.get(&"hp", 100)
		state.current_energy = stats.get(&"energy", 50)

	return state


# --- Battle creation ---


## Create a 1v1 singles battle.
static func create_1v1_battle(
	s0_key: StringName = &"test_agumon",
	s1_key: StringName = &"test_gabumon",
	seed: int = DEFAULT_SEED,
) -> BattleState:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": [make_digimon_state(s0_key)] as Array[DigimonState],
		"is_wild": false,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": [make_digimon_state(s1_key)] as Array[DigimonState],
		"is_wild": false,
	}
	return BattleFactory.create_battle(config, seed)


## Create a 2v2 doubles battle.
static func create_2v2_battle(
	s0_keys: Array[StringName] = [&"test_agumon", &"test_patamon"],
	s1_keys: Array[StringName] = [&"test_gabumon", &"test_tank"],
	seed: int = DEFAULT_SEED,
) -> BattleState:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.DOUBLES_2V2)
	var party_0: Array[DigimonState] = []
	for key: StringName in s0_keys:
		party_0.append(make_digimon_state(key))
	var party_1: Array[DigimonState] = []
	for key: StringName in s1_keys:
		party_1.append(make_digimon_state(key))
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": party_0,
		"is_wild": false,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": party_1,
		"is_wild": false,
	}
	return BattleFactory.create_battle(config, seed)


## Create a 1v1 battle where each side has reserves in the party.
static func create_1v1_with_reserves(
	s0_keys: Array[StringName] = [&"test_agumon", &"test_patamon"],
	s1_keys: Array[StringName] = [&"test_gabumon", &"test_tank"],
	seed: int = DEFAULT_SEED,
) -> BattleState:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)
	var party_0: Array[DigimonState] = []
	for key: StringName in s0_keys:
		party_0.append(make_digimon_state(key))
	var party_1: Array[DigimonState] = []
	for key: StringName in s1_keys:
		party_1.append(make_digimon_state(key))
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": party_0,
		"is_wild": false,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": party_1,
		"is_wild": false,
	}
	return BattleFactory.create_battle(config, seed)


## Create a 1v1 wild battle (can flee).
static func create_wild_battle(
	s0_key: StringName = &"test_agumon",
	s1_key: StringName = &"test_gabumon",
	seed: int = DEFAULT_SEED,
) -> BattleState:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": [make_digimon_state(s0_key)] as Array[DigimonState],
		"is_wild": false,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": [make_digimon_state(s1_key)] as Array[DigimonState],
		"is_wild": true,
	}
	return BattleFactory.create_battle(config, seed)


# --- Action helpers ---


static func make_technique_action(
	user_side: int,
	user_slot: int,
	tech_key: StringName,
	target_side: int,
	target_slot: int,
) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = BattleAction.ActionType.TECHNIQUE
	action.user_side = user_side
	action.user_slot = user_slot
	action.technique_key = tech_key
	action.target_side = target_side
	action.target_slot = target_slot
	return action


static func make_switch_action(
	user_side: int, user_slot: int, party_index: int,
) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = BattleAction.ActionType.SWITCH
	action.user_side = user_side
	action.user_slot = user_slot
	action.switch_to_party_index = party_index
	return action


static func make_rest_action(user_side: int, user_slot: int) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = BattleAction.ActionType.REST
	action.user_side = user_side
	action.user_slot = user_slot
	return action


static func make_run_action(user_side: int, user_slot: int) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = BattleAction.ActionType.RUN
	action.user_side = user_side
	action.user_slot = user_slot
	return action


static func make_item_action(
	user_side: int,
	user_slot: int,
	item_key: StringName,
	party_index: int = 0,
	target_side: int = -1,
	target_slot: int = -1,
) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = BattleAction.ActionType.ITEM
	action.user_side = user_side
	action.user_slot = user_slot
	action.item_key = item_key
	action.item_target_party_index = party_index
	if target_side >= 0:
		action.target_side = target_side
		action.target_slot = target_slot
	return action


# --- Battle creation with bag ---


## Create a 1v1 battle where side 0 has a bag with items.
static func create_1v1_battle_with_bag(
	s0_key: StringName = &"test_agumon",
	s1_key: StringName = &"test_gabumon",
	bag_items: Dictionary = {},  ## {StringName: int} — item_key -> quantity
	seed: int = DEFAULT_SEED,
) -> BattleState:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)
	var bag := BagState.new()
	for key: StringName in bag_items:
		bag.add_item(key, int(bag_items[key]))
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": [make_digimon_state(s0_key)] as Array[DigimonState],
		"is_wild": false,
		"bag": bag,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": [make_digimon_state(s1_key)] as Array[DigimonState],
		"is_wild": false,
	}
	return BattleFactory.create_battle(config, seed)


## Create a 1v1 battle with reserves and a bag for side 0.
static func create_1v1_with_reserves_and_bag(
	s0_keys: Array[StringName] = [&"test_agumon", &"test_patamon"],
	s1_keys: Array[StringName] = [&"test_gabumon", &"test_tank"],
	bag_items: Dictionary = {},
	seed: int = DEFAULT_SEED,
) -> BattleState:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)
	var party_0: Array[DigimonState] = []
	for key: StringName in s0_keys:
		party_0.append(make_digimon_state(key))
	var party_1: Array[DigimonState] = []
	for key: StringName in s1_keys:
		party_1.append(make_digimon_state(key))
	var bag := BagState.new()
	for key: StringName in bag_items:
		bag.add_item(key, int(bag_items[key]))
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": party_0,
		"is_wild": false,
		"bag": bag,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": party_1,
		"is_wild": false,
	}
	return BattleFactory.create_battle(config, seed)


## Create a 3-way FFA battle (3 sides, each on own team).
static func create_3_way_ffa_battle(
	s0_key: StringName = &"test_agumon",
	s1_key: StringName = &"test_gabumon",
	s2_key: StringName = &"test_patamon",
	seed: int = DEFAULT_SEED,
) -> BattleState:
	var config := BattleConfig.new()
	config.apply_preset(BattleConfig.FormatPreset.FFA_3)
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": [make_digimon_state(s0_key)] as Array[DigimonState],
		"is_wild": false,
	}
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": [make_digimon_state(s1_key)] as Array[DigimonState],
		"is_wild": false,
	}
	config.side_configs[2] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": [make_digimon_state(s2_key)] as Array[DigimonState],
		"is_wild": false,
	}
	return BattleFactory.create_battle(config, seed)


## Simulate switching out the active Digimon in a slot to reserves, without
## running the full engine. Useful for testing XP participation tracking.
static func simulate_switch_out(
	battle: BattleState, side_index: int, slot_index: int,
) -> void:
	var side: SideState = battle.sides[side_index]
	var slot: SlotState = side.slots[slot_index]
	var outgoing: BattleDigimonState = slot.digimon
	if outgoing == null:
		return
	outgoing.reset_volatiles()
	if outgoing.source_state != null:
		outgoing.source_state.current_hp = outgoing.current_hp
		outgoing.source_state.current_energy = outgoing.current_energy
		outgoing.source_state.equipped_consumable_key = outgoing.equipped_consumable_key
		side.party.append(outgoing.source_state)
	side.retired_battle_digimon.append(outgoing)
	slot.digimon = null


# --- Engine setup ---


static func create_engine(battle: BattleState) -> BattleEngine:
	var engine := BattleEngine.new()
	engine.initialise(battle)
	return engine
