class_name ItemData
extends Resource
## Base item resource defining any item in the game.

@export var key: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var category: Registry.ItemCategory = Registry.ItemCategory.GENERAL
@export var is_consumable: bool = false
@export var is_combat_usable: bool = false

## Modular effect bricks (for gear effects, medicine effects, etc.).
@export var bricks: Array[Dictionary] = []
