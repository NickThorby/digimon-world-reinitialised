class_name GameBalance
extends Resource
## Tunable game balance settings. Edit the .tres file to adjust values.

# --- Core ---

@export var attribute_advantage_multiplier: float = 1.5
@export var attribute_disadvantage_multiplier: float = 0.5
@export var damage_variance_min: float = 0.85
@export var damage_variance_max: float = 1.0
@export var max_party_size: int = 3
@export var max_equipped_techniques: int = 4
@export var energy_regen_per_turn: float = 0.05
@export var energy_regen_on_rest: float = 0.25
@export var max_iv: int = 50
@export var max_tv: int = 500
@export var personality_modifier: float = 0.1
@export var overexertion_damage_multiplier: float = 0.25

# --- Field effect durations ---

@export var default_weather_duration: int = 5
@export var default_terrain_duration: int = 5
@export var default_global_effect_duration: int = 5
@export var default_side_effect_duration: int = 5

# --- Weather ---

@export var weather_damage_boost: float = 1.5
@export var weather_damage_nerf: float = 0.5
@export var weather_tick_damage_percent: float = 0.0625  # 1/16 max HP
@export var weather_healing_boost: float = 0.667  # 2/3 in favourable weather
@export var weather_healing_nerf: float = 0.25  # 1/4 in unfavourable weather
@export var weather_healing_default: float = 0.5  # 1/2 in no weather
@export var weather_tick_healing_percent: float = 0.0625  # 1/16 max HP

# --- Terrain ---

@export var terrain_tick_damage_percent: float = 0.0625  # 1/16 max HP
@export var terrain_tick_healing_percent: float = 0.0625  # 1/16 max HP

# --- Preset field effects ---

@export var preset_hazard_return_delay: int = 2  ## Turns before removed preset hazard returns

# --- Barriers ---

@export var physical_barrier_multiplier: float = 0.5
@export var special_barrier_multiplier: float = 0.5
@export var dual_barrier_multiplier: float = 0.67

# --- Side effects ---

@export var speed_boost_multiplier: float = 1.5

# --- Status durations ---

@export var sleep_min_turns: int = 2
@export var sleep_max_turns: int = 5
@export var freeze_min_turns: int = 1
@export var freeze_max_turns: int = 3
@export var confusion_min_turns: int = 2
@export var confusion_max_turns: int = 5
@export var encore_duration: int = 3
@export var taunt_duration: int = 3
@export var disable_duration: int = 4
@export var perish_countdown: int = 3

# --- Protection ---

@export var protection_fail_escalation: float = 0.5

# --- Decoy ---

@export var decoy_hp_cost_percent: float = 0.25

# --- Critical hits ---

@export var crit_damage_multiplier: float = 1.5

# --- STAB (Same-Type Attack Bonus) ---

@export var element_stab_multiplier: float = 1.5

# --- Multi-side battle ---

@export var max_sides: int = 4
@export var max_slots_per_side: int = 3

# --- Level ---

@export var max_level: int = 100
