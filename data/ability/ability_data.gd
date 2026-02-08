class_name AbilityData
extends Resource
## Immutable template defining an ability. Mapped from digimon-dex Ability table.

@export var key: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var mechanic_description: String = ""

@export var trigger: Registry.AbilityTrigger = Registry.AbilityTrigger.CONTINUOUS
@export var stack_limit: Registry.StackLimit = Registry.StackLimit.UNLIMITED

## Optional condition for trigger (e.g., {hp_percent: 33, type: "below"}).
@export var trigger_condition: Dictionary = {}

## Modular effect bricks.
@export var bricks: Array[Dictionary] = []
