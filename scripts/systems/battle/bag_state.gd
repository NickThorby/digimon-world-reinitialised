class_name BagState
extends RefCounted
## Battle-specific item bag. Tracks item quantities for in-battle use.

const _Reg = preload("res://autoload/registry.gd")

## Item key -> quantity.
var _items: Dictionary = {}


## Add items to the bag.
func add_item(key: StringName, quantity: int = 1) -> void:
	_items[key] = int(_items.get(key, 0)) + quantity


## Remove items from the bag. Returns true if successful, false if insufficient.
func remove_item(key: StringName, quantity: int = 1) -> bool:
	var current: int = int(_items.get(key, 0))
	if current < quantity:
		return false
	current -= quantity
	if current <= 0:
		_items.erase(key)
	else:
		_items[key] = current
	return true


## Check if the bag contains at least one of this item.
func has_item(key: StringName) -> bool:
	return int(_items.get(key, 0)) > 0


## Get the quantity of an item in the bag.
func get_quantity(key: StringName) -> int:
	return int(_items.get(key, 0))


## Get all combat-usable items as [{key, quantity}].
func get_combat_usable_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: StringName in _items:
		var item: ItemData = Atlas.items.get(key) as ItemData
		if item != null and item.is_combat_usable:
			result.append({"key": key, "quantity": int(_items[key])})
	return result


## Get all items in a specific category as [{key, quantity}].
func get_items_in_category(category: _Reg.ItemCategory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: StringName in _items:
		var item: ItemData = Atlas.items.get(key) as ItemData
		if item != null and item.category == category:
			result.append({"key": key, "quantity": int(_items[key])})
	return result


## Get all items as [{key, quantity}].
func get_all_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: StringName in _items:
		result.append({"key": key, "quantity": int(_items[key])})
	return result


## Whether the bag is empty.
func is_empty() -> bool:
	return _items.is_empty()


## Serialise to dictionary.
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	for key: StringName in _items:
		data[str(key)] = int(_items[key])
	return data


## Deserialise from dictionary.
static func from_dict(data: Dictionary) -> BagState:
	var bag := BagState.new()
	for key: String in data:
		bag._items[StringName(key)] = int(data[key])
	return bag
