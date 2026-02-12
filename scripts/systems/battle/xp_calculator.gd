class_name XPCalculator
extends RefCounted
## Handles XP gain, level-up curves, and technique learning on level-up.


## Calculate XP awards for all victorious Digimon after battle.
## Returns an array of award dictionaries with keys:
##   digimon_state, xp, old_level, old_experience, old_stats,
##   levels_gained, new_techniques, participated
static func calculate_xp_awards(
	battle: BattleState, exp_share_enabled: bool = false,
) -> Array[Dictionary]:
	var awards: Array[Dictionary] = []

	if battle.result == null:
		return awards

	var winning_team: int = battle.result.winning_team
	if winning_team < 0:
		return awards

	# Collect defeated foes from all losing sides (active + retired)
	var defeated_foes: Array[Dictionary] = []
	for side: SideState in battle.sides:
		if side.team_index == winning_team:
			continue
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted:
				defeated_foes.append({
					"data": slot.digimon.data,
					"level": slot.digimon.source_state.level \
						if slot.digimon.source_state else 1,
					"source": slot.digimon.source_state,
				})
		for retired: BattleDigimonState in side.retired_battle_digimon:
			if retired.is_fainted:
				defeated_foes.append({
					"data": retired.data,
					"level": retired.source_state.level \
						if retired.source_state else 1,
					"source": retired.source_state,
				})

	if defeated_foes.is_empty():
		return awards

	# Collect ALL winning-side BattleDigimonState (active + retired)
	var winning_digimon: Array[BattleDigimonState] = []
	var seen_ids: Array[StringName] = []
	for side: SideState in battle.sides:
		if side.team_index != winning_team:
			continue
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.source_state != null:
				winning_digimon.append(slot.digimon)
				seen_ids.append(slot.digimon.source_state.unique_id)
		for retired: BattleDigimonState in side.retired_battle_digimon:
			if retired.source_state != null \
					and retired.source_state.unique_id not in seen_ids:
				winning_digimon.append(retired)
				seen_ids.append(retired.source_state.unique_id)

	# Award XP to each winning Digimon
	for battle_mon: BattleDigimonState in winning_digimon:
		if battle_mon.source_state == null:
			continue
		# Fainted allies get no XP
		if battle_mon.is_fainted:
			continue

		var state: DigimonState = battle_mon.source_state
		var total_xp: int = 0
		var did_participate: bool = false

		for foe: Dictionary in defeated_foes:
			var foe_data: DigimonData = foe["data"] as DigimonData
			if foe_data == null:
				continue

			var foe_source: DigimonState = foe["source"] as DigimonState
			var participated: bool = foe_source.unique_id in battle_mon.participated_against_ids

			if participated:
				did_participate = true
				var participants: int = _count_participants(
					battle, foe_source, winning_team,
				)
				total_xp += calculate_xp_gain(
					foe_data.base_xp_yield, int(foe["level"]),
					state.level, participants,
				)
			elif exp_share_enabled:
				# Non-participants get 50% XP (not split by participant count)
				var base_xp: int = calculate_xp_gain(
					foe_data.base_xp_yield, int(foe["level"]),
					state.level, 1,
				)
				@warning_ignore("integer_division")
				total_xp += maxi(base_xp / 2, 1)

		if total_xp <= 0:
			continue

		# Capture pre-XP state
		var old_level: int = state.level
		var old_experience: int = state.experience
		var old_stats: Dictionary = _calculate_display_stats(state)

		var result: Dictionary = apply_xp(state, total_xp)
		result["digimon_state"] = state
		result["xp"] = total_xp
		result["old_level"] = old_level
		result["old_experience"] = old_experience
		result["old_stats"] = old_stats
		result["participated"] = did_participate
		awards.append(result)

	# Award EXP Share to party reserves (never entered field)
	if exp_share_enabled:
		for side: SideState in battle.sides:
			if side.team_index != winning_team:
				continue
			for reserve: DigimonState in side.party:
				if reserve.unique_id in seen_ids:
					continue
				if reserve.current_hp <= 0:
					continue
				var reserve_xp: int = 0
				for foe: Dictionary in defeated_foes:
					var foe_data: DigimonData = foe["data"] as DigimonData
					if foe_data == null:
						continue
					var base_xp: int = calculate_xp_gain(
						foe_data.base_xp_yield, int(foe["level"]),
						reserve.level, 1,
					)
					@warning_ignore("integer_division")
					reserve_xp += maxi(base_xp / 2, 1)
				if reserve_xp <= 0:
					continue
				var old_level: int = reserve.level
				var old_experience: int = reserve.experience
				var old_stats: Dictionary = _calculate_display_stats(reserve)
				var result: Dictionary = apply_xp(reserve, reserve_xp)
				result["digimon_state"] = reserve
				result["xp"] = reserve_xp
				result["old_level"] = old_level
				result["old_experience"] = old_experience
				result["old_stats"] = old_stats
				result["participated"] = false
				awards.append(result)

	return awards


## Count how many winning-side Digimon participated against a specific foe.
## Includes both active and retired Digimon.
static func _count_participants(
	battle: BattleState, foe_source: DigimonState, winning_team: int,
) -> int:
	var count: int = 0
	for side: SideState in battle.sides:
		if side.team_index != winning_team:
			continue
		for slot: SlotState in side.slots:
			if slot.digimon != null \
					and foe_source.unique_id in slot.digimon.participated_against_ids:
				count += 1
		for retired: BattleDigimonState in side.retired_battle_digimon:
			if foe_source.unique_id in retired.participated_against_ids:
				count += 1
	return maxi(count, 1)


## Calculate display stats for a DigimonState (with personality applied).
static func _calculate_display_stats(state: DigimonState) -> Dictionary:
	var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
	if data == null:
		return {}
	var stats: Dictionary = StatCalculator.calculate_all_stats(data, state)
	var personality: PersonalityData = Atlas.personalities.get(
		state.personality_key,
	) as PersonalityData
	for stat_key: StringName in stats:
		stats[stat_key] = StatCalculator.apply_personality(
			stats[stat_key], stat_key, personality,
		)
	return stats


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
