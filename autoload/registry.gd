extends Node
## Central enum registry and game constants.

# --- Core ---

enum Attribute {
	NONE,
	VACCINE,
	VIRUS,
	DATA,
	FREE,
	VARIABLE,
	UNKNOWN,
}

var attribute_labels: Dictionary = {
	Attribute.NONE: tr("attribute.none"),
	Attribute.VACCINE: tr("attribute.vaccine"),
	Attribute.VIRUS: tr("attribute.virus"),
	Attribute.DATA: tr("attribute.data"),
	Attribute.FREE: tr("attribute.free"),
	Attribute.VARIABLE: tr("attribute.variable"),
	Attribute.UNKNOWN: tr("attribute.unknown"),
}

enum Element {
	NULL_ELEMENT,
	FIRE,
	WATER,
	AIR,
	EARTH,
	ICE,
	LIGHTNING,
	PLANT,
	METAL,
	DARK,
	LIGHT,
}

var element_labels: Dictionary = {
	Element.NULL_ELEMENT: tr("element.null"),
	Element.FIRE: tr("element.fire"),
	Element.WATER: tr("element.water"),
	Element.AIR: tr("element.air"),
	Element.EARTH: tr("element.earth"),
	Element.ICE: tr("element.ice"),
	Element.LIGHTNING: tr("element.lightning"),
	Element.PLANT: tr("element.plant"),
	Element.METAL: tr("element.metal"),
	Element.DARK: tr("element.dark"),
	Element.LIGHT: tr("element.light"),
}

enum Stat {
	HP,
	ENERGY,
	ATTACK,
	DEFENCE,
	SPECIAL_ATTACK,
	SPECIAL_DEFENCE,
	SPEED,
}

var stat_labels: Dictionary = {
	Stat.HP: tr("stat.hp"),
	Stat.ENERGY: tr("stat.energy"),
	Stat.ATTACK: tr("stat.attack"),
	Stat.DEFENCE: tr("stat.defence"),
	Stat.SPECIAL_ATTACK: tr("stat.special_attack"),
	Stat.SPECIAL_DEFENCE: tr("stat.special_defence"),
	Stat.SPEED: tr("stat.speed"),
}

enum EvolutionLevel {
	BABY_I = 1,
	BABY_II = 2,
	CHILD = 3,
	ADULT = 4,
	PERFECT = 5,
	ULTIMATE = 6,
	SUPER_ULTIMATE = 7,
	ARMOR = 8,
	HYBRID = 9,
	UNKNOWN = 10,
}

var _evolution_level_jp_labels: Dictionary = {
	EvolutionLevel.BABY_I: tr("Baby I"),
	EvolutionLevel.BABY_II: tr("Baby II"),
	EvolutionLevel.CHILD: tr("Child"),
	EvolutionLevel.ADULT: tr("Adult"),
	EvolutionLevel.PERFECT: tr("Perfect"),
	EvolutionLevel.ULTIMATE: tr("Ultimate"),
	EvolutionLevel.SUPER_ULTIMATE: tr("Super Ultimate"),
	EvolutionLevel.ARMOR: tr("Armor"),
	EvolutionLevel.HYBRID: tr("Hybrid"),
	EvolutionLevel.UNKNOWN: tr("Unknown"),
}

var _evolution_level_dub_labels: Dictionary = {
	EvolutionLevel.BABY_I: tr("Fresh"),
	EvolutionLevel.BABY_II: tr("In-Training"),
	EvolutionLevel.CHILD: tr("Rookie"),
	EvolutionLevel.ADULT: tr("Champion"),
	EvolutionLevel.PERFECT: tr("Ultimate"),
	EvolutionLevel.ULTIMATE: tr("Mega"),
	EvolutionLevel.SUPER_ULTIMATE: tr("Ultra"),
	EvolutionLevel.ARMOR: tr("Armor"),
	EvolutionLevel.HYBRID: tr("Hybrid"),
	EvolutionLevel.UNKNOWN: tr("Unknown"),
}

## Returns the label for a single evolution level based on display preference.
func get_evolution_level_label(level: EvolutionLevel) -> String:
	if Settings.display_preference == Settings.DisplayPreference.JAPANESE:
		return _evolution_level_jp_labels.get(level, "Unknown")
	return _evolution_level_dub_labels.get(level, "Unknown")

## Returns the full evolution level labels dictionary based on display preference.
var evolution_level_labels: Dictionary:
	get:
		if Settings.display_preference == Settings.DisplayPreference.JAPANESE:
			return _evolution_level_jp_labels
		return _evolution_level_dub_labels

# --- Techniques ---

enum TechniqueClass {
	PHYSICAL,
	SPECIAL,
	STATUS,
}

var technique_class_labels: Dictionary = {
	TechniqueClass.PHYSICAL: tr("technique_class.physical"),
	TechniqueClass.SPECIAL: tr("technique_class.special"),
	TechniqueClass.STATUS: tr("technique_class.status"),
}

enum Targeting {
	SELF,
	SINGLE_TARGET,
	SINGLE_OTHER,
	SINGLE_SIDE,
	SINGLE_SIDE_OR_ALLY,
	ALL,
	ALL_OTHER,
}

var targeting_labels: Dictionary = {
	Targeting.SELF: tr("targeting.self"),
	Targeting.SINGLE_TARGET: tr("targeting.single_target"),
	Targeting.SINGLE_OTHER: tr("targeting.single_other"),
	Targeting.SINGLE_SIDE: tr("targeting.single_side"),
	Targeting.SINGLE_SIDE_OR_ALLY: tr("targeting.single_side_or_ally"),
	Targeting.ALL: tr("targeting.all"),
	Targeting.ALL_OTHER: tr("targeting.all_other"),
}

enum Priority {
	MINIMUM,
	NEGATIVE,
	VERY_LOW,
	LOW,
	NORMAL,
	HIGH,
	VERY_HIGH,
	INSTANT,
	MAXIMUM,
}

var priority_labels: Dictionary = {
	Priority.MINIMUM: tr("priority.minimum"),
	Priority.NEGATIVE: tr("priority.negative"),
	Priority.VERY_LOW: tr("priority.very_low"),
	Priority.LOW: tr("priority.low"),
	Priority.NORMAL: tr("priority.normal"),
	Priority.HIGH: tr("priority.high"),
	Priority.VERY_HIGH: tr("priority.very_high"),
	Priority.INSTANT: tr("priority.instant"),
	Priority.MAXIMUM: tr("priority.maximum"),
}

enum BrickType {
	DAMAGE,
	DAMAGE_MODIFIER,
	RECOIL,
	STAT_MODIFIER,
	STAT_PROTECTION,
	STATUS_EFFECT,
	STATUS_INTERACTION,
	HEALING,
	FIELD_EFFECT,
	SIDE_EFFECT,
	HAZARD,
	POSITION_CONTROL,
	TURN_ECONOMY,
	CHARGE_REQUIREMENT,
	REQUIREMENT,
	CONDITIONAL,
	PROTECTION,
	PRIORITY_OVERRIDE,
	TYPE_MODIFIER,
	FLAGS,
	CRITICAL_HIT,
	RESOURCE,
	USE_RANDOM_MOVE,
	TRANSFORM,
	SHIELD,
	COPY_MOVE,
	ABILITY_MANIPULATION,
	TURN_ORDER,
}

var brick_type_labels: Dictionary = {
	BrickType.DAMAGE: tr("brick_type.damage"),
	BrickType.DAMAGE_MODIFIER: tr("brick_type.damage_modifier"),
	BrickType.RECOIL: tr("brick_type.recoil"),
	BrickType.STAT_MODIFIER: tr("brick_type.stat_modifier"),
	BrickType.STAT_PROTECTION: tr("brick_type.stat_protection"),
	BrickType.STATUS_EFFECT: tr("brick_type.status_effect"),
	BrickType.STATUS_INTERACTION: tr("brick_type.status_interaction"),
	BrickType.HEALING: tr("brick_type.healing"),
	BrickType.FIELD_EFFECT: tr("brick_type.field_effect"),
	BrickType.SIDE_EFFECT: tr("brick_type.side_effect"),
	BrickType.HAZARD: tr("brick_type.hazard"),
	BrickType.POSITION_CONTROL: tr("brick_type.position_control"),
	BrickType.TURN_ECONOMY: tr("brick_type.turn_economy"),
	BrickType.CHARGE_REQUIREMENT: tr("brick_type.charge_requirement"),
	BrickType.REQUIREMENT: tr("brick_type.requirement"),
	BrickType.CONDITIONAL: tr("brick_type.conditional"),
	BrickType.PROTECTION: tr("brick_type.protection"),
	BrickType.PRIORITY_OVERRIDE: tr("brick_type.priority_override"),
	BrickType.TYPE_MODIFIER: tr("brick_type.type_modifier"),
	BrickType.FLAGS: tr("brick_type.flags"),
	BrickType.CRITICAL_HIT: tr("brick_type.critical_hit"),
	BrickType.RESOURCE: tr("brick_type.resource"),
	BrickType.USE_RANDOM_MOVE: tr("brick_type.use_random_move"),
	BrickType.TRANSFORM: tr("brick_type.transform"),
	BrickType.SHIELD: tr("brick_type.shield"),
	BrickType.COPY_MOVE: tr("brick_type.copy_move"),
	BrickType.ABILITY_MANIPULATION: tr("brick_type.ability_manipulation"),
	BrickType.TURN_ORDER: tr("brick_type.turn_order"),
}

enum TechniqueTag {
	SOUND,
	WIND,
	EXPLOSIVE,
	CONTACT,
	PUNCH,
	KICK,
	BITE,
	BEAM,
}

var technique_tag_labels: Dictionary = {
	TechniqueTag.SOUND: tr("technique_tag.sound"),
	TechniqueTag.WIND: tr("technique_tag.wind"),
	TechniqueTag.EXPLOSIVE: tr("technique_tag.explosive"),
	TechniqueTag.CONTACT: tr("technique_tag.contact"),
	TechniqueTag.PUNCH: tr("technique_tag.punch"),
	TechniqueTag.KICK: tr("technique_tag.kick"),
	TechniqueTag.BITE: tr("technique_tag.bite"),
	TechniqueTag.BEAM: tr("technique_tag.beam"),
}

# --- Abilities ---

enum AbilityTrigger {
	ON_ENTRY,
	ON_EXIT,
	ON_TURN_START,
	ON_TURN_END,
	ON_BEFORE_ATTACK,
	ON_AFTER_ATTACK,
	ON_BEFORE_HIT,
	ON_AFTER_HIT,
	ON_DEAL_DAMAGE,
	ON_TAKE_DAMAGE,
	ON_FAINT,
	ON_ALLY_FAINT,
	ON_FOE_FAINT,
	ON_STATUS_APPLIED,
	ON_STATUS_INFLICTED,
	ON_STAT_CHANGE,
	ON_WEATHER_CHANGE,
	ON_TERRAIN_CHANGE,
	ON_HP_THRESHOLD,
	CONTINUOUS,
}

var ability_trigger_labels: Dictionary = {
	AbilityTrigger.ON_ENTRY: tr("ability_trigger.on_entry"),
	AbilityTrigger.ON_EXIT: tr("ability_trigger.on_exit"),
	AbilityTrigger.ON_TURN_START: tr("ability_trigger.on_turn_start"),
	AbilityTrigger.ON_TURN_END: tr("ability_trigger.on_turn_end"),
	AbilityTrigger.ON_BEFORE_ATTACK: tr("ability_trigger.on_before_attack"),
	AbilityTrigger.ON_AFTER_ATTACK: tr("ability_trigger.on_after_attack"),
	AbilityTrigger.ON_BEFORE_HIT: tr("ability_trigger.on_before_hit"),
	AbilityTrigger.ON_AFTER_HIT: tr("ability_trigger.on_after_hit"),
	AbilityTrigger.ON_DEAL_DAMAGE: tr("ability_trigger.on_deal_damage"),
	AbilityTrigger.ON_TAKE_DAMAGE: tr("ability_trigger.on_take_damage"),
	AbilityTrigger.ON_FAINT: tr("ability_trigger.on_faint"),
	AbilityTrigger.ON_ALLY_FAINT: tr("ability_trigger.on_ally_faint"),
	AbilityTrigger.ON_FOE_FAINT: tr("ability_trigger.on_foe_faint"),
	AbilityTrigger.ON_STATUS_APPLIED: tr("ability_trigger.on_status_applied"),
	AbilityTrigger.ON_STATUS_INFLICTED: tr("ability_trigger.on_status_inflicted"),
	AbilityTrigger.ON_STAT_CHANGE: tr("ability_trigger.on_stat_change"),
	AbilityTrigger.ON_WEATHER_CHANGE: tr("ability_trigger.on_weather_change"),
	AbilityTrigger.ON_TERRAIN_CHANGE: tr("ability_trigger.on_terrain_change"),
	AbilityTrigger.ON_HP_THRESHOLD: tr("ability_trigger.on_hp_threshold"),
	AbilityTrigger.CONTINUOUS: tr("ability_trigger.continuous"),
}

enum StackLimit {
	UNLIMITED,
	ONCE_PER_TURN,
	ONCE_PER_SWITCH,
	ONCE_PER_BATTLE,
	FIRST_ONLY,
}

var stack_limit_labels: Dictionary = {
	StackLimit.UNLIMITED: tr("stack_limit.unlimited"),
	StackLimit.ONCE_PER_TURN: tr("stack_limit.once_per_turn"),
	StackLimit.ONCE_PER_SWITCH: tr("stack_limit.once_per_switch"),
	StackLimit.ONCE_PER_BATTLE: tr("stack_limit.once_per_battle"),
	StackLimit.FIRST_ONLY: tr("stack_limit.first_only"),
}

# --- Status ---

enum StatusCondition {
	ASLEEP,
	BURNED,
	FROSTBITTEN,
	FROZEN,
	EXHAUSTED,
	POISONED,
	DAZED,
	TRAPPED,
	CONFUSED,
	BLINDED,
	PARALYSED,
	BLEEDING,
	REGENERATING,
	VITALISED,
	NULLIFIED,
	REVERSED,
}

var status_condition_labels: Dictionary = {
	StatusCondition.ASLEEP: tr("status_condition.asleep"),
	StatusCondition.BURNED: tr("status_condition.burned"),
	StatusCondition.FROSTBITTEN: tr("status_condition.frostbitten"),
	StatusCondition.FROZEN: tr("status_condition.frozen"),
	StatusCondition.EXHAUSTED: tr("status_condition.exhausted"),
	StatusCondition.POISONED: tr("status_condition.poisoned"),
	StatusCondition.DAZED: tr("status_condition.dazed"),
	StatusCondition.TRAPPED: tr("status_condition.trapped"),
	StatusCondition.CONFUSED: tr("status_condition.confused"),
	StatusCondition.BLINDED: tr("status_condition.blinded"),
	StatusCondition.PARALYSED: tr("status_condition.paralysed"),
	StatusCondition.BLEEDING: tr("status_condition.bleeding"),
	StatusCondition.REGENERATING: tr("status_condition.regenerating"),
	StatusCondition.VITALISED: tr("status_condition.vitalised"),
	StatusCondition.NULLIFIED: tr("status_condition.nullified"),
	StatusCondition.REVERSED: tr("status_condition.reversed"),
}

enum StatusCategory {
	NEGATIVE,
	POSITIVE,
	NEUTRAL,
}

var status_category_labels: Dictionary = {
	StatusCategory.NEGATIVE: tr("status_category.negative"),
	StatusCategory.POSITIVE: tr("status_category.positive"),
	StatusCategory.NEUTRAL: tr("status_category.neutral"),
}

# --- Evolution ---

enum EvolutionType {
	STANDARD,
	SPIRIT,
	ARMOR,
	SLIDE,
	X_ANTIBODY,
	JOGRESS,
	MODE_CHANGE,
}

var evolution_type_labels: Dictionary = {
	EvolutionType.STANDARD: tr("evolution_type.standard"),
	EvolutionType.SPIRIT: tr("evolution_type.spirit"),
	EvolutionType.ARMOR: tr("evolution_type.armor"),
	EvolutionType.SLIDE: tr("evolution_type.slide"),
	EvolutionType.X_ANTIBODY: tr("evolution_type.x_antibody"),
	EvolutionType.JOGRESS: tr("evolution_type.jogress"),
	EvolutionType.MODE_CHANGE: tr("evolution_type.mode_change"),
}

# --- Items ---

enum ItemCategory {
	GENERAL,
	CAPTURE_SCAN,
	MEDICINE,
	PERFORMANCE,
	GEAR,
	KEY,
	QUEST,
	CARD,
}

var item_category_labels: Dictionary = {
	ItemCategory.GENERAL: tr("item_category.general"),
	ItemCategory.CAPTURE_SCAN: tr("item_category.capture_scan"),
	ItemCategory.MEDICINE: tr("item_category.medicine"),
	ItemCategory.PERFORMANCE: tr("item_category.performance"),
	ItemCategory.GEAR: tr("item_category.gear"),
	ItemCategory.KEY: tr("item_category.key"),
	ItemCategory.QUEST: tr("item_category.quest"),
	ItemCategory.CARD: tr("item_category.card"),
}

enum GearSlot {
	EQUIPABLE,
	CONSUMABLE,
}

var gear_slot_labels: Dictionary = {
	GearSlot.EQUIPABLE: tr("gear_slot.equipable"),
	GearSlot.CONSUMABLE: tr("gear_slot.consumable"),
}

# --- Constants ---

## Stat stage multipliers: maps stage (-6 to +6) to multiplier.
const STAT_STAGE_MULTIPLIERS: Dictionary = {
	-6: 0.25,
	-5: 0.29,
	-4: 0.33,
	-3: 0.40,
	-2: 0.50,
	-1: 0.67,
	0: 1.0,
	1: 1.50,
	2: 2.0,
	3: 2.50,
	4: 3.0,
	5: 3.50,
	6: 4.0,
}

## Priority tier speed multipliers (for tiers that modify speed calculation).
const PRIORITY_SPEED_MULTIPLIERS: Dictionary = {
	Priority.VERY_LOW: 0.25,
	Priority.LOW: 0.5,
	Priority.NORMAL: 1.0,
	Priority.HIGH: 1.5,
	Priority.VERY_HIGH: 2.0,
}
