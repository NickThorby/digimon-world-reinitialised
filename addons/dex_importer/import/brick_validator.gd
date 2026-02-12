@tool
extends RefCounted
## Validates brick arrays against BRICK_CONTRACT.md schemas.
## Returns { valid: bool, errors: Array[String] }.

# Valid brick discriminator values.
const VALID_BRICK_TYPES: Array[String] = [
	"damage", "damageModifier", "recoil", "statModifier", "statProtection",
	"statusEffect", "statusInteraction", "healing", "fieldEffect", "sideEffect",
	"hazard", "positionControl", "turnEconomy", "chargeRequirement", "synergy",
	"requirement", "conditional", "protection", "priorityOverride", "elementModifier",
	"criticalHit", "resource", "useRandomTechnique", "transform",
	"shield", "copyTechnique", "abilityManipulation", "turnOrder",
	"outOfBattleEffect",
]

# Required fields per brick type (beyond the "brick" discriminator).
const REQUIRED_FIELDS: Dictionary = {
	"damage": ["type"],
	"recoil": ["type"],
	"statModifier": ["stats"],
	"statProtection": ["stats"],
	"statusEffect": ["status", "target"],
	"healing": ["type"],
	"fieldEffect": ["type"],
	"sideEffect": ["effect", "side"],
	"hazard": ["hazardType"],
	"positionControl": ["type"],
	"synergy": ["synergyType"],
	"requirement": ["failCondition"],
	"conditional": ["condition"],
	"protection": ["type"],
	"priorityOverride": ["condition", "newPriority"],
	"chargeRequirement": ["turnsToCharge"],
	"useRandomTechnique": ["source"],
	"shield": ["type"],
	"copyTechnique": ["source"],
	"abilityManipulation": ["type"],
	"turnOrder": ["type"],
	"elementModifier": ["type"],
	"outOfBattleEffect": ["effect"],
}

# Enum validation sets for specific fields.
const DAMAGE_TYPES: Array[String] = [
	"standard", "fixed", "percentage", "scaling", "level", "returnDamage", "counterScaling",
]

const RECOIL_TYPES: Array[String] = [
	"damagePercent", "hpPercent", "fixed", "crash",
]

const HEALING_TYPES: Array[String] = [
	"percentage", "fixed", "drain", "weather", "status",
]

const FIELD_EFFECT_TYPES: Array[String] = [
	"weather", "terrain", "global",
]

const SIDE_EFFECT_NAMES: Array[String] = [
	"physicalBarrier", "specialBarrier", "dualBarrier", "statDropImmunity",
	"statusImmunity", "speedBoost", "critImmunity", "spreadProtection",
	"priorityProtection", "firstTurnProtection",
]

const SIDE_VALUES: Array[String] = [
	"user", "target", "allFoes", "both",
]

const HAZARD_TYPE_VALUES: Array[String] = [
	"entryDamage", "entryStatReduction",
]

const POSITION_CONTROL_TYPES: Array[String] = [
	"forceSwitch", "switchOut", "switchOutPassStats", "swapPositions",
]

const SYNERGY_TYPES: Array[String] = [
	"combo", "followUp",
]

const PROTECTION_TYPES: Array[String] = [
	"all", "wide", "priority",
]

const SHIELD_TYPE_VALUES: Array[String] = [
	"hpDecoy", "intactFormGuard", "endure", "fullHpGuard", "lastStand", "negateOnePhysical",
]

const RANDOM_TECHNIQUE_SOURCES: Array[String] = [
	"allTechniques", "userKnown", "userKnownExceptThis", "targetKnown",
]

const COPY_TECHNIQUE_SOURCES: Array[String] = [
	"lastUsedByTarget", "lastUsedByAny", "lastUsedOnUser", "randomFromTarget",
]

const ABILITY_MANIPULATION_TYPES: Array[String] = [
	"copy", "swap", "suppress", "replace", "give", "nullify",
]

const TURN_ORDER_TYPES: Array[String] = [
	"makeTargetMoveNext", "makeTargetMoveLast", "repeatTargetMove",
]

const ELEMENT_MODIFIER_TYPES: Array[String] = [
	"addElement", "removeElement", "replaceElements",
	"changeTechniqueElement", "matchTargetWeakness",
	"changeUserResistanceProfile", "changeTargetResistanceProfile",
]

const OUT_OF_BATTLE_EFFECTS: Array[String] = [
	"toggleAbility", "switchSecretAbility",
	"addTv", "removeTv", "addIv", "removeIv",
	"changePersonality", "clearPersonality", "addTp",
]

const EFFECTS_REQUIRING_VALUE: Array[String] = [
	"addTv", "removeTv", "addIv", "removeIv",
	"changePersonality", "addTp",
]

const VALID_RESISTANCE_VALUES: Array[float] = [0.0, 0.5, 1.0, 1.5, 2.0]

const TECHNIQUE_CLASS_VALUES: Array[String] = [
	"Physical", "Special", "Status",
]

const BRICK_TARGET_VALUES: Array[String] = [
	"self", "target", "allFoes", "allAllies", "all", "attacker", "field",
]

const TECHNIQUE_FLAG_VALUES: Array[String] = [
	"contact", "sound", "punch", "kick", "bite", "blade", "beam", "explosive",
	"bullet", "powder", "wind", "flying", "groundable", "defrost",
	"reflectable", "snatchable",
]

const STAT_ABBREVIATIONS: Array[String] = [
	"hp", "atk", "def", "spa", "spd", "spe", "energy", "accuracy", "evasion",
]


## Validates an array of brick dictionaries. Returns { valid: bool, errors: Array[String] }.
func validate_bricks(bricks: Array) -> Dictionary:
	var errors: Array[String] = []

	for i: int in range(bricks.size()):
		var brick: Variant = bricks[i]
		if brick is not Dictionary:
			errors.append("Brick %d: expected Dictionary, got %s" % [i, typeof(brick)])
			continue
		_validate_single_brick(brick as Dictionary, i, errors)

	return {"valid": errors.is_empty(), "errors": errors}


func _validate_single_brick(brick: Dictionary, index: int, errors: Array[String]) -> void:
	# Check discriminator
	if not brick.has("brick"):
		errors.append("Brick %d: missing 'brick' discriminator" % index)
		return

	var brick_type: Variant = brick["brick"]
	if brick_type is not String:
		errors.append("Brick %d: 'brick' must be a string" % index)
		return

	var type_str: String = brick_type as String
	if type_str not in VALID_BRICK_TYPES:
		errors.append("Brick %d: unknown brick type '%s'" % [index, type_str])
		return

	# Check required fields
	if REQUIRED_FIELDS.has(type_str):
		var required: Array = REQUIRED_FIELDS[type_str]
		for field: Variant in required:
			var field_str: String = field as String
			if not brick.has(field_str):
				errors.append("Brick %d (%s): missing required field '%s'" % [
					index, type_str, field_str
				])

	# Type-specific validation
	match type_str:
		"damage":
			_validate_enum_field(brick, "type", DAMAGE_TYPES, index, type_str, errors)
		"recoil":
			_validate_enum_field(brick, "type", RECOIL_TYPES, index, type_str, errors)
		"statModifier":
			_validate_stats_field(brick, index, type_str, errors)
			_validate_optional_enum(brick, "target", BRICK_TARGET_VALUES, index, type_str, errors)
		"statProtection":
			_validate_stats_field(brick, index, type_str, errors)
			_validate_optional_enum(brick, "target", BRICK_TARGET_VALUES, index, type_str, errors)
		"statusEffect":
			_validate_optional_enum(brick, "target", BRICK_TARGET_VALUES, index, type_str, errors)
		"healing":
			_validate_enum_field(brick, "type", HEALING_TYPES, index, type_str, errors)
			_validate_optional_enum(brick, "target", BRICK_TARGET_VALUES, index, type_str, errors)
		"fieldEffect":
			_validate_enum_field(brick, "type", FIELD_EFFECT_TYPES, index, type_str, errors)
		"sideEffect":
			_validate_enum_field(brick, "effect", SIDE_EFFECT_NAMES, index, type_str, errors)
			_validate_enum_field(brick, "side", SIDE_VALUES, index, type_str, errors)
		"hazard":
			_validate_enum_field(
				brick, "hazardType", HAZARD_TYPE_VALUES, index, type_str, errors
			)
		"positionControl":
			_validate_enum_field(
				brick, "type", POSITION_CONTROL_TYPES, index, type_str, errors
			)
		"synergy":
			_validate_enum_field(brick, "synergyType", SYNERGY_TYPES, index, type_str, errors)
		"protection":
			_validate_enum_field(brick, "type", PROTECTION_TYPES, index, type_str, errors)
		"priorityOverride":
			_validate_int_field(brick, "newPriority", index, type_str, errors)
		"chargeRequirement":
			_validate_int_field(brick, "turnsToCharge", index, type_str, errors)
		"useRandomTechnique":
			_validate_enum_field(
				brick, "source", RANDOM_TECHNIQUE_SOURCES, index, type_str, errors
			)
		"shield":
			_validate_enum_field(brick, "type", SHIELD_TYPE_VALUES, index, type_str, errors)
		"copyTechnique":
			_validate_enum_field(
				brick, "source", COPY_TECHNIQUE_SOURCES, index, type_str, errors
			)
		"abilityManipulation":
			_validate_enum_field(
				brick, "type", ABILITY_MANIPULATION_TYPES, index, type_str, errors
			)
		"elementModifier":
			_validate_enum_field(
				brick, "type", ELEMENT_MODIFIER_TYPES, index, type_str, errors
			)
			_validate_optional_enum(
				brick, "target", BRICK_TARGET_VALUES, index, type_str, errors
			)
			if brick.has("value"):
				var val: Variant = brick["value"]
				if val is not float and val is not int:
					errors.append(
						"Brick %d (elementModifier): 'value' must be a number" % index
					)
				elif float(val) not in VALID_RESISTANCE_VALUES:
					errors.append(
						"Brick %d (elementModifier): 'value' must be 0.0, 0.5, 1.0, 1.5, or 2.0"
						% index
					)
		"turnOrder":
			_validate_enum_field(brick, "type", TURN_ORDER_TYPES, index, type_str, errors)
		"outOfBattleEffect":
			_validate_enum_field(
				brick, "effect", OUT_OF_BATTLE_EFFECTS, index, type_str, errors
			)
			var effect: String = str(brick.get("effect", ""))
			if effect in EFFECTS_REQUIRING_VALUE and not brick.has("value"):
				errors.append(
					"Brick %d (outOfBattleEffect): effect '%s' requires 'value'" % [
						index, effect
					]
				)
			if brick.has("value") and brick["value"] is not String:
				errors.append(
					"Brick %d (outOfBattleEffect): 'value' must be a string" % index
				)


func _validate_enum_field(
	brick: Dictionary,
	field: String,
	valid_values: Array,
	index: int,
	brick_type: String,
	errors: Array[String],
) -> void:
	if not brick.has(field):
		return
	var value: Variant = brick[field]
	if value is not String:
		errors.append("Brick %d (%s): '%s' must be a string" % [index, brick_type, field])
		return
	if (value as String) not in valid_values:
		errors.append("Brick %d (%s): '%s' has invalid value '%s'" % [
			index, brick_type, field, value
		])


func _validate_optional_enum(
	brick: Dictionary,
	field: String,
	valid_values: Array,
	index: int,
	brick_type: String,
	errors: Array[String],
) -> void:
	if brick.has(field):
		_validate_enum_field(brick, field, valid_values, index, brick_type, errors)


func _validate_stats_field(
	brick: Dictionary,
	index: int,
	brick_type: String,
	errors: Array[String],
) -> void:
	if not brick.has("stats"):
		return
	var stats: Variant = brick["stats"]
	if stats is String:
		if stats == "all":
			return
		if (stats as String) not in STAT_ABBREVIATIONS:
			errors.append("Brick %d (%s): invalid stat '%s'" % [index, brick_type, stats])
	elif stats is Array:
		for stat: Variant in (stats as Array):
			if stat is not String or (stat as String) not in STAT_ABBREVIATIONS:
				errors.append("Brick %d (%s): invalid stat '%s'" % [index, brick_type, str(stat)])


func _validate_int_field(
	brick: Dictionary,
	field: String,
	index: int,
	brick_type: String,
	errors: Array[String],
) -> void:
	if not brick.has(field):
		return
	var value: Variant = brick[field]
	if value is not int and value is not float:
		errors.append("Brick %d (%s): '%s' must be a number" % [index, brick_type, field])


