class_name StatCalculator
extends RefCounted
## Pure stat calculation functions.


## Core stat formula: FLOOR((((2 * BASE + IV + (TV / 5)) * LEVEL) / 100)) + LEVEL + 10
static func calculate_stat(base: int, iv: int, tv: int, level: int) -> int:
	return floori((((2 * base + iv + (tv / 5)) * level) / 100.0)) + level + 10


## Calculate all seven stats for a Digimon.
static func calculate_all_stats(data: DigimonData, state: DigimonState) -> Dictionary:
	return {
		&"hp": calculate_stat(data.base_hp, state.ivs.get(&"hp", 0), state.tvs.get(&"hp", 0), state.level),
		&"energy": calculate_stat(data.base_energy, state.ivs.get(&"energy", 0), state.tvs.get(&"energy", 0), state.level),
		&"attack": calculate_stat(data.base_attack, state.ivs.get(&"attack", 0), state.tvs.get(&"attack", 0), state.level),
		&"defence": calculate_stat(data.base_defence, state.ivs.get(&"defence", 0), state.tvs.get(&"defence", 0), state.level),
		&"special_attack": calculate_stat(data.base_special_attack, state.ivs.get(&"special_attack", 0), state.tvs.get(&"special_attack", 0), state.level),
		&"special_defence": calculate_stat(data.base_special_defence, state.ivs.get(&"special_defence", 0), state.tvs.get(&"special_defence", 0), state.level),
		&"speed": calculate_stat(data.base_speed, state.ivs.get(&"speed", 0), state.tvs.get(&"speed", 0), state.level),
	}


## Apply personality modifier to a stat value.
## Returns the modified value (floored).
static func apply_personality(
	stat_value: int,
	stat_key: StringName,
	personality: PersonalityData
) -> int:
	if personality == null:
		return stat_value

	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var modifier: float = balance.personality_modifier if balance else 0.1

	var multiplier: float = 1.0
	if personality.boosted_stat == _stat_key_to_enum(stat_key):
		multiplier += modifier
	if personality.reduced_stat == _stat_key_to_enum(stat_key):
		multiplier -= modifier

	return floori(stat_value * multiplier)


## Apply a stat stage modifier (-6 to +6) to a stat value.
static func apply_stat_stage(stat_value: int, stage: int) -> int:
	var clamped_stage: int = clampi(stage, -6, 6)
	var multiplier: float = Registry.STAT_STAGE_MULTIPLIERS.get(clamped_stage, 1.0)
	return floori(stat_value * multiplier)


## Calculate effective speed considering priority tier multiplier.
static func calculate_effective_speed(base_speed: int, priority: Registry.Priority) -> float:
	var multiplier: float = Registry.PRIORITY_SPEED_MULTIPLIERS.get(priority, 1.0)
	return base_speed * multiplier


## Convert a stat key string to the Registry.Stat enum.
static func _stat_key_to_enum(stat_key: StringName) -> Registry.Stat:
	match stat_key:
		&"hp": return Registry.Stat.HP
		&"energy": return Registry.Stat.ENERGY
		&"attack": return Registry.Stat.ATTACK
		&"defence": return Registry.Stat.DEFENCE
		&"special_attack": return Registry.Stat.SPECIAL_ATTACK
		&"special_defence": return Registry.Stat.SPECIAL_DEFENCE
		&"speed": return Registry.Stat.SPEED
		_: return Registry.Stat.HP
