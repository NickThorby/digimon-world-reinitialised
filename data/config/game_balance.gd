class_name GameBalance
extends Resource
## Tunable game balance settings. Edit the .tres file to adjust values.

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
