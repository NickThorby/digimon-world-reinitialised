extends GutTest
## Unit tests for DamageCalculator with fixed RNG seeds.

var _battle: BattleState


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func before_each() -> void:
	_battle = TestBattleFactory.create_1v1_battle()


# --- Core damage calculation ---


func test_physical_damage_returns_positive() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, _battle.rng,
	)
	assert_gt(result.raw_damage, 0, "Physical damage should be positive")
	assert_gt(result.final_damage, 0, "Final damage should be positive")


func test_special_damage_returns_positive() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(1, 0)  # gabumon (spa=100)
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var technique: TechniqueData = Atlas.techniques[&"test_ice_beam"]
	var result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, _battle.rng,
	)
	assert_gt(result.raw_damage, 0, "Special damage should be positive")


func test_status_technique_deals_zero_damage() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	var technique: TechniqueData = Atlas.techniques[&"test_status_burn"]
	var result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, _battle.rng,
	)
	assert_eq(result.raw_damage, 0, "Status technique should deal 0 damage")
	assert_eq(result.final_damage, 0, "Status technique final damage should be 0")


func test_minimum_damage_floor() -> void:
	# Even with extreme conditions, damage should be at least 1
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)
	# Debuff the user's attack massively
	user.base_stats[&"attack"] = 1
	# Boost target's defence
	target.base_stats[&"defence"] = 999
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, _battle.rng,
	)
	assert_gte(result.raw_damage, 1, "Minimum damage should be at least 1")


# --- Attribute triangle ---


func test_attribute_vaccine_vs_virus_advantage() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var mult: float = DamageCalculator.calculate_attribute_multiplier(
		Registry.Attribute.VACCINE, Registry.Attribute.VIRUS, balance,
	)
	assert_eq(mult, 1.5, "Vaccine vs Virus should be 1.5x advantage")


func test_attribute_virus_vs_data_advantage() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var mult: float = DamageCalculator.calculate_attribute_multiplier(
		Registry.Attribute.VIRUS, Registry.Attribute.DATA, balance,
	)
	assert_eq(mult, 1.5, "Virus vs Data should be 1.5x advantage")


func test_attribute_data_vs_vaccine_advantage() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var mult: float = DamageCalculator.calculate_attribute_multiplier(
		Registry.Attribute.DATA, Registry.Attribute.VACCINE, balance,
	)
	assert_eq(mult, 1.5, "Data vs Vaccine should be 1.5x advantage")


func test_attribute_virus_vs_vaccine_disadvantage() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var mult: float = DamageCalculator.calculate_attribute_multiplier(
		Registry.Attribute.VIRUS, Registry.Attribute.VACCINE, balance,
	)
	assert_eq(mult, 0.5, "Virus vs Vaccine should be 0.5x disadvantage")


func test_attribute_same_type_neutral() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var mult: float = DamageCalculator.calculate_attribute_multiplier(
		Registry.Attribute.VACCINE, Registry.Attribute.VACCINE, balance,
	)
	assert_eq(mult, 1.0, "Same attribute should be 1.0x neutral")


func test_attribute_free_is_neutral() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var mult: float = DamageCalculator.calculate_attribute_multiplier(
		Registry.Attribute.FREE, Registry.Attribute.VIRUS, balance,
	)
	assert_eq(mult, 1.0, "Free attribute should always be 1.0x neutral")


# --- Element multiplier ---


func test_element_super_effective() -> void:
	# test_agumon has ice resistance 1.5 (weak to ice)
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(&"ice", target)
	assert_eq(mult, 1.5, "Ice vs fire-type should be 1.5x (super effective)")


func test_element_resistant() -> void:
	# test_agumon has fire resistance 0.5 (resists fire)
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(&"fire", target)
	assert_eq(mult, 0.5, "Fire vs fire-type should be 0.5x (resistant)")


func test_element_immune() -> void:
	# test_patamon has dark resistance 0.0 (immune to dark)
	# Create a battle with patamon as target
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_patamon",
	)
	var target: BattleDigimonState = battle.get_digimon_at(1, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(&"dark", target)
	assert_eq(mult, 0.0, "Dark vs light-type should be 0.0x (immune)")


func test_element_neutral() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	# Earth is not in agumon's resistances, defaults to 1.0
	var mult: float = DamageCalculator.calculate_element_multiplier(&"earth", target)
	assert_eq(mult, 1.0, "Unlisted element should be 1.0x neutral")


func test_element_empty_key_is_neutral() -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var mult: float = DamageCalculator.calculate_element_multiplier(&"", target)
	assert_eq(mult, 1.0, "Empty element key should be 1.0x neutral")


# --- STAB ---


func test_stab_applied_when_matching() -> void:
	# test_agumon has element_traits [&"fire"], using fire technique
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var stab: float = DamageCalculator.calculate_stab(&"fire", user, balance)
	assert_eq(stab, 1.5, "Fire user using fire technique should get 1.5x STAB")


func test_stab_not_applied_when_not_matching() -> void:
	# test_agumon has element_traits [&"fire"], using ice technique
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var stab: float = DamageCalculator.calculate_stab(&"ice", user, balance)
	assert_eq(stab, 1.0, "Non-matching element should return 1.0x (no STAB)")


func test_stab_empty_element_returns_1() -> void:
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var stab: float = DamageCalculator.calculate_stab(&"", user, balance)
	assert_eq(stab, 1.0, "Empty element should return 1.0x")


# --- Critical hits ---


func test_crit_stage_3_always_crits() -> void:
	# Stage 3 = 100% crit rate
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var crits: int = 0
	for i: int in 10:
		if DamageCalculator.roll_critical(3, rng):
			crits += 1
	assert_eq(crits, 10, "Crit stage 3 should always crit (100% rate)")


func test_crit_stage_0_rarely_crits() -> void:
	# Stage 0 = 1/24 chance (~4.2%)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var crits: int = 0
	var trials: int = 1000
	for i: int in trials:
		if DamageCalculator.roll_critical(0, rng):
			crits += 1
	# 1/24 = ~4.2%, so in 1000 trials expect ~42, allow wide margin
	assert_lt(crits, 150, "Crit stage 0 should rarely crit")
	assert_gt(crits, 5, "Crit stage 0 should occasionally crit in 1000 trials")


# --- Overexertion ---


func test_overexertion_formula() -> void:
	# damage = overexerted_points * (1.0 + level / 25.0)
	# 10 * (1.0 + 50/25.0) = 10 * 3.0 = 30
	var damage: int = DamageCalculator.calculate_overexertion(10, 50)
	assert_eq(damage, 30, "Overexertion: 10 points at level 50 should deal 30")


func test_overexertion_minimum_1() -> void:
	var damage: int = DamageCalculator.calculate_overexertion(0, 1)
	assert_gte(damage, 1, "Overexertion should deal at least 1 damage")


func test_overexertion_scales_with_level() -> void:
	var damage_low: int = DamageCalculator.calculate_overexertion(10, 1)
	var damage_high: int = DamageCalculator.calculate_overexertion(10, 100)
	assert_gt(damage_high, damage_low, "Higher level should take more overexertion damage")


# --- Variance ---


func test_variance_within_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	for i: int in 100:
		var v: float = DamageCalculator.roll_variance(rng, balance)
		assert_gte(v, 0.85, "Variance should be >= 0.85")
		assert_lte(v, 1.0, "Variance should be <= 1.0")


# --- Effectiveness categories ---


func test_effectiveness_super_effective() -> void:
	# Vaccine vs Virus (1.5x attr) + neutral element (1.0x) = 1.5x total
	var user: BattleDigimonState = _battle.get_digimon_at(0, 0)  # Vaccine
	var target: BattleDigimonState = _battle.get_digimon_at(1, 0)  # Data
	# We need Vaccine vs Virus for super effective
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_agumon", &"test_tank",  # Vaccine vs Virus
	)
	var u: BattleDigimonState = battle.get_digimon_at(0, 0)
	var t: BattleDigimonState = battle.get_digimon_at(1, 0)
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: DamageResult = DamageCalculator.calculate_damage(
		u, t, technique, battle.rng,
	)
	assert_eq(
		result.effectiveness, &"super_effective",
		"Vaccine vs Virus should be super_effective",
	)


func test_effectiveness_not_very_effective() -> void:
	# Virus vs Vaccine = 0.5x
	var battle: BattleState = TestBattleFactory.create_1v1_battle(
		&"test_tank", &"test_agumon",  # Virus vs Vaccine
	)
	var u: BattleDigimonState = battle.get_digimon_at(0, 0)
	var t: BattleDigimonState = battle.get_digimon_at(1, 0)
	var technique: TechniqueData = Atlas.techniques[&"test_tackle"]
	var result: DamageResult = DamageCalculator.calculate_damage(
		u, t, technique, battle.rng,
	)
	assert_eq(
		result.effectiveness, &"not_very_effective",
		"Virus vs Vaccine should be not_very_effective",
	)
