class_name TechniqueData
extends Resource
## Immutable template defining a technique. Mapped from digimon-dex Attack table.

const _Reg = preload("res://autoload/registry.gd")
const _Settings = preload("res://autoload/settings.gd")

@export var key: StringName = &""
@export var jp_name: String = ""
@export var dub_name: String = ""
@export var custom_name: String = ""
@export var description: String = ""
@export var mechanic_description: String = ""

@export var technique_class: _Reg.TechniqueClass = _Reg.TechniqueClass.PHYSICAL
@export var targeting: _Reg.Targeting = _Reg.Targeting.SINGLE_OTHER
@export var element_key: StringName = &""
@export var power: int = 0
@export var accuracy: int = 100
@export var energy_cost: int = 10
@export var priority: _Reg.Priority = _Reg.Priority.NORMAL

@export var flags: Array[_Reg.TechniqueFlag] = []

## Number of charges required before use (0 = no charge needed).
@export var charge_required: int = 0
## Conditions for gaining charges (e.g., turns, damaged, hit_by_type).
@export var charge_conditions: Array[Dictionary] = []

## Modular effect bricks defining what this technique does.
@export var bricks: Array[Dictionary] = []


## Returns the display name based on player preference settings.
var display_name: String:
	get:
		if Engine.has_singleton(&"Settings"):
			var settings: Node = Engine.get_singleton(&"Settings")
			if settings.use_game_names and custom_name != "":
				return custom_name
			if settings.display_preference == _Settings.DisplayPreference.JAPANESE:
				return jp_name
		if dub_name != "":
			return dub_name
		return jp_name
