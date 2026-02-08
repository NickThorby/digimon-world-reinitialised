class_name EvolutionLinkData
extends Resource
## Defines a single evolution path between two Digimon.

@export var key: StringName = &""
@export var from_key: StringName = &""
@export var to_key: StringName = &""
@export var evolution_type: Registry.EvolutionType = Registry.EvolutionType.STANDARD

## Requirements that must ALL be met (AND logic).
@export var requirements: Array[Dictionary] = []

## Digimon keys needed as Jogress partners (for Jogress evolutions).
@export var jogress_partner_keys: Array[StringName] = []
