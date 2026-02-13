class_name ItemApplicator
extends RefCounted
## Applies item bricks to a Digimon outside of battle.
## Handles healing (bug-fixed) and outOfBattleEffect bricks.


## Applies an item's bricks to a Digimon. Returns true if anything was applied.
static func apply(
	item_data: ItemData,
	digimon: DigimonState,
	max_hp: int,
	max_energy: int,
) -> bool:
	var any_applied: bool = false
	for brick: Dictionary in item_data.bricks:
		var brick_type: String = str(brick.get("brick", ""))
		match brick_type:
			"healing":
				if _apply_healing(brick, digimon, max_hp, max_energy):
					any_applied = true
			"outOfBattleEffect":
				if _apply_out_of_battle_effect(brick, digimon):
					any_applied = true
	return any_applied


## Calculates max HP and max energy for a Digimon (personality-aware).
## Returns {"max_hp": int, "max_energy": int}.
static func get_max_stats(digimon: DigimonState) -> Dictionary:
	var data: DigimonData = Atlas.digimon.get(digimon.key) as DigimonData
	if data == null:
		return {"max_hp": 1, "max_energy": 1}

	var stats: Dictionary = StatCalculator.calculate_all_stats(data, digimon)
	var personality: PersonalityData = Atlas.personalities.get(
		digimon.get_effective_personality_key(),
	) as PersonalityData
	var max_hp: int = StatCalculator.apply_personality(
		stats.get(&"hp", 1), &"hp", personality,
	)
	var max_energy: int = StatCalculator.apply_personality(
		stats.get(&"energy", 1), &"energy", personality,
	)
	return {"max_hp": max_hp, "max_energy": max_energy}


static func _apply_healing(
	brick: Dictionary,
	digimon: DigimonState,
	max_hp: int,
	max_energy: int,
) -> bool:
	var type: String = str(brick.get("type", ""))
	var amount: int = int(brick.get("amount", 0))
	var percent: float = float(brick.get("percent", 0.0))

	var old_hp: int = digimon.current_hp
	var old_energy: int = digimon.current_energy
	var old_status_count: int = digimon.status_conditions.size()

	match type:
		"fixed":
			digimon.current_hp = mini(digimon.current_hp + amount, max_hp)
			return digimon.current_hp != old_hp
		"percentage":
			var heal: int = floori(max_hp * percent / 100.0)
			digimon.current_hp = mini(digimon.current_hp + heal, max_hp)
			_cure_statuses(brick, digimon)
			return digimon.current_hp != old_hp \
				or digimon.status_conditions.size() != old_status_count
		"status":
			if amount > 0:
				digimon.current_hp = mini(digimon.current_hp + amount, max_hp)
			elif percent > 0.0:
				var heal: int = floori(max_hp * percent / 100.0)
				digimon.current_hp = mini(digimon.current_hp + heal, max_hp)
			_cure_statuses(brick, digimon)
			return digimon.current_hp != old_hp \
				or digimon.status_conditions.size() != old_status_count
		"full_restore":
			digimon.current_hp = max_hp
			digimon.current_energy = max_energy
			digimon.status_conditions.clear()
			return digimon.current_hp != old_hp \
				or digimon.current_energy != old_energy \
				or old_status_count > 0
		"revive":
			if digimon.current_hp <= 0:
				if percent > 0.0:
					digimon.current_hp = maxi(
						floori(max_hp * percent / 100.0), 1,
					)
				else:
					@warning_ignore("integer_division")
					digimon.current_hp = maxi(max_hp / 2, 1)
				return true
			return false
		"energy_fixed":
			digimon.current_energy = mini(
				digimon.current_energy + amount, max_energy,
			)
			return digimon.current_energy != old_energy
		"energy_percentage":
			var heal: int = floori(max_energy * percent / 100.0)
			digimon.current_energy = mini(
				digimon.current_energy + heal, max_energy,
			)
			return digimon.current_energy != old_energy
	return false


## Cure status conditions from a brick's cureStatus field.
## Handles both String and Array values.
static func _cure_statuses(brick: Dictionary, digimon: DigimonState) -> void:
	var raw_cure: Variant = brick.get("cureStatus", null)
	if raw_cure == null:
		return

	var cure_list: Array = []
	if raw_cure is String:
		cure_list = [raw_cure]
	elif raw_cure is Array:
		cure_list = raw_cure as Array
	else:
		return

	if cure_list.is_empty():
		return

	var remaining: Array[Dictionary] = []
	for condition: Dictionary in digimon.status_conditions:
		var cond_key: String = str(condition.get("key", ""))
		if cond_key not in cure_list:
			remaining.append(condition)
	digimon.status_conditions = remaining


static func _apply_out_of_battle_effect(
	brick: Dictionary, digimon: DigimonState,
) -> bool:
	var effect: String = str(brick.get("effect", ""))
	var value: String = str(brick.get("value", ""))

	match effect:
		"toggleAbility":
			var data: DigimonData = Atlas.digimon.get(digimon.key) as DigimonData
			if data and data.ability_slot_2_key != &"":
				digimon.active_ability_slot = 2 if digimon.active_ability_slot == 1 else 1
				return true
			return false
		"switchSecretAbility":
			var data: DigimonData = Atlas.digimon.get(digimon.key) as DigimonData
			if data and data.ability_slot_3_key != &"":
				digimon.active_ability_slot = 3
				return true
			return false
		"addTv":
			var parsed: Dictionary = _parse_stat_value(value)
			if parsed.is_empty():
				return false
			var balance: GameBalance = load(
				"res://data/config/game_balance.tres"
			) as GameBalance
			var max_tv: int = balance.max_tv if balance else 500
			var max_total: int = balance.max_total_tvs if balance else 1000
			var stat_key: StringName = parsed.stat_key
			var current: int = digimon.tvs.get(stat_key, 0) as int
			var current_total: int = digimon.get_total_tvs()
			var headroom: int = maxi(max_total - current_total, 0)
			var new_val: int = mini(
				current + parsed.amount, mini(max_tv, current + headroom)
			)
			digimon.tvs[stat_key] = new_val
			return new_val != current
		"removeTv":
			var parsed: Dictionary = _parse_stat_value(value)
			if parsed.is_empty():
				return false
			var stat_key: StringName = parsed.stat_key
			var current: int = digimon.tvs.get(stat_key, 0) as int
			var new_val: int = maxi(current - parsed.amount, 0)
			digimon.tvs[stat_key] = new_val
			return new_val != current
		"addIv":
			var parsed: Dictionary = _parse_stat_value(value)
			if parsed.is_empty():
				return false
			var balance: GameBalance = load(
				"res://data/config/game_balance.tres"
			) as GameBalance
			var max_iv: int = balance.max_iv if balance else 50
			var stat_key: StringName = parsed.stat_key
			var current: int = digimon.ivs.get(stat_key, 0) as int
			var new_val: int = mini(current + parsed.amount, max_iv)
			digimon.ivs[stat_key] = new_val
			return new_val != current
		"removeIv":
			var parsed: Dictionary = _parse_stat_value(value)
			if parsed.is_empty():
				return false
			var stat_key: StringName = parsed.stat_key
			var current: int = digimon.ivs.get(stat_key, 0) as int
			var new_val: int = maxi(current - parsed.amount, 0)
			digimon.ivs[stat_key] = new_val
			return new_val != current
		"changePersonality":
			if value != "" and Atlas.personalities.has(StringName(value)):
				digimon.personality_override_key = StringName(value)
				return true
			return false
		"clearPersonality":
			if digimon.personality_override_key != &"":
				digimon.personality_override_key = &""
				return true
			return false
		"addTp":
			var tp: int = int(value) if value != "" else 0
			if tp > 0:
				var balance: GameBalance = load(
					"res://data/config/game_balance.tres"
				) as GameBalance
				var max_tp: int = balance.max_training_points if balance else 999
				var old_tp: int = digimon.training_points
				digimon.training_points = mini(
					digimon.training_points + tp, max_tp,
				)
				return digimon.training_points != old_tp
			return false
		"gain_xantibody":
			var amount: int = int(value) if value != "" else 1
			if amount > 0:
				digimon.x_antibody += amount
				return true
			return false
		"digimental", "spirit", "modeChange":
			# Tag effects — identify item type, no runtime action.
			return true
	return false


## Parses "abbrev:amount" into {"stat_key": StringName, "amount": int}.
## Returns empty Dictionary on failure.
static func _parse_stat_value(value: String) -> Dictionary:
	var parts: PackedStringArray = value.split(":")
	if parts.size() != 2:
		return {}
	var stat_key: StringName = _abbrev_to_stat_key(parts[0])
	if stat_key == &"":
		return {}
	var amount: int = int(parts[1])
	if amount <= 0:
		return {}
	return {"stat_key": stat_key, "amount": amount}


## Maps stat abbreviation to full stat key.
static func _abbrev_to_stat_key(abbrev: String) -> StringName:
	match abbrev:
		"hp": return &"hp"
		"atk": return &"attack"
		"def": return &"defence"
		"spa": return &"special_attack"
		"spd": return &"special_defence"
		"spe": return &"speed"
		"energy": return &"energy"
	return &""
