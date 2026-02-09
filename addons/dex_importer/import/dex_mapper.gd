@tool
extends RefCounted
## Maps dex export JSON dictionaries to game Resource instances.
## Pure mapping — no I/O. All enum conversions happen here.

# Preload registry script directly to access enums without autoload dependency.
# This avoids compile-time issues when the plugin loads before autoloads are ready.
const _Reg = preload("res://autoload/registry.gd")

# --- Enum Mapping Dictionaries ---

const ATTRIBUTE_MAP: Dictionary = {
	"None": _Reg.Attribute.NONE,
	"Vaccine": _Reg.Attribute.VACCINE,
	"Virus": _Reg.Attribute.VIRUS,
	"Data": _Reg.Attribute.DATA,
	"Free": _Reg.Attribute.FREE,
	"Variable": _Reg.Attribute.VARIABLE,
	"Unknown": _Reg.Attribute.UNKNOWN,
}

const TECHNIQUE_CLASS_MAP: Dictionary = {
	"Physical": _Reg.TechniqueClass.PHYSICAL,
	"Special": _Reg.TechniqueClass.SPECIAL,
	"Status": _Reg.TechniqueClass.STATUS,
}

const TARGETING_MAP: Dictionary = {
	"Self": _Reg.Targeting.SELF,
	"SingleTarget": _Reg.Targeting.SINGLE_TARGET,
	"SingleOther": _Reg.Targeting.SINGLE_OTHER,
	"SingleAlly": _Reg.Targeting.SINGLE_ALLY,
	"SingleFoe": _Reg.Targeting.SINGLE_FOE,
	"AllAllies": _Reg.Targeting.ALL_ALLIES,
	"AllOtherAllies": _Reg.Targeting.ALL_OTHER_ALLIES,
	"AllFoes": _Reg.Targeting.ALL_FOES,
	"All": _Reg.Targeting.ALL,
	"AllOther": _Reg.Targeting.ALL_OTHER,
	"SingleSide": _Reg.Targeting.SINGLE_SIDE,
	"Field": _Reg.Targeting.FIELD,
}

const ABILITY_TRIGGER_MAP: Dictionary = {
	"onEntry": _Reg.AbilityTrigger.ON_ENTRY,
	"onExit": _Reg.AbilityTrigger.ON_EXIT,
	"onTurnStart": _Reg.AbilityTrigger.ON_TURN_START,
	"onTurnEnd": _Reg.AbilityTrigger.ON_TURN_END,
	"onBeforeTechnique": _Reg.AbilityTrigger.ON_BEFORE_TECHNIQUE,
	"onAfterTechnique": _Reg.AbilityTrigger.ON_AFTER_TECHNIQUE,
	"onBeforeHit": _Reg.AbilityTrigger.ON_BEFORE_HIT,
	"onAfterHit": _Reg.AbilityTrigger.ON_AFTER_HIT,
	"onDealDamage": _Reg.AbilityTrigger.ON_DEAL_DAMAGE,
	"onTakeDamage": _Reg.AbilityTrigger.ON_TAKE_DAMAGE,
	"onFaint": _Reg.AbilityTrigger.ON_FAINT,
	"onAllyFaint": _Reg.AbilityTrigger.ON_ALLY_FAINT,
	"onFoeFaint": _Reg.AbilityTrigger.ON_FOE_FAINT,
	"onStatusApplied": _Reg.AbilityTrigger.ON_STATUS_APPLIED,
	"onStatusInflicted": _Reg.AbilityTrigger.ON_STATUS_INFLICTED,
	"onStatChange": _Reg.AbilityTrigger.ON_STAT_CHANGE,
	"onWeatherChange": _Reg.AbilityTrigger.ON_WEATHER_CHANGE,
	"onTerrainChange": _Reg.AbilityTrigger.ON_TERRAIN_CHANGE,
	"onHpThreshold": _Reg.AbilityTrigger.ON_HP_THRESHOLD,
	"continuous": _Reg.AbilityTrigger.CONTINUOUS,
}

const STACK_LIMIT_MAP: Dictionary = {
	"unlimited": _Reg.StackLimit.UNLIMITED,
	"oncePerTurn": _Reg.StackLimit.ONCE_PER_TURN,
	"oncePerSwitch": _Reg.StackLimit.ONCE_PER_SWITCH,
	"oncePerBattle": _Reg.StackLimit.ONCE_PER_BATTLE,
	"firstOnly": _Reg.StackLimit.FIRST_ONLY,
}

const EVOLUTION_TYPE_MAP: Dictionary = {
	"Standard": _Reg.EvolutionType.STANDARD,
	"Spirit": _Reg.EvolutionType.SPIRIT,
	"Armor": _Reg.EvolutionType.ARMOR,
	"Slide": _Reg.EvolutionType.SLIDE,
	"X-Antibody": _Reg.EvolutionType.X_ANTIBODY,
	"Jogress": _Reg.EvolutionType.JOGRESS,
	"Mode Change": _Reg.EvolutionType.MODE_CHANGE,
}

const TECHNIQUE_FLAG_MAP: Dictionary = {
	"contact": _Reg.TechniqueFlag.CONTACT,
	"sound": _Reg.TechniqueFlag.SOUND,
	"punch": _Reg.TechniqueFlag.PUNCH,
	"kick": _Reg.TechniqueFlag.KICK,
	"bite": _Reg.TechniqueFlag.BITE,
	"blade": _Reg.TechniqueFlag.BLADE,
	"beam": _Reg.TechniqueFlag.BEAM,
	"explosive": _Reg.TechniqueFlag.EXPLOSIVE,
	"bullet": _Reg.TechniqueFlag.BULLET,
	"powder": _Reg.TechniqueFlag.POWDER,
	"wind": _Reg.TechniqueFlag.WIND,
	"flying": _Reg.TechniqueFlag.FLYING,
	"groundable": _Reg.TechniqueFlag.GROUNDABLE,
	"defrost": _Reg.TechniqueFlag.DEFROST,
	"reflectable": _Reg.TechniqueFlag.REFLECTABLE,
	"snatchable": _Reg.TechniqueFlag.SNATCHABLE,
}

const GROWTH_RATE_MAP: Dictionary = {
	"Erratic": _Reg.GrowthRate.ERRATIC,
	"Fast": _Reg.GrowthRate.FAST,
	"MediumFast": _Reg.GrowthRate.MEDIUM_FAST,
	"Medium Fast": _Reg.GrowthRate.MEDIUM_FAST,
	"MediumSlow": _Reg.GrowthRate.MEDIUM_SLOW,
	"Medium Slow": _Reg.GrowthRate.MEDIUM_SLOW,
	"Slow": _Reg.GrowthRate.SLOW,
	"Fluctuating": _Reg.GrowthRate.FLUCTUATING,
}

const ELEMENT_NAME_MAP: Dictionary = {
	"Null": &"null",
	"Fire": &"fire",
	"Water": &"water",
	"Air": &"air",
	"Earth": &"earth",
	"Ice": &"ice",
	"Lightning": &"lightning",
	"Plant": &"plant",
	"Metal": &"metal",
	"Dark": &"dark",
	"Light": &"light",
}


# --- Technique Mapping ---

## Maps a dex technique dictionary to a TechniqueData resource. Returns null on failure.
func map_technique(dex_data: Dictionary, _validator: RefCounted) -> Resource:
	var technique: TechniqueData = TechniqueData.new()

	technique.key = StringName(dex_data.get("game_id", ""))
	technique.jp_name = _str_or_empty(dex_data.get("jp_name"))
	technique.dub_name = _str_or_empty(dex_data.get("dub_name"))
	technique.custom_name = _str_or_empty(dex_data.get("name"))
	technique.description = _str_or_empty(dex_data.get("description"))
	technique.mechanic_description = _str_or_empty(dex_data.get("mechanic_description"))

	# Enum mappings
	var tech_class: String = _str_or_empty(dex_data.get("class"))
	technique.technique_class = TECHNIQUE_CLASS_MAP.get(
		tech_class, _Reg.TechniqueClass.PHYSICAL
	)

	var targeting_str: String = _str_or_empty(dex_data.get("targeting"))
	technique.targeting = TARGETING_MAP.get(targeting_str, _Reg.Targeting.SINGLE_OTHER)

	# Element
	var element: Variant = dex_data.get("element")
	if element != null and element is String:
		technique.element_key = ELEMENT_NAME_MAP.get(element as String, &"")
	else:
		technique.element_key = &""

	# Accuracy: null = always hits -> 0
	var accuracy: Variant = dex_data.get("accuracy")
	if accuracy == null:
		technique.accuracy = 0
	else:
		technique.accuracy = int(accuracy)

	technique.energy_cost = int(dex_data.get("energy_cost", 10))

	# Priority: int -> _Reg.Priority via DEX_PRIORITY_MAP
	var priority_int: int = int(dex_data.get("priority", 0))
	technique.priority = _Reg.DEX_PRIORITY_MAP.get(
		priority_int, _Reg.Priority.NORMAL
	)

	# Bricks — store validated bricks as-is
	var bricks: Array = dex_data.get("bricks", []) as Array
	var typed_bricks: Array[Dictionary] = []
	for b: Variant in bricks:
		if b is Dictionary:
			typed_bricks.append(b as Dictionary)
	technique.bricks = typed_bricks

	# Extract derived fields from bricks
	_extract_technique_fields(technique, bricks)

	return technique


## Extracts top-level fields from bricks into TechniqueData.
func _extract_technique_fields(technique: TechniqueData, bricks: Array) -> void:
	for brick: Variant in bricks:
		if brick is not Dictionary:
			continue
		var b: Dictionary = brick as Dictionary
		var brick_type: String = b.get("brick", "") as String

		match brick_type:
			"damage":
				if b.get("type", "") == "standard" and b.has("power"):
					technique.power = int(b["power"])
			"flags":
				var flag_values: Variant = b.get("flags", [])
				if flag_values is Array:
					var mapped_flags: Array = []
					for flag: Variant in (flag_values as Array):
						if flag is String and TECHNIQUE_FLAG_MAP.has(flag as String):
							mapped_flags.append(TECHNIQUE_FLAG_MAP[flag as String])
					technique.flags.assign(mapped_flags)
			"chargeRequirement":
				if b.has("turnsToCharge"):
					technique.charge_required = int(b["turnsToCharge"])
				var conditions: Array[Dictionary] = []
				if b.has("skipInWeather"):
					conditions.append({
						"type": "skip_in_weather",
						"weather": b["skipInWeather"],
					})
				if b.has("skipInTerrain"):
					conditions.append({
						"type": "skip_in_terrain",
						"terrain": b["skipInTerrain"],
					})
				if b.has("semiInvulnerable"):
					conditions.append({
						"type": "semi_invulnerable",
						"state": b["semiInvulnerable"],
					})
				if not conditions.is_empty():
					technique.charge_conditions = conditions


# --- Ability Mapping ---

## Maps a dex ability dictionary to an AbilityData resource. Returns null on failure.
func map_ability(dex_data: Dictionary, _validator: RefCounted) -> Resource:
	var ability: AbilityData = AbilityData.new()

	ability.key = StringName(dex_data.get("game_id", ""))
	ability.name = _str_or_empty(dex_data.get("name"))
	ability.description = _str_or_empty(dex_data.get("description"))
	ability.mechanic_description = _str_or_empty(dex_data.get("mechanic_description"))

	# Trigger
	var trigger_str: String = _str_or_empty(dex_data.get("trigger"))
	ability.trigger = ABILITY_TRIGGER_MAP.get(
		trigger_str, _Reg.AbilityTrigger.CONTINUOUS
	)

	# Stack limit
	var stack_str: String = _str_or_empty(dex_data.get("stack_limit"))
	ability.stack_limit = STACK_LIMIT_MAP.get(
		stack_str, _Reg.StackLimit.UNLIMITED
	)

	# Trigger condition (condition string format: "condType:value|cond2")
	var condition: Variant = dex_data.get("trigger_condition")
	if condition is String:
		ability.trigger_condition = condition
	elif condition is Dictionary and not (condition as Dictionary).is_empty():
		# Legacy dict format: convert {type: "below", hp_percent: 50} -> "userHpBelow:50"
		ability.trigger_condition = _convert_legacy_trigger_condition(
			condition as Dictionary,
		)
	else:
		ability.trigger_condition = ""

	# Bricks
	var raw_bricks: Array = dex_data.get("bricks", []) as Array
	var typed_bricks: Array[Dictionary] = []
	for b: Variant in raw_bricks:
		if b is Dictionary:
			typed_bricks.append(b as Dictionary)
	ability.bricks = typed_bricks

	return ability


# --- Digimon Mapping ---

## Maps a dex Digimon dictionary to a DigimonData resource. Returns null on failure.
func map_digimon(
	dex_data: Dictionary,
	valid_technique_keys: Dictionary,
	valid_ability_keys: Dictionary,
) -> Resource:
	var digimon: DigimonData = DigimonData.new()

	digimon.key = StringName(dex_data.get("game_id", ""))
	digimon.jp_name = _str_or_empty(dex_data.get("jp_name"))
	digimon.dub_name = _str_or_empty(dex_data.get("dub_name"))
	digimon.custom_name = _str_or_empty(dex_data.get("name"))
	digimon.level = int(dex_data.get("level", 1))

	# Attribute
	var attr_str: String = _str_or_empty(dex_data.get("attribute"))
	digimon.attribute = ATTRIBUTE_MAP.get(attr_str, _Reg.Attribute.NONE)

	# Base stats
	digimon.base_hp = int(dex_data.get("hp", 0))
	digimon.base_energy = int(dex_data.get("energy", 0))
	digimon.base_attack = int(dex_data.get("attack", 0))
	digimon.base_defence = int(dex_data.get("defence", 0))
	digimon.base_special_attack = int(dex_data.get("special_attack", 0))
	digimon.base_special_defence = int(dex_data.get("special_defence", 0))
	digimon.base_speed = int(dex_data.get("speed", 0))
	digimon.bst = int(dex_data.get("bst", 0))

	# Growth rate
	var growth_rate_str: String = _str_or_empty(dex_data.get("growth_rate"))
	digimon.growth_rate = GROWTH_RATE_MAP.get(
		growth_rate_str, _Reg.GrowthRate.MEDIUM_FAST
	)

	# Base XP yield
	digimon.base_xp_yield = int(dex_data.get("base_xp_yield", 50))

	# Resistances: element name -> lowercase StringName key
	var raw_resistances: Variant = dex_data.get("resistances", {})
	if raw_resistances is Dictionary:
		var mapped_resistances: Dictionary = {}
		for element_name: Variant in (raw_resistances as Dictionary).keys():
			var element_key: StringName = ELEMENT_NAME_MAP.get(
				element_name as String, &""
			)
			if element_key != &"":
				mapped_resistances[element_key] = float(
					(raw_resistances as Dictionary)[element_name]
				)
		digimon.resistances = mapped_resistances

	# Techniques — preserve all requirement types
	var technique_entries: Array[Dictionary] = []
	var techniques_arr: Variant = dex_data.get("techniques", [])
	if techniques_arr is Array:
		for tech_entry: Variant in (techniques_arr as Array):
			if tech_entry is not Dictionary:
				continue
			var entry: Dictionary = tech_entry as Dictionary
			var tech_key: StringName = StringName(entry.get("game_id", ""))
			if tech_key == &"":
				continue
			var raw_reqs: Variant = entry.get("requirements", [])
			var typed_reqs: Array[Dictionary] = []
			if raw_reqs is Array:
				for req: Variant in (raw_reqs as Array):
					if req is Dictionary:
						typed_reqs.append(req as Dictionary)
			technique_entries.append({
				"key": tech_key,
				"requirements": typed_reqs,
			})

	digimon.technique_entries = technique_entries

	# Abilities
	var abilities_arr: Variant = dex_data.get("abilities", [])
	if abilities_arr is Array:
		for ability_entry: Variant in (abilities_arr as Array):
			if ability_entry is not Dictionary:
				continue
			var entry: Dictionary = ability_entry as Dictionary
			var ability_key: StringName = StringName(entry.get("game_id", ""))
			var slot: int = int(entry.get("slot", 0))
			match slot:
				1:
					digimon.ability_slot_1_key = ability_key
				2:
					digimon.ability_slot_2_key = ability_key
				3:
					digimon.ability_slot_3_key = ability_key

	# Traits
	var traits_arr: Variant = dex_data.get("traits", [])
	if traits_arr is Array:
		for trait_entry: Variant in (traits_arr as Array):
			if trait_entry is not Dictionary:
				continue
			var entry: Dictionary = trait_entry as Dictionary
			var trait_name: String = _str_or_empty(entry.get("name"))
			var trait_category: String = _str_or_empty(entry.get("category"))
			if trait_name.is_empty() or trait_category.is_empty():
				continue
			var trait_key: StringName = _trait_to_key(trait_name)
			match trait_category:
				"Size":
					digimon.size_trait = trait_key
				"Movement":
					digimon.movement_traits.append(trait_key)
				"Type":
					digimon.type_trait = trait_key
				"Element":
					digimon.element_traits.append(trait_key)

	return digimon


# --- Evolution Mapping ---

## Maps a dex evolution dictionary to an EvolutionLinkData resource. Returns null on failure.
func map_evolution(dex_data: Dictionary) -> Resource:
	var evolution: EvolutionLinkData = EvolutionLinkData.new()

	var from_key: String = dex_data.get("from_game_id", "")
	var to_key: String = dex_data.get("to_game_id", "")
	evolution.key = StringName("%s_to_%s" % [from_key, to_key])
	evolution.from_key = StringName(from_key)
	evolution.to_key = StringName(to_key)

	# Evolution type
	var type_str: String = _str_or_empty(dex_data.get("evolution_type"))
	evolution.evolution_type = EVOLUTION_TYPE_MAP.get(
		type_str, _Reg.EvolutionType.STANDARD
	)

	# Requirements (AND logic, stored as-is)
	var requirements: Variant = dex_data.get("requirements")
	if requirements is Array:
		var typed_reqs: Array[Dictionary] = []
		for req: Variant in (requirements as Array):
			if req is Dictionary:
				typed_reqs.append(req as Dictionary)
		evolution.requirements = typed_reqs
	else:
		evolution.requirements = []

	# Jogress partners
	var partners: Variant = dex_data.get("jogress_partners", [])
	if partners is Array:
		var partner_keys: Array[StringName] = []
		for partner: Variant in (partners as Array):
			if partner is String:
				partner_keys.append(StringName(partner as String))
		evolution.jogress_partner_keys = partner_keys
	else:
		evolution.jogress_partner_keys = []

	return evolution


# --- Utilities ---

func _trait_to_key(trait_name: String) -> StringName:
	return StringName(trait_name.replace(" ", "_").to_lower())


func _str_or_empty(value: Variant) -> String:
	if value == null:
		return ""
	if value is String:
		return value as String
	return str(value)


## Converts legacy Dictionary trigger_condition to condition string format.
## Input:  {"type": "below", "hpPercent": 33}  or  {"type": "above", "hpPercent": 50}
## Output: "userHpBelow:33"  or  "userHpAbove:50"
static func _convert_legacy_trigger_condition(cond: Dictionary) -> String:
	var cond_type: String = str(cond.get("type", ""))
	var hp_percent: Variant = cond.get("hpPercent", cond.get("hp_percent", null))

	if hp_percent != null:
		match cond_type:
			"below":
				return "userHpBelow:%d" % int(hp_percent)
			"above":
				return "userHpAbove:%d" % int(hp_percent)

	push_warning("DexMapper: Unknown legacy trigger_condition format: %s" % str(cond))
	return ""
