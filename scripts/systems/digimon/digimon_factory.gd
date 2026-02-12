class_name DigimonFactory
extends RefCounted
## Creates new DigimonState instances from DigimonData templates.


## Create a new Digimon with random IVs and personality.
static func create_digimon(
	digimon_key: StringName,
	level: int = 1,
	nickname: String = ""
) -> DigimonState:
	var data: DigimonData = Atlas.digimon.get(digimon_key) as DigimonData
	if data == null:
		push_error("DigimonFactory: Unknown digimon key: %s" % digimon_key)
		return null

	var state := DigimonState.new()
	state.key = digimon_key
	var ids: Dictionary = IdGenerator.generate_digimon_ids()
	state.display_id = ids["display_id"]
	state.secret_id = ids["secret_id"]
	state.nickname = nickname
	state.level = level
	state.experience = XPCalculator.total_xp_for_level(level, data.growth_rate)

	# Roll random IVs (0 to max_iv per stat)
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_iv: int = balance.max_iv if balance else 50

	state.ivs = {
		&"hp": randi_range(0, max_iv),
		&"energy": randi_range(0, max_iv),
		&"attack": randi_range(0, max_iv),
		&"defence": randi_range(0, max_iv),
		&"special_attack": randi_range(0, max_iv),
		&"special_defence": randi_range(0, max_iv),
		&"speed": randi_range(0, max_iv),
	}

	# Initialise TVs to zero
	state.tvs = {
		&"hp": 0,
		&"energy": 0,
		&"attack": 0,
		&"defence": 0,
		&"special_attack": 0,
		&"special_defence": 0,
		&"speed": 0,
	}

	# Assign random personality
	var personality_keys := Atlas.personalities.keys()
	if personality_keys.size() > 0:
		state.personality_key = personality_keys[randi() % personality_keys.size()]

	# Set innate techniques as known and equipped
	var innate_keys: Array[StringName] = data.get_innate_technique_keys()
	state.known_technique_keys = innate_keys.duplicate()
	var max_equipped: int = balance.max_equipped_techniques if balance else 4
	for i: int in mini(innate_keys.size(), max_equipped):
		state.equipped_technique_keys.append(innate_keys[i])

	# Calculate initial HP and energy
	state.current_hp = StatCalculator.calculate_stat(data.base_hp, state.ivs.get(&"hp", 0), 0, level)
	state.current_energy = StatCalculator.calculate_stat(data.base_energy, state.ivs.get(&"energy", 0), 0, level)

	return state
