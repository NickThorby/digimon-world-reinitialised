class_name AbilityData
extends Resource
## Immutable template defining an ability. Mapped from digimon-dex Ability table.

const _Reg = preload("res://autoload/registry.gd")

@export var key: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var mechanic_description: String = ""

@export var trigger: _Reg.AbilityTrigger = _Reg.AbilityTrigger.CONTINUOUS
@export var stack_limit: _Reg.StackLimit = _Reg.StackLimit.UNLIMITED

## Optional condition for trigger (e.g., {hp_percent: 33, type: "below"}).
@export var trigger_condition: Dictionary = {}

## Modular effect bricks.
@export var bricks: Array[Dictionary] = []
