class_name ItemData
extends Resource
## Base item resource defining any item in the game.

const _Reg = preload("res://autoload/registry.gd")

@export var key: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var category: _Reg.ItemCategory = _Reg.ItemCategory.GENERAL
@export var is_consumable: bool = false
@export var is_combat_usable: bool = false

## Modular effect bricks (for gear effects, medicine effects, etc.).
@export var bricks: Array[Dictionary] = []
