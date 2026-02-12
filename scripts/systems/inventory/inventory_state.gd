class_name InventoryState
extends RefCounted
## Tracks owned items and currency.

## Item key -> quantity.
var items: Dictionary = {}
var bits: int = 0


func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(),
		"bits": bits,
	}


static func from_dict(data: Dictionary) -> InventoryState:
	var state := InventoryState.new()
	state.items = data.get("items", {})
	# Read "bits" with "money" fallback for backward compatibility.
	state.bits = data.get("bits", data.get("money", 0))
	return state
