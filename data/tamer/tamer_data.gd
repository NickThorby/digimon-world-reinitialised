class_name TamerData
extends Resource
## Immutable template defining an NPC tamer for battles.

@export var key: StringName = &""
@export var name: String = ""
@export var title: String = ""

## Party configuration: Array of { "digimon_key": StringName, "level": int,
## "ability_slot": int, "technique_keys": Array[StringName],
## "gear_key": StringName, "consumable_key": StringName }.
@export var party_config: Array[Dictionary] = []

## Item keys this tamer carries (for item usage during battle).
@export var item_keys: Array[StringName] = []

## AI type key for battle behaviour (e.g. &"aggressive", &"defensive").
@export var ai_type: StringName = &"default"

## Sprite key for overworld/battle display.
@export var sprite_key: StringName = &""

## Dialogue lines shown during battle: { "intro": String, "win": String, "lose": String }.
@export var battle_dialogue: Dictionary = {}

## Reward bits given on defeat.
@export var reward_bits: int = 0

## Reward item keys given on defeat: Array of { "key": StringName, "quantity": int }.
@export var reward_items: Array[Dictionary] = []
