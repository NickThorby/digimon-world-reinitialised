class_name WildBattleFactory
extends RefCounted
## Factory for creating wild encounter BattleConfigs from zone data.
## All methods are static — no instance state needed.


## Create a wild encounter BattleConfig from a zone's encounter table.
## Rolls format, species, and levels, then builds a complete config.
static func create_encounter(
	zone: ZoneData,
	player_party: Array[DigimonState],
	player_bag: BagState,
	rng: RandomNumberGenerator,
) -> BattleConfig:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance

	# Roll format
	var weights: Dictionary = zone.format_weights
	if weights.is_empty() and balance != null:
		weights = balance.default_format_weights
	var format: BattleConfig.FormatPreset = roll_format(weights, rng)

	# Determine wild side slot count
	var slot_count: int = _get_slots_for_format(format)

	# Roll wild party
	var wild_party: Array[DigimonState] = []
	for i: int in slot_count:
		var entry: Dictionary = roll_species(zone.encounter_entries, rng, balance)
		if entry.is_empty():
			continue
		var level: int = roll_level(entry, zone, rng)
		var digimon_key: StringName = entry.get("digimon_key", &"")
		var digimon: DigimonState = DigimonFactory.create_digimon(digimon_key, level)
		if digimon != null:
			_set_level_techniques(digimon, level, balance, rng)
			_randomise_ability_slot(digimon, rng)
			wild_party.append(digimon)

	# Build config
	var config := BattleConfig.new()
	config.apply_preset(format)

	# Side 0: Player
	config.side_configs[0] = {
		"controller": BattleConfig.ControllerType.PLAYER,
		"party": player_party,
		"is_wild": false,
		"is_owned": true,
		"bag": player_bag,
	}

	# Side 1: Wild
	config.side_configs[1] = {
		"controller": BattleConfig.ControllerType.AI,
		"party": wild_party,
		"is_wild": true,
		"is_owned": false,
	}

	return config


## Roll a species from the encounter entries using rarity-weighted selection.
## Returns the selected entry Dictionary, or {} if entries is empty.
static func roll_species(
	entries: Array[Dictionary],
	rng: RandomNumberGenerator,
	balance: GameBalance = null,
) -> Dictionary:
	if entries.is_empty():
		return {}

	if balance == null:
		balance = load("res://data/config/game_balance.tres") as GameBalance

	var rarity_weights: Dictionary = balance.rarity_weights if balance != null else {
		0: 50, 1: 30, 2: 15, 3: 4, 4: 1,
	}

	# Build weighted pool
	var pool: Array[Dictionary] = []
	var weights: Array[int] = []
	var total_weight: int = 0

	for entry: Dictionary in entries:
		var rarity: int = int(entry.get("rarity", Registry.Rarity.COMMON))
		var weight: int = int(rarity_weights.get(rarity, 1))
		pool.append(entry)
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0:
		return entries[rng.randi() % entries.size()]

	# Weighted random selection
	var roll: int = rng.randi() % total_weight
	var cumulative: int = 0
	for i: int in pool.size():
		cumulative += weights[i]
		if roll < cumulative:
			return pool[i]

	return pool[pool.size() - 1]


## Roll a level for a given encounter entry within the zone's level range.
static func roll_level(
	entry: Dictionary, zone: ZoneData, rng: RandomNumberGenerator
) -> int:
	var range_dict: Dictionary = zone.get_encounter_level_range(entry)
	var min_lvl: int = range_dict["min"]
	var max_lvl: int = range_dict["max"]
	if min_lvl >= max_lvl:
		return min_lvl
	return rng.randi_range(min_lvl, max_lvl)


## Roll a battle format from weighted format presets.
## Keys are int(BattleConfig.FormatPreset) values.
static func roll_format(
	format_weights: Dictionary, rng: RandomNumberGenerator
) -> BattleConfig.FormatPreset:
	if format_weights.is_empty():
		return BattleConfig.FormatPreset.SINGLES_1V1

	var total_weight: int = 0
	for key: Variant in format_weights:
		total_weight += int(format_weights[key])

	if total_weight <= 0:
		return BattleConfig.FormatPreset.SINGLES_1V1

	var roll: int = rng.randi() % total_weight
	var cumulative: int = 0
	for key: Variant in format_weights:
		cumulative += int(format_weights[key])
		if roll < cumulative:
			return int(key) as BattleConfig.FormatPreset

	return BattleConfig.FormatPreset.SINGLES_1V1


## Returns the number of active slots per side for a given format preset.
static func _get_slots_for_format(preset: BattleConfig.FormatPreset) -> int:
	match preset:
		BattleConfig.FormatPreset.SINGLES_1V1:
			return 1
		BattleConfig.FormatPreset.DOUBLES_2V2:
			return 2
		BattleConfig.FormatPreset.TRIPLES_3V3:
			return 3
		_:
			return 1


## Set known and equipped techniques based on what the Digimon learns by its level.
## Equipped moves are randomly selected from the available pool (up to max_equipped).
static func _set_level_techniques(
	digimon: DigimonState,
	level: int,
	balance: GameBalance,
	rng: RandomNumberGenerator,
) -> void:
	var data: DigimonData = Atlas.digimon.get(digimon.key) as DigimonData
	if data == null:
		return
	var available: Array[StringName] = data.get_technique_keys_at_level(level)
	if available.is_empty():
		return

	var max_equipped: int = balance.max_equipped_techniques if balance else 4
	digimon.known_technique_keys = available.duplicate()

	# Randomly select equipped moves from available pool
	digimon.equipped_technique_keys.clear()
	var pool: Array[StringName] = available.duplicate()
	for i: int in mini(max_equipped, pool.size()):
		var idx: int = rng.randi() % pool.size()
		digimon.equipped_technique_keys.append(pool[idx])
		pool.remove_at(idx)


## Randomise the active ability slot among available ability slots.
static func _randomise_ability_slot(
	digimon: DigimonState, rng: RandomNumberGenerator
) -> void:
	var data: DigimonData = Atlas.digimon.get(digimon.key) as DigimonData
	if data == null:
		return
	var slots: Array[int] = []
	if data.ability_slot_1_key != &"":
		slots.append(1)
	if data.ability_slot_2_key != &"":
		slots.append(2)
	if data.ability_slot_3_key != &"":
		slots.append(3)
	if slots.size() > 1:
		digimon.active_ability_slot = slots[rng.randi() % slots.size()]
	elif slots.size() == 1:
		digimon.active_ability_slot = slots[0]
