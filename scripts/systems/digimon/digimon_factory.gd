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


## Create a new Digimon with randomised evolution history.
## Uses the provided RNG for deterministic results.
static func create_digimon_with_history(
	digimon_key: StringName,
	level: int = 1,
	nickname: String = "",
	rng: RandomNumberGenerator = null,
) -> DigimonState:
	var state: DigimonState = create_digimon(digimon_key, level, nickname)
	if state == null:
		return null
	_backfill_evolution_history(state, level, rng)
	return state


## Walk backward from the current species to Baby I, building a plausible
## evolution chain. Populates state.evolution_history.
static func _backfill_evolution_history(
	state: DigimonState,
	level: int,
	rng: RandomNumberGenerator,
) -> void:
	# Build reverse index: to_key → Array[EvolutionLinkData]
	var reverse_index: Dictionary = {}
	for evo_key: StringName in Atlas.evolutions:
		var link: EvolutionLinkData = Atlas.evolutions[evo_key] as EvolutionLinkData
		if link == null:
			continue
		if not reverse_index.has(link.to_key):
			reverse_index[link.to_key] = []
		(reverse_index[link.to_key] as Array).append(link)

	# Walk backward
	var current_key: StringName = state.key
	var chain: Array[Dictionary] = []  # Built in reverse

	for _step: int in 20:  # Safety limit
		var current_data: DigimonData = Atlas.digimon.get(current_key) as DigimonData
		if current_data == null:
			break
		# Stop at Baby I (level 1) or below
		if current_data.level <= 1:
			break

		var predecessors: Array = reverse_index.get(current_key, [])
		if predecessors.is_empty():
			break

		# Separate into standard vs non-standard (excluding slide/mode change)
		var standard: Array[EvolutionLinkData] = []
		var other: Array[EvolutionLinkData] = []
		for pred: Variant in predecessors:
			var link: EvolutionLinkData = pred as EvolutionLinkData
			if link == null:
				continue
			match link.evolution_type:
				Registry.EvolutionType.SLIDE, Registry.EvolutionType.MODE_CHANGE:
					continue  # Skip lateral evos
				Registry.EvolutionType.STANDARD:
					standard.append(link)
				_:
					other.append(link)

		# Pick a predecessor — 95% standard, 5% non-standard
		var chosen: EvolutionLinkData = null
		var roll: float = rng.randf() if rng else randf()
		if not standard.is_empty() and (roll < 0.95 or other.is_empty()):
			var idx: int = (rng.randi() if rng else randi()) % standard.size()
			chosen = standard[idx]
		elif not other.is_empty():
			var idx: int = (rng.randi() if rng else randi()) % other.size()
			chosen = other[idx]
		else:
			break

		# Build history entry
		var item_key: StringName = EvolutionExecutor._get_item_key_from_requirements(
			chosen,
		)
		var jogress_partners: Array[Dictionary] = []

		# For jogress entries, synthesise partner snapshots
		if chosen.evolution_type == Registry.EvolutionType.JOGRESS:
			for partner_key: StringName in chosen.jogress_partner_keys:
				var partner: DigimonState = create_digimon(partner_key, level)
				if partner != null:
					var partner_dict: Dictionary = partner.to_dict()
					partner_dict["synthesised"] = true
					jogress_partners.append(partner_dict)

		var entry: Dictionary = {
			"from_key": chosen.from_key,
			"to_key": chosen.to_key,
			"evolution_type": chosen.evolution_type,
			"evolution_item_key": item_key,
		}
		if not jogress_partners.is_empty():
			entry["jogress_partners"] = jogress_partners

		chain.append(entry)
		current_key = chosen.from_key

	# Reverse to get chronological order
	chain.reverse()
	state.evolution_history = chain

	# Set final item holding and x_antibody from history
	if not chain.is_empty():
		# Find the last item-holding entry
		for i: int in range(chain.size() - 1, -1, -1):
			var entry_item: StringName = StringName(
				chain[i].get("evolution_item_key", ""),
			)
			var entry_type: int = chain[i].get("evolution_type", 0)
			if entry_item != &"" and entry_type in [
				Registry.EvolutionType.ARMOR,
				Registry.EvolutionType.SPIRIT,
				Registry.EvolutionType.MODE_CHANGE,
			]:
				state.evolution_item_key = entry_item
				break

		# Set x_antibody for any x_antibody entries in history
		for entry: Dictionary in chain:
			if entry.get("evolution_type", 0) == Registry.EvolutionType.X_ANTIBODY:
				# Ensure the Digimon meets x_antibody requirements
				state.x_antibody = maxi(state.x_antibody, 1)
