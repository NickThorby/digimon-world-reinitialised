class_name PersonalityData
extends Resource
## Defines a personality with stat modifiers (+10%/-10%).
## When boosted_stat == reduced_stat, the personality is effectively neutral.

@export var key: StringName = &""
@export var boosted_stat: Registry.Stat = Registry.Stat.ATTACK
@export var reduced_stat: Registry.Stat = Registry.Stat.ATTACK
