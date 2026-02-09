class_name XPCalculator
extends RefCounted
## Handles XP gain, level-up curves, and technique learning on level-up.


## Calculate XP awards for all victorious Digimon after battle.
static func calculate_xp_awards(battle: BattleState) -> Array[Dictionary]:
	var awards: Array[Dictionary] = []

	if battle.result == null:
		return awards

	# Collect defeated foe data (need base_xp_yield and level)
	var defeated_foes: Array[Dictionary] = []
	for side: SideState in battle.sides:
		if battle.are_foes(0, side.side_index):
			for slot: SlotState in side.slots:
				if slot.digimon != null and slot.digimon.is_fainted:
					defeated_foes.append({
						"data": slot.digimon.data,
						"level": slot.digimon.source_state.level if slot.digimon.source_state else 1,
						"key": slot.digimon.source_state.key if slot.digimon.source_state else &"",
					})

	if defeated_foes.is_empty():
		return awards

	# Award XP to each Digimon on the winning side
	for side: SideState in battle.sides:
		if not battle.are_foes(0, side.side_index):
			# Check all slots + reserve
			var all_digimon: Array[BattleDigimonState] = []
			for slot: SlotState in side.slots:
				if slot.digimon != null:
					all_digimon.append(slot.digimon)

			for battle_mon: BattleDigimonState in all_digimon:
				if battle_mon.source_state == null:
					continue

				var total_xp: int = 0
				for foe: Dictionary in defeated_foes:
					var foe_data: DigimonData = foe["data"] as DigimonData
					if foe_data == null:
						continue

					# Check if this Digimon participated against this foe
					var foe_key: StringName = foe["key"] as StringName
					var participants: int = _count_participants(battle, foe_key)
					participants = maxi(participants, 1)

					total_xp += calculate_xp_gain(
						foe_data.base_xp_yield,
						int(foe["level"]),
						battle_mon.source_state.level,
						participants,
					)

				if total_xp > 0:
					var award: Dictionary = apply_xp(battle_mon.source_state, total_xp)
					award["digimon_state"] = battle_mon.source_state
					award["xp"] = total_xp
					awards.append(award)

	return awards


## Count how many allied Digimon participated against a specific foe.
static func _count_participants(battle: BattleState, foe_key: StringName) -> int:
	var count: int = 0
	for side: SideState in battle.sides:
		if not battle.are_foes(0, side.side_index):
			for slot: SlotState in side.slots:
				if slot.digimon != null and foe_key in slot.digimon.participated_against:
					count += 1
	return maxi(count, 1)


## Gen V-style XP gain formula.
static func calculate_xp_gain(
	base_yield: int,
	defeated_level: int,
	victor_level: int,
	participant_count: int,
) -> int:
	var a: float = float(base_yield) * float(defeated_level) / 5.0
	var b: float = 1.0 / float(maxi(participant_count, 1))
	var level_factor: float = float(2 * defeated_level + 10) / float(
		defeated_level + victor_level + 10
	)
	var c: float = pow(level_factor, 2.5) + 1.0
	return maxi(floori(a * b * c), 1)


## Apply XP to a DigimonState, handling level-ups.
## Returns { "levels_gained": int, "new_techniques": Array[StringName] }
static func apply_xp(state: DigimonState, xp: int) -> Dictionary:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var max_level: int = balance.max_level if balance else 100

	state.experience += xp
	var levels_gained: int = 0
	var new_techniques: Array[StringName] = []

	var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
	if data == null:
		return {"levels_gained": 0, "new_techniques": new_techniques}

	# Level up while we have enough XP
	while state.level < max_level:
		var needed: int = total_xp_for_level(state.level + 1, data.growth_rate)
		if state.experience < needed:
			break

		state.level += 1
		levels_gained += 1

		# Check for new techniques at this level
		var learnable: Array[StringName] = data.get_technique_keys_at_level(state.level)
		for tech_key: StringName in learnable:
			if tech_key not in state.known_technique_keys:
				state.known_technique_keys.append(tech_key)
				new_techniques.append(tech_key)

	# Recalculate stats after level-up
	if levels_gained > 0 and data != null:
		var stats: Dictionary = StatCalculator.calculate_all_stats(data, state)
		state.current_hp = stats.get(&"hp", state.current_hp)
		state.current_energy = stats.get(&"energy", state.current_energy)

	return {"levels_gained": levels_gained, "new_techniques": new_techniques}


## Total XP required to reach a given level, based on growth rate.
static func total_xp_for_level(level: int, growth_rate: Registry.GrowthRate) -> int:
	if level <= 1:
		return 0

	var n: float = float(level)
	var n3: float = n * n * n

	match growth_rate:
		Registry.GrowthRate.FAST:
			return maxi(floori(4.0 * n3 / 5.0), 0)

		Registry.GrowthRate.MEDIUM_FAST:
			return maxi(floori(n3), 0)

		Registry.GrowthRate.MEDIUM_SLOW:
			return maxi(floori(6.0 * n3 / 5.0 - 15.0 * n * n + 100.0 * n - 140.0), 0)

		Registry.GrowthRate.SLOW:
			return maxi(floori(5.0 * n3 / 4.0), 0)

		Registry.GrowthRate.ERRATIC:
			if level < 50:
				return maxi(floori(n3 * (100.0 - n) / 50.0), 0)
			elif level < 68:
				return maxi(floori(n3 * (150.0 - n) / 100.0), 0)
			elif level < 98:
				return maxi(floori(n3 * float(floori((1911.0 - 10.0 * n) / 3.0)) / 500.0), 0)
			else:
				return maxi(floori(n3 * (160.0 - n) / 100.0), 0)

		Registry.GrowthRate.FLUCTUATING:
			if level < 15:
				return maxi(floori(n3 * (float(floori((n + 1.0) / 3.0)) + 24.0) / 50.0), 0)
			elif level < 36:
				return maxi(floori(n3 * (n + 14.0) / 50.0), 0)
			else:
				return maxi(floori(n3 * (float(floori(n / 2.0)) + 32.0) / 50.0), 0)

	return maxi(floori(n3), 0)


## Convenience: XP needed to reach the next level from current state.
static func xp_to_next_level(
	current_level: int,
	current_xp: int,
	growth_rate: Registry.GrowthRate,
) -> int:
	return maxi(total_xp_for_level(current_level + 1, growth_rate) - current_xp, 0)
