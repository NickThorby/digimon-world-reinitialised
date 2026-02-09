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


## Remove all test data (keys starting with "test_") from Atlas.
static func clear_test_data() -> void:
	_clear_dict(Atlas.digimon)
	_clear_dict(Atlas.techniques)
	_clear_dict(Atlas.abilities)
	_clear_dict(Atlas.personalities)


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
	Atlas.digimon[&"test_agumon"] = _make_digimon(
		&"test_agumon", "Test Agumon", Registry.Attribute.VACCINE,
		[&"fire"], 80, 50, 100, 60, 50, 60, 80,
		{&"ice": 1.5, &"water": 1.5, &"fire": 0.5},
		&"test_ability_on_entry",
	)
	Atlas.digimon[&"test_gabumon"] = _make_digimon(
		&"test_gabumon", "Test Gabumon", Registry.Attribute.DATA,
		[&"ice"], 75, 50, 55, 65, 100, 70, 60,
		{&"fire": 1.5, &"ice": 0.5, &"earth": 0.5},
		&"test_ability_on_turn_start",
	)
	Atlas.digimon[&"test_patamon"] = _make_digimon(
		&"test_patamon", "Test Patamon", Registry.Attribute.VACCINE,
		[&"light"], 90, 50, 40, 70, 60, 80, 50,
		{&"dark": 0.0, &"light": 0.5},
		&"test_ability_on_ally_faint",
	)
	Atlas.digimon[&"test_tank"] = _make_digimon(
		&"test_tank", "Test Tank", Registry.Attribute.VIRUS,
		[&"dark"], 120, 50, 70, 100, 40, 100, 30,
		{&"dark": 0.0, &"light": 1.5},
		&"",
	)
	Atlas.digimon[&"test_speedster"] = _make_digimon(
		&"test_speedster", "Test Speedster", Registry.Attribute.DATA,
		[&"lightning"], 50, 50, 70, 40, 70, 40, 130,
		{&"earth": 1.5, &"lightning": 0.5},
		&"",
	)


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


# --- Engine setup ---


static func create_engine(battle: BattleState) -> BattleEngine:
	var engine := BattleEngine.new()
	engine.initialise(battle)
	return engine
