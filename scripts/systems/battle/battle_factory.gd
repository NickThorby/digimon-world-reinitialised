class_name BattleFactory
extends RefCounted
## Creates BattleState from BattleConfig.


## Create a fully initialised BattleState from a config.
static func create_battle(config: BattleConfig, rng_seed: int = -1) -> BattleState:
	var battle := BattleState.new()
	battle.config = config
	battle.field = FieldState.new()

	# Seed PRNG
	if rng_seed >= 0:
		battle.rng.seed = rng_seed
	else:
		battle.rng.randomize()

	# Create sides
	for i: int in config.side_count:
		var side_cfg: Dictionary = config.side_configs[i] if i < config.side_configs.size() else {}
		var side := SideState.new()
		side.side_index = i
		side.team_index = config.team_assignments[i] if i < config.team_assignments.size() else i
		side.controller = side_cfg.get("controller", BattleConfig.ControllerType.PLAYER) as BattleConfig.ControllerType
		side.is_wild = side_cfg.get("is_wild", false)
		side.is_owned = side_cfg.get("is_owned", false)

		# Copy bag if provided
		var bag: Variant = side_cfg.get("bag")
		if bag is BagState:
			side.bag = bag as BagState

		var party: Array = side_cfg.get("party", []) as Array
		var party_index: int = 0

		# Fill slots from party
		for s: int in config.slots_per_side:
			var slot := SlotState.new()
			slot.slot_index = s
			slot.side_index = i

			if party_index < party.size():
				var digimon_state: DigimonState = party[party_index] as DigimonState
				if digimon_state != null:
					slot.digimon = create_battle_digimon(digimon_state, i, s)
				party_index += 1

			side.slots.append(slot)

		# Remaining party goes to reserve
		while party_index < party.size():
			var digimon_state: DigimonState = party[party_index] as DigimonState
			if digimon_state != null:
				side.party.append(digimon_state)
			party_index += 1

		battle.sides.append(side)

	_apply_preset_effects(battle)
	return battle


## Create a BattleDigimonState from a persistent DigimonState.
static func create_battle_digimon(
	state: DigimonState,
	side_index: int,
	slot_index: int,
) -> BattleDigimonState:
	var battle_mon := BattleDigimonState.new()
	battle_mon.source_state = state
	battle_mon.data = Atlas.digimon.get(state.key) as DigimonData
	battle_mon.side_index = side_index
	battle_mon.slot_index = slot_index

	# Calculate stats
	if battle_mon.data != null:
		var all_stats: Dictionary = StatCalculator.calculate_all_stats(
			battle_mon.data, state
		)

		# Apply personality
		var personality: PersonalityData = Atlas.personalities.get(
			state.personality_key
		) as PersonalityData
		for stat_key: StringName in all_stats:
			all_stats[stat_key] = StatCalculator.apply_personality(
				all_stats[stat_key], stat_key, personality
			)

		battle_mon.base_stats = all_stats
		battle_mon.max_hp = all_stats.get(&"hp", 1)
		battle_mon.max_energy = all_stats.get(&"energy", 1)
	else:
		battle_mon.max_hp = 1
		battle_mon.max_energy = 1

	# Snapshot current HP/energy from source
	battle_mon.current_hp = state.current_hp if state.current_hp > 0 else battle_mon.max_hp
	battle_mon.current_energy = state.current_energy if state.current_energy > 0 else battle_mon.max_energy

	# Copy techniques
	battle_mon.equipped_technique_keys = state.equipped_technique_keys.duplicate()
	battle_mon.known_technique_keys = state.known_technique_keys.duplicate()

	# Resolve ability
	if battle_mon.data != null:
		match state.active_ability_slot:
			1: battle_mon.ability_key = battle_mon.data.ability_slot_1_key
			2: battle_mon.ability_key = battle_mon.data.ability_slot_2_key
			3: battle_mon.ability_key = battle_mon.data.ability_slot_3_key

	# Copy gear
	battle_mon.equipped_gear_key = state.equipped_gear_key
	battle_mon.equipped_consumable_key = state.equipped_consumable_key

	# Copy persistent status conditions
	for status: Dictionary in state.status_conditions:
		battle_mon.status_conditions.append(status.duplicate())

	return battle_mon


## Apply preset field effects from config to the battle state.
static func _apply_preset_effects(battle: BattleState) -> void:
	var config: BattleConfig = battle.config
	var presets: Dictionary = config.preset_field_effects
	var stored: Dictionary = {
		"weather": &"",
		"terrain": &"",
		"global_effects": [] as Array[StringName],
		"side_effects": [] as Array[Dictionary],
		"hazards": [] as Array[Dictionary],
	}

	# Weather
	var weather: Dictionary = presets.get("weather", {})
	if not weather.is_empty():
		var key: StringName = StringName(weather.get("key", ""))
		var permanent: bool = weather.get("permanent", false)
		var duration: int = -1 if permanent else int(weather.get("duration", 5))
		battle.field.set_weather(key, duration, -1)
		if permanent:
			stored["weather"] = key

	# Terrain
	var terrain: Dictionary = presets.get("terrain", {})
	if not terrain.is_empty():
		var key: StringName = StringName(terrain.get("key", ""))
		var permanent: bool = terrain.get("permanent", false)
		var duration: int = -1 if permanent else int(terrain.get("duration", 5))
		battle.field.set_terrain(key, duration, -1)
		if permanent:
			stored["terrain"] = key

	# Global effects
	for effect: Dictionary in presets.get("global_effects", []):
		var key: StringName = StringName(effect.get("key", ""))
		var permanent: bool = effect.get("permanent", false)
		var duration: int = -1 if permanent else int(effect.get("duration", 5))
		battle.field.add_global_effect(key, duration)
		if permanent:
			stored["global_effects"].append(key)

	# Side effects
	for entry: Dictionary in config.preset_side_effects:
		var key: StringName = StringName(entry.get("key", ""))
		var permanent: bool = entry.get("permanent", false)
		var duration: int = -1 if permanent else int(entry.get("duration", 5))
		var sides: Array = entry.get("sides", [])
		var target_sides: Array[int] = []
		if sides.is_empty():
			for i: int in battle.sides.size():
				target_sides.append(i)
		else:
			for s: Variant in sides:
				target_sides.append(int(s))
		for side_idx: int in target_sides:
			if side_idx < battle.sides.size():
				battle.sides[side_idx].add_side_effect(key, duration)
		if permanent:
			stored["side_effects"].append({"key": key, "sides": target_sides})

	# Hazards
	for entry: Dictionary in config.preset_hazards:
		var key: StringName = StringName(entry.get("key", ""))
		var permanent: bool = entry.get("permanent", false)
		var layers: int = int(entry.get("layers", 1))
		var extra: Dictionary = entry.get("extra", {})
		var sides: Array = entry.get("sides", [])
		var target_sides: Array[int] = []
		if sides.is_empty():
			for i: int in battle.sides.size():
				target_sides.append(i)
		else:
			for s: Variant in sides:
				target_sides.append(int(s))
		for side_idx: int in target_sides:
			if side_idx < battle.sides.size():
				battle.sides[side_idx].add_hazard(key, layers, extra)
		if permanent:
			stored["hazards"].append({
				"key": key, "sides": target_sides,
				"layers": layers, "extra": extra,
			})

	battle.preset_effects = stored
