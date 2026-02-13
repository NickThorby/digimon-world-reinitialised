class_name ItemGiveHandler
extends RefCounted
## Static utility for giving items to Digimon. Used by both the bag-give
## flow and the context-menu-give flow in the party screen.

enum GiveResult { EQUIPPED, SWAPPED, ALREADY_HELD, INVALID }


## Attempt to give an item to a Digimon. Returns a Dictionary with:
##   "result": GiveResult — the outcome
##   "old_key": StringName — the previously held item key (if swapped), else &""
static func give_item(
	member: DigimonState,
	item_key: StringName,
	inventory: InventoryState,
) -> Dictionary:
	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	if item_data == null:
		return {"result": GiveResult.INVALID, "old_key": &""}

	# Check if already holding the same item
	if item_data.is_consumable:
		if member.equipped_consumable_key == item_key:
			return {"result": GiveResult.ALREADY_HELD, "old_key": &""}
	else:
		if member.equipped_gear_key == item_key:
			return {"result": GiveResult.ALREADY_HELD, "old_key": &""}

	# Return old item to inventory if slot was occupied
	var old_key: StringName = &""
	if item_data.is_consumable:
		if member.equipped_consumable_key != &"":
			old_key = member.equipped_consumable_key
			var current: int = int(inventory.items.get(old_key, 0))
			inventory.items[old_key] = current + 1
		member.equipped_consumable_key = item_key
	else:
		if member.equipped_gear_key != &"":
			old_key = member.equipped_gear_key
			var current: int = int(inventory.items.get(old_key, 0))
			inventory.items[old_key] = current + 1
		member.equipped_gear_key = item_key

	# Remove item from inventory
	var current_qty: int = int(inventory.items.get(item_key, 0))
	if current_qty <= 1:
		inventory.items.erase(item_key)
	else:
		inventory.items[item_key] = current_qty - 1

	var result: GiveResult = GiveResult.SWAPPED if old_key != &"" else GiveResult.EQUIPPED
	return {"result": result, "old_key": old_key}
