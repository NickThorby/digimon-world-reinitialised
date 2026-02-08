class_name InventoryState
extends RefCounted
## Tracks owned items and currency.

## Item key -> quantity.
var items: Dictionary = {}
var money: int = 0


func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(),
		"money": money,
	}


static func from_dict(data: Dictionary) -> InventoryState:
	var state := InventoryState.new()
	state.items = data.get("items", {})
	state.money = data.get("money", 0)
	return state
