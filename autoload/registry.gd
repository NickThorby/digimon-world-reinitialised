extends Node
## Central enum registry and game constants.

# Preload Settings script for enum access without autoload dependency.
const _SettingsScript = preload("res://autoload/settings.gd")

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
	if Engine.has_singleton("Settings"):
		var settings_node: Node = Engine.get_singleton("Settings")
		if settings_node.display_preference == _SettingsScript.DisplayPreference.JAPANESE:
			return _evolution_level_jp_labels.get(level, "Unknown")
	return _evolution_level_dub_labels.get(level, "Unknown")

## Returns the full evolution level labels dictionary based on display preference.
var evolution_level_labels: Dictionary:
	get:
		if Engine.has_singleton("Settings"):
			var settings_node: Node = Engine.get_singleton("Settings")
			if settings_node.display_preference == _SettingsScript.DisplayPreference.JAPANESE:
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
	SELF,               ## User only
	SINGLE_TARGET,      ## Any one Digimon (ally or foe)
	SINGLE_OTHER,       ## Any one Digimon except user
	SINGLE_ALLY,        ## One ally on same side (not self)
	SINGLE_FOE,         ## One Digimon on any foe side
	ALL_ALLIES,         ## All Digimon on user's side (incl. self)
	ALL_OTHER_ALLIES,   ## All allies on user's side except self
	ALL_FOES,           ## All Digimon on all foe sides
	ALL,                ## Every Digimon on the field
	ALL_OTHER,          ## Every Digimon except user
	SINGLE_SIDE,        ## An entire side (for hazards, side effects)
	FIELD,              ## Entire field (weather, terrain, global)
}

var targeting_labels: Dictionary = {
	Targeting.SELF: tr("targeting.self"),
	Targeting.SINGLE_TARGET: tr("targeting.single_target"),
	Targeting.SINGLE_OTHER: tr("targeting.single_other"),
	Targeting.SINGLE_ALLY: tr("targeting.single_ally"),
	Targeting.SINGLE_FOE: tr("targeting.single_foe"),
	Targeting.ALL_ALLIES: tr("targeting.all_allies"),
	Targeting.ALL_OTHER_ALLIES: tr("targeting.all_other_allies"),
	Targeting.ALL_FOES: tr("targeting.all_foes"),
	Targeting.ALL: tr("targeting.all"),
	Targeting.ALL_OTHER: tr("targeting.all_other"),
	Targeting.SINGLE_SIDE: tr("targeting.single_side"),
	Targeting.FIELD: tr("targeting.field"),
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
	SYNERGY,
	REQUIREMENT,
	CONDITIONAL,
	PROTECTION,
	PRIORITY_OVERRIDE,
	TYPE_MODIFIER,
	FLAGS,
	CRITICAL_HIT,
	RESOURCE,
	USE_RANDOM_TECHNIQUE,
	TRANSFORM,
	SHIELD,
	COPY_TECHNIQUE,
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
	BrickType.SYNERGY: tr("brick_type.synergy"),
	BrickType.REQUIREMENT: tr("brick_type.requirement"),
	BrickType.CONDITIONAL: tr("brick_type.conditional"),
	BrickType.PROTECTION: tr("brick_type.protection"),
	BrickType.PRIORITY_OVERRIDE: tr("brick_type.priority_override"),
	BrickType.TYPE_MODIFIER: tr("brick_type.type_modifier"),
	BrickType.FLAGS: tr("brick_type.flags"),
	BrickType.CRITICAL_HIT: tr("brick_type.critical_hit"),
	BrickType.RESOURCE: tr("brick_type.resource"),
	BrickType.USE_RANDOM_TECHNIQUE: tr("brick_type.use_random_technique"),
	BrickType.TRANSFORM: tr("brick_type.transform"),
	BrickType.SHIELD: tr("brick_type.shield"),
	BrickType.COPY_TECHNIQUE: tr("brick_type.copy_technique"),
	BrickType.ABILITY_MANIPULATION: tr("brick_type.ability_manipulation"),
	BrickType.TURN_ORDER: tr("brick_type.turn_order"),
}

enum TechniqueFlag {
	CONTACT,        ## Makes physical contact
	SOUND,          ## Sound-based, may bypass shields
	PUNCH,          ## Punch-based, boosted by fist abilities
	KICK,           ## Kick-based
	BITE,           ## Bite-based, boosted by jaw abilities
	BLADE,          ## Slashing/blade-based
	BEAM,           ## Beam/ray-based
	EXPLOSIVE,      ## Explosive, may hit semi-invulnerable
	BULLET,         ## Projectile-based
	POWDER,         ## Powder/spore, blocked by certain abilities
	WIND,           ## Wind-based
	FLYING,         ## Aerial, blocked by grounding field
	GROUNDABLE,        ## Affected by grounding field
	DEFROST,        ## Thaws frozen user before executing
	REFLECTABLE,    ## Can be reflected by technique reflection
	SNATCHABLE,     ## Can be snatched
}

var technique_flag_labels: Dictionary = {
	TechniqueFlag.CONTACT: tr("technique_flag.contact"),
	TechniqueFlag.SOUND: tr("technique_flag.sound"),
	TechniqueFlag.PUNCH: tr("technique_flag.punch"),
	TechniqueFlag.KICK: tr("technique_flag.kick"),
	TechniqueFlag.BITE: tr("technique_flag.bite"),
	TechniqueFlag.BLADE: tr("technique_flag.blade"),
	TechniqueFlag.BEAM: tr("technique_flag.beam"),
	TechniqueFlag.EXPLOSIVE: tr("technique_flag.explosive"),
	TechniqueFlag.BULLET: tr("technique_flag.bullet"),
	TechniqueFlag.POWDER: tr("technique_flag.powder"),
	TechniqueFlag.WIND: tr("technique_flag.wind"),
	TechniqueFlag.FLYING: tr("technique_flag.flying"),
	TechniqueFlag.GROUNDABLE: tr("technique_flag.groundable"),
	TechniqueFlag.DEFROST: tr("technique_flag.defrost"),
	TechniqueFlag.REFLECTABLE: tr("technique_flag.reflectable"),
	TechniqueFlag.SNATCHABLE: tr("technique_flag.snatchable"),
}

# --- Abilities ---

enum AbilityTrigger {
	ON_ENTRY,
	ON_EXIT,
	ON_TURN_START,
	ON_TURN_END,
	ON_BEFORE_TECHNIQUE,
	ON_AFTER_TECHNIQUE,
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
	AbilityTrigger.ON_BEFORE_TECHNIQUE: tr("ability_trigger.on_before_technique"),
	AbilityTrigger.ON_AFTER_TECHNIQUE: tr("ability_trigger.on_after_technique"),
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
	# Negative (19)
	ASLEEP,
	BURNED,
	BADLY_BURNED,
	FROSTBITTEN,
	FROZEN,
	EXHAUSTED,
	POISONED,
	BADLY_POISONED,
	DAZED,
	TRAPPED,
	CONFUSED,
	BLINDED,
	PARALYSED,
	BLEEDING,
	ENCORED,
	TAUNTED,
	DISABLED,
	PERISHING,
	SEEDED,
	# Positive (2)
	REGENERATING,
	VITALISED,
	# Neutral (2)
	NULLIFIED,
	REVERSED,
}

var status_condition_labels: Dictionary = {
	StatusCondition.ASLEEP: tr("status_condition.asleep"),
	StatusCondition.BURNED: tr("status_condition.burned"),
	StatusCondition.BADLY_BURNED: tr("status_condition.badly_burned"),
	StatusCondition.FROSTBITTEN: tr("status_condition.frostbitten"),
	StatusCondition.FROZEN: tr("status_condition.frozen"),
	StatusCondition.EXHAUSTED: tr("status_condition.exhausted"),
	StatusCondition.POISONED: tr("status_condition.poisoned"),
	StatusCondition.BADLY_POISONED: tr("status_condition.badly_poisoned"),
	StatusCondition.DAZED: tr("status_condition.dazed"),
	StatusCondition.TRAPPED: tr("status_condition.trapped"),
	StatusCondition.CONFUSED: tr("status_condition.confused"),
	StatusCondition.BLINDED: tr("status_condition.blinded"),
	StatusCondition.PARALYSED: tr("status_condition.paralysed"),
	StatusCondition.BLEEDING: tr("status_condition.bleeding"),
	StatusCondition.ENCORED: tr("status_condition.encored"),
	StatusCondition.TAUNTED: tr("status_condition.taunted"),
	StatusCondition.DISABLED: tr("status_condition.disabled"),
	StatusCondition.PERISHING: tr("status_condition.perishing"),
	StatusCondition.SEEDED: tr("status_condition.seeded"),
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

# --- Battle ---

## Battle-only stats (includes accuracy/evasion which are stage-modifiable but not permanent).
enum BattleStat {
	HP,
	ATTACK,
	DEFENCE,
	SPECIAL_ATTACK,
	SPECIAL_DEFENCE,
	SPEED,
	ENERGY,
	ACCURACY,
	EVASION,
}

var battle_stat_labels: Dictionary = {
	BattleStat.HP: tr("battle_stat.hp"),
	BattleStat.ATTACK: tr("battle_stat.attack"),
	BattleStat.DEFENCE: tr("battle_stat.defence"),
	BattleStat.SPECIAL_ATTACK: tr("battle_stat.special_attack"),
	BattleStat.SPECIAL_DEFENCE: tr("battle_stat.special_defence"),
	BattleStat.SPEED: tr("battle_stat.speed"),
	BattleStat.ENERGY: tr("battle_stat.energy"),
	BattleStat.ACCURACY: tr("battle_stat.accuracy"),
	BattleStat.EVASION: tr("battle_stat.evasion"),
}

## Within-brick targeting (distinct from technique-level Targeting).
enum BrickTarget {
	SELF,
	TARGET,
	ALL_FOES,
	ALL_ALLIES,
	ALL,
	ATTACKER,
	FIELD,
}

var brick_target_labels: Dictionary = {
	BrickTarget.SELF: tr("brick_target.self"),
	BrickTarget.TARGET: tr("brick_target.target"),
	BrickTarget.ALL_FOES: tr("brick_target.all_foes"),
	BrickTarget.ALL_ALLIES: tr("brick_target.all_allies"),
	BrickTarget.ALL: tr("brick_target.all"),
	BrickTarget.ATTACKER: tr("brick_target.attacker"),
	BrickTarget.FIELD: tr("brick_target.field"),
}

## Battle counters for scaling effects.
enum BattleCounter {
	TIMES_HIT_THIS_BATTLE,
	ALLIES_FAINTED_THIS_BATTLE,
	FOES_FAINTED_THIS_BATTLE,
	USER_STAT_STAGES_TOTAL,
	TARGET_STAT_STAGES_TOTAL,
	TURNS_ON_FIELD,
	CONSECUTIVE_USES,
}

var battle_counter_labels: Dictionary = {
	BattleCounter.TIMES_HIT_THIS_BATTLE: tr("battle_counter.times_hit_this_battle"),
	BattleCounter.ALLIES_FAINTED_THIS_BATTLE: tr("battle_counter.allies_fainted_this_battle"),
	BattleCounter.FOES_FAINTED_THIS_BATTLE: tr("battle_counter.foes_fainted_this_battle"),
	BattleCounter.USER_STAT_STAGES_TOTAL: tr("battle_counter.user_stat_stages_total"),
	BattleCounter.TARGET_STAT_STAGES_TOTAL: tr("battle_counter.target_stat_stages_total"),
	BattleCounter.TURNS_ON_FIELD: tr("battle_counter.turns_on_field"),
	BattleCounter.CONSECUTIVE_USES: tr("battle_counter.consecutive_uses"),
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

## BattleStat enum to stat_stages dictionary key mapping.
const BATTLE_STAT_STAGE_KEYS: Dictionary = {
	BattleStat.ATTACK: &"attack",
	BattleStat.DEFENCE: &"defence",
	BattleStat.SPECIAL_ATTACK: &"special_attack",
	BattleStat.SPECIAL_DEFENCE: &"special_defence",
	BattleStat.SPEED: &"speed",
	BattleStat.ACCURACY: &"accuracy",
	BattleStat.EVASION: &"evasion",
}

## Dex brick stat abbreviation to game BattleStat mapping.
const BRICK_STAT_MAP: Dictionary = {
	"hp": BattleStat.HP,
	"atk": BattleStat.ATTACK,
	"def": BattleStat.DEFENCE,
	"spa": BattleStat.SPECIAL_ATTACK,
	"spd": BattleStat.SPECIAL_DEFENCE,
	"spe": BattleStat.SPEED,
	"energy": BattleStat.ENERGY,
	"accuracy": BattleStat.ACCURACY,
	"evasion": BattleStat.EVASION,
}

## Crit stage to crit chance mapping.
const CRIT_STAGE_RATES: Dictionary = {
	0: 1.0 / 24.0,
	1: 1.0 / 8.0,
	2: 1.0 / 2.0,
	3: 1.0,
}

const CRIT_DAMAGE_MULTIPLIER: float = 1.5

## Battle field constant arrays.
const WEATHER_TYPES: Array[StringName] = [
	&"sun", &"rain", &"sandstorm", &"hail", &"snow", &"fog",
]

const TERRAIN_TYPES: Array[StringName] = [
	&"flooded", &"blooming",
]

const HAZARD_TYPES: Array[StringName] = [
	&"entry_damage", &"entry_stat_reduction",
]

const GLOBAL_EFFECT_TYPES: Array[StringName] = [
	&"grounding_field", &"speed_inversion", &"gear_suppression", &"defence_swap",
]

const SIDE_EFFECT_TYPES: Array[StringName] = [
	&"physical_barrier", &"special_barrier", &"dual_barrier",
	&"stat_drop_immunity", &"status_immunity", &"speed_boost",
	&"crit_immunity", &"spread_protection", &"priority_protection",
	&"first_turn_protection",
]

const SHIELD_TYPES: Array[StringName] = [
	&"hp_decoy", &"intact_form_guard", &"endure",
	&"last_stand", &"negate_one_move_class",
]

const SEMI_INVULNERABLE_STATES: Array[StringName] = [
	&"sky", &"underground", &"underwater", &"shadow", &"intangible",
]

## Maps dex priority integers (-4 to 4) to game Priority enum values.
## XP growth rate curves (Pokemon-style).
enum GrowthRate {
	ERRATIC,
	FAST,
	MEDIUM_FAST,
	MEDIUM_SLOW,
	SLOW,
	FLUCTUATING,
}

var growth_rate_labels: Dictionary = {
	GrowthRate.ERRATIC: tr("growth_rate.erratic"),
	GrowthRate.FAST: tr("growth_rate.fast"),
	GrowthRate.MEDIUM_FAST: tr("growth_rate.medium_fast"),
	GrowthRate.MEDIUM_SLOW: tr("growth_rate.medium_slow"),
	GrowthRate.SLOW: tr("growth_rate.slow"),
	GrowthRate.FLUCTUATING: tr("growth_rate.fluctuating"),
}

## Persistent status conditions (survive battle, saved to disk).
const PERSISTENT_STATUSES: Array[StatusCondition] = [
	StatusCondition.ASLEEP,
	StatusCondition.BURNED,
	StatusCondition.BADLY_BURNED,
	StatusCondition.FROSTBITTEN,
	StatusCondition.FROZEN,
	StatusCondition.POISONED,
	StatusCondition.BADLY_POISONED,
	StatusCondition.PARALYSED,
	StatusCondition.BLINDED,
	StatusCondition.EXHAUSTED,
	StatusCondition.DAZED,
]

## Volatile status conditions (battle-only, reset on battle end).
const VOLATILE_STATUSES: Array[StatusCondition] = [
	StatusCondition.CONFUSED,
	StatusCondition.TRAPPED,
	StatusCondition.BLEEDING,
	StatusCondition.ENCORED,
	StatusCondition.TAUNTED,
	StatusCondition.DISABLED,
	StatusCondition.PERISHING,
	StatusCondition.SEEDED,
	StatusCondition.REGENERATING,
	StatusCondition.VITALISED,
	StatusCondition.NULLIFIED,
	StatusCondition.REVERSED,
]

## Maps status condition keys to the element whose resistance ≤ 0.5 grants immunity.
const STATUS_RESISTANCE_IMMUNITIES: Dictionary = {
	&"burned": &"fire",
	&"badly_burned": &"fire",
	&"frostbitten": &"ice",
	&"frozen": &"ice",
	&"poisoned": &"dark",
	&"badly_poisoned": &"dark",
	&"paralysed": &"lightning",
	&"seeded": &"plant",
}

## Escalating DoT fractions for badly_burned / badly_poisoned (indexed by turn).
const ESCALATION_FRACTIONS: Array[float] = [
	0.0625,  # 1/16 (turn 0)
	0.125,   # 1/8  (turn 1)
	0.25,    # 1/4  (turn 2)
	0.5,     # 1/2  (turn 3)
	1.0,     # 1/1  (turn 4+)
]

## Element enum -> icon texture for UI display.
const ELEMENT_ICONS: Dictionary = {
	Element.NULL_ELEMENT: preload("res://assets/icons/elements/null-icon.png"),
	Element.FIRE: preload("res://assets/icons/elements/fire-icon.png"),
	Element.WATER: preload("res://assets/icons/elements/water-icon.png"),
	Element.AIR: preload("res://assets/icons/elements/air-icon.png"),
	Element.EARTH: preload("res://assets/icons/elements/earth-icon.png"),
	Element.ICE: preload("res://assets/icons/elements/ice-icon.png"),
	Element.LIGHTNING: preload("res://assets/icons/elements/lightning-icon.png"),
	Element.PLANT: preload("res://assets/icons/elements/plant-icon.png"),
	Element.METAL: preload("res://assets/icons/elements/metal-icon.png"),
	Element.DARK: preload("res://assets/icons/elements/dark-icon.png"),
	Element.LIGHT: preload("res://assets/icons/elements/light-icon.png"),
}

## Attribute enum -> icon texture for UI display.
const ATTRIBUTE_ICONS: Dictionary = {
	Attribute.VACCINE: preload("res://assets/icons/attributes/vaccine-icon.png"),
	Attribute.VIRUS: preload("res://assets/icons/attributes/virus-icon.png"),
	Attribute.DATA: preload("res://assets/icons/attributes/data-icon.png"),
	Attribute.FREE: preload("res://assets/icons/attributes/free-icon.png"),
	Attribute.VARIABLE: preload("res://assets/icons/attributes/variable-icon.png"),
	Attribute.UNKNOWN: preload("res://assets/icons/attributes/unknown-icon.png"),
}

## Element key (StringName) -> Element enum for icon lookup from technique data.
const ELEMENT_KEY_MAP: Dictionary = {
	&"null": Element.NULL_ELEMENT,
	&"fire": Element.FIRE,
	&"water": Element.WATER,
	&"air": Element.AIR,
	&"earth": Element.EARTH,
	&"ice": Element.ICE,
	&"lightning": Element.LIGHTNING,
	&"plant": Element.PLANT,
	&"metal": Element.METAL,
	&"dark": Element.DARK,
	&"light": Element.LIGHT,
}

const ELEMENT_COLOURS: Dictionary = {
	&"null": Color(0.75, 0.75, 0.75),
	&"fire": Color(1.0, 0.35, 0.1),
	&"water": Color(0.2, 0.5, 1.0),
	&"air": Color(0.7, 0.9, 1.0),
	&"earth": Color(0.6, 0.4, 0.2),
	&"ice": Color(0.6, 0.9, 1.0),
	&"lightning": Color(1.0, 0.9, 0.2),
	&"plant": Color(0.2, 0.8, 0.3),
	&"metal": Color(0.7, 0.7, 0.75),
	&"dark": Color(0.4, 0.1, 0.5),
	&"light": Color(1.0, 0.95, 0.6),
}

const DEX_PRIORITY_MAP: Dictionary = {
	-4: Priority.MINIMUM,
	-3: Priority.NEGATIVE,
	-2: Priority.VERY_LOW,
	-1: Priority.LOW,
	0: Priority.NORMAL,
	1: Priority.HIGH,
	2: Priority.VERY_HIGH,
	3: Priority.INSTANT,
	4: Priority.MAXIMUM,
}
