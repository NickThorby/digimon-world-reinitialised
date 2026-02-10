class_name DamageCalculator
extends RefCounted
## Calculates damage for technique execution.
## Formula: ROUND((7 + level/200 * power * ATK/DEF) * modifier)


static var _balance: GameBalance = null


static func _get_balance() -> GameBalance:
	if _balance == null:
		_balance = load("res://data/config/game_balance.tres") as GameBalance
	return _balance


## Calculate damage for a technique hit.
static func calculate_damage(
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle_or_rng: Variant = null,
	crit_bonus: int = 0,
) -> DamageResult:
	var result := DamageResult.new()
	var balance: GameBalance = _get_balance()

	# Support both BattleState and bare RandomNumberGenerator for backwards
	# compatibility. Existing callers that pass an RNG directly still work.
	var rng: RandomNumberGenerator
	var battle: BattleState = null
	if battle_or_rng is BattleState:
		battle = battle_or_rng as BattleState
		rng = battle.rng
	elif battle_or_rng is RandomNumberGenerator:
		rng = battle_or_rng as RandomNumberGenerator
	else:
		rng = RandomNumberGenerator.new()

	# Status techniques deal no damage
	if technique.technique_class == Registry.TechniqueClass.STATUS:
		return result

	var level: float = float(user.source_state.level)
	var power: float = float(technique.power)

	if power <= 0:
		return result

	# Determine ATK/DEF stats based on technique class
	var atk: float
	var def: float
	if technique.technique_class == Registry.TechniqueClass.PHYSICAL:
		atk = float(user.get_effective_stat(&"attack"))
		def = float(target.get_effective_stat(&"defence"))
	else:
		atk = float(user.get_effective_stat(&"special_attack"))
		def = float(target.get_effective_stat(&"special_defence"))

	# Defence swap: global effect swaps which defence stat is used
	if battle != null \
			and battle.field.has_global_effect(&"defence_swap"):
		if technique.technique_class == Registry.TechniqueClass.PHYSICAL:
			def = float(target.get_effective_stat(&"special_defence"))
		else:
			def = float(target.get_effective_stat(&"defence"))

	# Prevent division by zero
	if def <= 0.0:
		def = 1.0

	# Attribute multiplier
	var attr_mult: float = calculate_attribute_multiplier(
		user.data.attribute if user.data else Registry.Attribute.NONE,
		target.data.attribute if target.data else Registry.Attribute.NONE,
		balance,
	)
	result.attribute_multiplier = attr_mult

	# Element multiplier (target's resistance to technique element)
	var elem_mult: float = calculate_element_multiplier(technique.element_key, target)
	result.element_multiplier = elem_mult

	# STAB
	var stab: float = calculate_stab(technique.element_key, user, balance)
	result.stab_applied = stab > 1.0

	# Critical hit
	var crit: float = 1.0
	if roll_critical(crit_bonus, rng):
		crit = balance.crit_damage_multiplier if balance else 1.5
		result.was_critical = true

	# Variance
	var variance_val: float = roll_variance(rng, balance)
	result.variance = variance_val

	# Final modifier
	var modifier: float = attr_mult * elem_mult * stab * crit * variance_val

	# Core formula: (7 + level/200 * power * ATK/DEF) * modifier
	var base_damage: float = 7.0 + (level / 200.0) * power * (atk / def)
	var raw: float = base_damage * modifier
	result.raw_damage = maxi(roundi(raw), 1)
	result.final_damage = result.raw_damage

	# Determine effectiveness (immune must be checked first)
	var total_type_mult: float = attr_mult * elem_mult
	if total_type_mult <= 0.0:
		result.effectiveness = &"immune"
	elif total_type_mult >= 1.5:
		result.effectiveness = &"super_effective"
	elif total_type_mult < 0.75:
		result.effectiveness = &"not_very_effective"
	else:
		result.effectiveness = &"neutral"

	return result


## Calculate overexertion self-damage.
static func calculate_overexertion(overexerted_points: int, level: int) -> int:
	var damage: float = float(overexerted_points) * (1.0 + float(level) / 25.0)
	return maxi(roundi(damage), 1)


## Calculate attribute triangle multiplier.
static func calculate_attribute_multiplier(
	attacker_attr: Registry.Attribute,
	defender_attr: Registry.Attribute,
	balance: GameBalance,
) -> float:
	# Non-combat attributes are neutral
	if attacker_attr not in [Registry.Attribute.VACCINE, Registry.Attribute.VIRUS, Registry.Attribute.DATA]:
		return 1.0
	if defender_attr not in [Registry.Attribute.VACCINE, Registry.Attribute.VIRUS, Registry.Attribute.DATA]:
		return 1.0

	# Advantage: Vaccine > Virus > Data > Vaccine
	var advantage_mult: float = balance.attribute_advantage_multiplier if balance else 1.5
	var disadvantage_mult: float = balance.attribute_disadvantage_multiplier if balance else 0.5

	if attacker_attr == Registry.Attribute.VACCINE and defender_attr == Registry.Attribute.VIRUS:
		return advantage_mult
	if attacker_attr == Registry.Attribute.VIRUS and defender_attr == Registry.Attribute.DATA:
		return advantage_mult
	if attacker_attr == Registry.Attribute.DATA and defender_attr == Registry.Attribute.VACCINE:
		return advantage_mult

	# Disadvantage (reverse)
	if attacker_attr == Registry.Attribute.VIRUS and defender_attr == Registry.Attribute.VACCINE:
		return disadvantage_mult
	if attacker_attr == Registry.Attribute.DATA and defender_attr == Registry.Attribute.VIRUS:
		return disadvantage_mult
	if attacker_attr == Registry.Attribute.VACCINE and defender_attr == Registry.Attribute.DATA:
		return disadvantage_mult

	return 1.0


## Calculate element multiplier from target's resistances.
static func calculate_element_multiplier(
	element_key: StringName,
	target: BattleDigimonState,
) -> float:
	if element_key == &"" or target.data == null:
		return 1.0
	return float(target.data.resistances.get(element_key, 1.0))


## Calculate STAB bonus.
static func calculate_stab(
	element_key: StringName,
	user: BattleDigimonState,
	balance: GameBalance,
) -> float:
	if element_key == &"" or user.data == null:
		return 1.0
	if element_key in user.data.element_traits:
		return balance.element_stab_multiplier if balance else 1.5
	return 1.0


## Roll for critical hit. Returns true if critical.
static func roll_critical(crit_stage: int, rng: RandomNumberGenerator) -> bool:
	var clamped: int = clampi(crit_stage, 0, 3)
	var rate: float = Registry.CRIT_STAGE_RATES.get(clamped, 1.0 / 24.0)
	return rng.randf() < rate


## Roll damage variance (0.85-1.0 by default).
static func roll_variance(rng: RandomNumberGenerator, balance: GameBalance) -> float:
	var min_var: float = balance.damage_variance_min if balance else 0.85
	var max_var: float = balance.damage_variance_max if balance else 1.0
	return rng.randf_range(min_var, max_var)
