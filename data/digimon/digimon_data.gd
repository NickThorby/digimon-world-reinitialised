class_name DigimonData
extends Resource
## Immutable template defining a Digimon species. Mapped from digimon-dex Digimon table.

const _Settings = preload("res://autoload/settings.gd")

@export var key: StringName = &""
@export var jp_name: String = ""
@export var dub_name: String = ""
@export var custom_name: String = ""

## Size trait key (max 1). Empty if unset.
@export var size_trait: StringName = &""
## Movement trait keys (unlimited).
@export var movement_traits: Array[StringName] = []
## Type trait key (max 1). Empty if unset.
@export var type_trait: StringName = &""
## Element trait keys (unlimited). Used for STAB calculation.
@export var element_traits: Array[StringName] = []

@export var level: int = 1
@export var attribute: Registry.Attribute = Registry.Attribute.NONE

# Base stats
@export var base_hp: int = 0
@export var base_energy: int = 0
@export var base_attack: int = 0
@export var base_defence: int = 0
@export var base_special_attack: int = 0
@export var base_special_defence: int = 0
@export var base_speed: int = 0
@export var bst: int = 0

## Element key -> resistance multiplier (0.0 immune, 0.5 resistant, 1.0 neutral, 1.5 weak, 2.0 very weak).
@export var resistances: Dictionary = {}

## Keys of techniques this Digimon learns innately.
@export var innate_technique_keys: Array[StringName] = []
## Keys of all techniques this Digimon can learn.
@export var learnable_technique_keys: Array[StringName] = []

## Ability slot keys (slot 3 is hidden/secret).
@export var ability_slot_1_key: StringName = &""
@export var ability_slot_2_key: StringName = &""
@export var ability_slot_3_key: StringName = &""


## Returns the display name based on player preference settings.
var display_name: String:
	get:
		var settings: Node = Engine.get_singleton(&"Settings")
		if settings and settings.use_game_names and custom_name != "":
			return custom_name
		if settings and settings.display_preference == _Settings.DisplayPreference.JAPANESE:
			return jp_name
		if dub_name != "":
			return dub_name
		return jp_name
