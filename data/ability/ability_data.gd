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

## Optional condition string for trigger (e.g., "userHpBelow:33").
## Uses BrickConditionEvaluator format: "condType:value" with "|" for AND.
@export var trigger_condition: String = ""

## Modular effect bricks.
@export var bricks: Array[Dictionary] = []
