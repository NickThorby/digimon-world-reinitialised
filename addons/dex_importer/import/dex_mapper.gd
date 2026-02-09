@tool
extends RefCounted
## Maps dex export JSON dictionaries to game Resource instances.
## Pure mapping — no I/O. All enum conversions happen here.

# --- Enum Mapping Dictionaries ---

const ATTRIBUTE_MAP: Dictionary = {
	"None": Registry.Attribute.NONE,
	"Vaccine": Registry.Attribute.VACCINE,
	"Virus": Registry.Attribute.VIRUS,
	"Data": Registry.Attribute.DATA,
	"Free": Registry.Attribute.FREE,
	"Variable": Registry.Attribute.VARIABLE,
	"Unknown": Registry.Attribute.UNKNOWN,
}

const TECHNIQUE_CLASS_MAP: Dictionary = {
	"Physical": Registry.TechniqueClass.PHYSICAL,
	"Special": Registry.TechniqueClass.SPECIAL,
	"Status": Registry.TechniqueClass.STATUS,
}

const TARGETING_MAP: Dictionary = {
	"Self": Registry.Targeting.SELF,
	"SingleTarget": Registry.Targeting.SINGLE_TARGET,
	"SingleOther": Registry.Targeting.SINGLE_OTHER,
	"SingleAlly": Registry.Targeting.SINGLE_ALLY,
	"SingleFoe": Registry.Targeting.SINGLE_FOE,
	"AllAllies": Registry.Targeting.ALL_ALLIES,
	"AllOtherAllies": Registry.Targeting.ALL_OTHER_ALLIES,
	"AllFoes": Registry.Targeting.ALL_FOES,
	"All": Registry.Targeting.ALL,
	"AllOther": Registry.Targeting.ALL_OTHER,
	"SingleSide": Registry.Targeting.SINGLE_SIDE,
	"Field": Registry.Targeting.FIELD,
}

const ABILITY_TRIGGER_MAP: Dictionary = {
	"onEntry": Registry.AbilityTrigger.ON_ENTRY,
	"onExit": Registry.AbilityTrigger.ON_EXIT,
	"onTurnStart": Registry.AbilityTrigger.ON_TURN_START,
	"onTurnEnd": Registry.AbilityTrigger.ON_TURN_END,
	"onBeforeTechnique": Registry.AbilityTrigger.ON_BEFORE_TECHNIQUE,
	"onAfterTechnique": Registry.AbilityTrigger.ON_AFTER_TECHNIQUE,
	"onBeforeHit": Registry.AbilityTrigger.ON_BEFORE_HIT,
	"onAfterHit": Registry.AbilityTrigger.ON_AFTER_HIT,
	"onDealDamage": Registry.AbilityTrigger.ON_DEAL_DAMAGE,
	"onTakeDamage": Registry.AbilityTrigger.ON_TAKE_DAMAGE,
	"onFaint": Registry.AbilityTrigger.ON_FAINT,
	"onAllyFaint": Registry.AbilityTrigger.ON_ALLY_FAINT,
	"onFoeFaint": Registry.AbilityTrigger.ON_FOE_FAINT,
	"onStatusApplied": Registry.AbilityTrigger.ON_STATUS_APPLIED,
	"onStatusInflicted": Registry.AbilityTrigger.ON_STATUS_INFLICTED,
	"onStatChange": Registry.AbilityTrigger.ON_STAT_CHANGE,
	"onWeatherChange": Registry.AbilityTrigger.ON_WEATHER_CHANGE,
	"onTerrainChange": Registry.AbilityTrigger.ON_TERRAIN_CHANGE,
	"onHpThreshold": Registry.AbilityTrigger.ON_HP_THRESHOLD,
	"continuous": Registry.AbilityTrigger.CONTINUOUS,
}

const STACK_LIMIT_MAP: Dictionary = {
	"unlimited": Registry.StackLimit.UNLIMITED,
	"oncePerTurn": Registry.StackLimit.ONCE_PER_TURN,
	"oncePerSwitch": Registry.StackLimit.ONCE_PER_SWITCH,
	"oncePerBattle": Registry.StackLimit.ONCE_PER_BATTLE,
	"firstOnly": Registry.StackLimit.FIRST_ONLY,
}

const EVOLUTION_TYPE_MAP: Dictionary = {
	"Standard": Registry.EvolutionType.STANDARD,
	"Spirit": Registry.EvolutionType.SPIRIT,
	"Armor": Registry.EvolutionType.ARMOR,
	"Slide": Registry.EvolutionType.SLIDE,
	"X-Antibody": Registry.EvolutionType.X_ANTIBODY,
	"Jogress": Registry.EvolutionType.JOGRESS,
	"Mode Change": Registry.EvolutionType.MODE_CHANGE,
}

const TECHNIQUE_FLAG_MAP: Dictionary = {
	"contact": Registry.TechniqueFlag.CONTACT,
	"sound": Registry.TechniqueFlag.SOUND,
	"punch": Registry.TechniqueFlag.PUNCH,
	"kick": Registry.TechniqueFlag.KICK,
	"bite": Registry.TechniqueFlag.BITE,
	"blade": Registry.TechniqueFlag.BLADE,
	"beam": Registry.TechniqueFlag.BEAM,
	"explosive": Registry.TechniqueFlag.EXPLOSIVE,
	"bullet": Registry.TechniqueFlag.BULLET,
	"powder": Registry.TechniqueFlag.POWDER,
	"wind": Registry.TechniqueFlag.WIND,
	"flying": Registry.TechniqueFlag.FLYING,
	"groundable": Registry.TechniqueFlag.GROUNDABLE,
	"defrost": Registry.TechniqueFlag.DEFROST,
	"reflectable": Registry.TechniqueFlag.REFLECTABLE,
	"snatchable": Registry.TechniqueFlag.SNATCHABLE,
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
		tech_class, Registry.TechniqueClass.PHYSICAL
	)

	var targeting_str: String = _str_or_empty(dex_data.get("targeting"))
	technique.targeting = TARGETING_MAP.get(targeting_str, Registry.Targeting.SINGLE_OTHER)

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

	# Priority: int -> Registry.Priority via DEX_PRIORITY_MAP
	var priority_int: int = int(dex_data.get("priority", 0))
	technique.priority = Registry.DEX_PRIORITY_MAP.get(
		priority_int, Registry.Priority.NORMAL
	)

	# Bricks — store validated bricks as-is
	var bricks: Array = dex_data.get("bricks", []) as Array
	technique.bricks = bricks

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
					var mapped_flags: Array[Registry.TechniqueFlag] = []
					for flag: Variant in (flag_values as Array):
						if flag is String and TECHNIQUE_FLAG_MAP.has(flag as String):
							mapped_flags.append(TECHNIQUE_FLAG_MAP[flag as String])
					technique.flags = mapped_flags
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
		trigger_str, Registry.AbilityTrigger.CONTINUOUS
	)

	# Stack limit
	var stack_str: String = _str_or_empty(dex_data.get("stack_limit"))
	ability.stack_limit = STACK_LIMIT_MAP.get(
		stack_str, Registry.StackLimit.UNLIMITED
	)

	# Trigger condition
	var condition: Variant = dex_data.get("trigger_condition")
	if condition != null and condition is Dictionary:
		ability.trigger_condition = condition as Dictionary
	else:
		ability.trigger_condition = {}

	# Bricks
	ability.bricks = dex_data.get("bricks", []) as Array

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
	digimon.type_tag = _str_or_empty(dex_data.get("type"))
	digimon.level = int(dex_data.get("level", 1))

	# Attribute
	var attr_str: String = _str_or_empty(dex_data.get("attribute"))
	digimon.attribute = ATTRIBUTE_MAP.get(attr_str, Registry.Attribute.NONE)

	# Base stats
	digimon.base_hp = int(dex_data.get("hp", 0))
	digimon.base_energy = int(dex_data.get("energy", 0))
	digimon.base_attack = int(dex_data.get("attack", 0))
	digimon.base_defence = int(dex_data.get("defence", 0))
	digimon.base_special_attack = int(dex_data.get("special_attack", 0))
	digimon.base_special_defence = int(dex_data.get("special_defence", 0))
	digimon.base_speed = int(dex_data.get("speed", 0))
	digimon.bst = int(dex_data.get("bst", 0))

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

	# Techniques — all referenced keys included regardless of validity
	var innate_keys: Array[StringName] = []
	var learnable_keys: Array[StringName] = []
	var techniques_arr: Variant = dex_data.get("techniques", [])
	if techniques_arr is Array:
		for tech_entry: Variant in (techniques_arr as Array):
			if tech_entry is not Dictionary:
				continue
			var entry: Dictionary = tech_entry as Dictionary
			var tech_key: StringName = StringName(entry.get("game_id", ""))
			if tech_key == &"":
				continue
			learnable_keys.append(tech_key)
			var requirements: Variant = entry.get("requirements", [])
			if requirements is Array:
				for req: Variant in (requirements as Array):
					if req is Dictionary and (req as Dictionary).get("type", "") == "innate":
						innate_keys.append(tech_key)
						break

	digimon.innate_technique_keys = innate_keys
	digimon.learnable_technique_keys = learnable_keys

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
		type_str, Registry.EvolutionType.STANDARD
	)

	# Requirements (AND logic, stored as-is)
	var requirements: Variant = dex_data.get("requirements")
	if requirements is Array:
		evolution.requirements = requirements as Array[Dictionary]
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

func _str_or_empty(value: Variant) -> String:
	if value == null:
		return ""
	if value is String:
		return value as String
	return str(value)
