class_name PersonalityData
extends Resource
## Defines a personality with stat modifiers (+10%/-10%).
## When boosted_stat == reduced_stat, the personality is effectively neutral.

const _Reg = preload("res://autoload/registry.gd")

@export var key: StringName = &""
@export var boosted_stat: _Reg.Stat = _Reg.Stat.ATTACK
@export var reduced_stat: _Reg.Stat = _Reg.Stat.ATTACK
