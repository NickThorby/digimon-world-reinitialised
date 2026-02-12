class_name ShopData
extends Resource
## Immutable template defining a shop's stock and pricing.

@export var key: StringName = &""
@export var name: String = ""

## Available stock: Array of { "item_key": StringName, "price": int, "quantity": int }.
## quantity of -1 means unlimited.
@export var stock: Array[Dictionary] = []

## Price multiplier when buying from this shop (1.0 = base price).
@export var buy_multiplier: float = 1.0

## Price multiplier when selling to this shop (0.5 = half base price).
@export var sell_multiplier: float = 0.5
