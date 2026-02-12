class_name StorageState
extends RefCounted
## Box-based Digimon storage system. Each box has a fixed number of slots.

## Array of boxes. Each box is a Dictionary with "name" and "slots" keys.
## slots is an Array of Variant (DigimonState or null).
var boxes: Array[Dictionary] = []


func _init() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	var box_count: int = balance.storage_box_count if balance else 100
	var slots_per_box: int = balance.storage_slots_per_box if balance else 50
	_create_boxes(box_count, slots_per_box)


func _create_boxes(box_count: int, slots_per_box: int) -> void:
	boxes.clear()
	for i: int in box_count:
		var slots: Array = []
		slots.resize(slots_per_box)
		slots.fill(null)
		boxes.append({"name": "Box %d" % (i + 1), "slots": slots})


## Get the Digimon at a specific box and slot index. Returns null if empty or out of bounds.
func get_digimon(box_index: int, slot_index: int) -> DigimonState:
	if box_index < 0 or box_index >= boxes.size():
		return null
	var slots: Array = boxes[box_index]["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index] as DigimonState


## Place a Digimon at a specific box and slot index.
func set_digimon(box_index: int, slot_index: int, digimon: DigimonState) -> void:
	if box_index < 0 or box_index >= boxes.size():
		return
	var slots: Array = boxes[box_index]["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return
	slots[slot_index] = digimon


## Remove and return the Digimon at a specific box and slot index.
func remove_digimon(box_index: int, slot_index: int) -> DigimonState:
	var digimon: DigimonState = get_digimon(box_index, slot_index)
	if digimon != null:
		boxes[box_index]["slots"][slot_index] = null
	return digimon


## Swap the Digimon in two slots (can be in different boxes).
func swap_digimon(
	box_a: int, slot_a: int, box_b: int, slot_b: int,
) -> void:
	var a: DigimonState = get_digimon(box_a, slot_a)
	var b: DigimonState = get_digimon(box_b, slot_b)
	set_digimon(box_a, slot_a, b)
	set_digimon(box_b, slot_b, a)


## Find the first empty slot across all boxes.
## Returns { "box": int, "slot": int } or an empty Dictionary if full.
func find_first_empty_slot() -> Dictionary:
	for box_index: int in boxes.size():
		var slots: Array = boxes[box_index]["slots"]
		for slot_index: int in slots.size():
			if slots[slot_index] == null:
				return {"box": box_index, "slot": slot_index}
	return {}


## Return the total number of boxes.
func get_box_count() -> int:
	return boxes.size()


## Return the number of occupied slots in a specific box.
func get_box_occupied_count(box_index: int) -> int:
	if box_index < 0 or box_index >= boxes.size():
		return 0
	var count: int = 0
	for slot: Variant in boxes[box_index]["slots"]:
		if slot != null:
			count += 1
	return count


## Return the total number of stored Digimon across all boxes.
func get_total_stored() -> int:
	var count: int = 0
	for box: Dictionary in boxes:
		for slot: Variant in box["slots"]:
			if slot != null:
				count += 1
	return count


func to_dict() -> Dictionary:
	var box_dicts: Array[Dictionary] = []
	for box: Dictionary in boxes:
		var slot_dicts: Array = []
		for slot: Variant in box["slots"]:
			if slot is DigimonState:
				slot_dicts.append((slot as DigimonState).to_dict())
			else:
				slot_dicts.append(null)
		box_dicts.append({"name": box["name"], "slots": slot_dicts})
	return {"boxes": box_dicts}


static func from_dict(data: Dictionary) -> StorageState:
	var state := StorageState.new()
	var box_dicts: Array = data.get("boxes", [])
	# Overlay loaded data onto the default boxes (bounds-safe).
	for i: int in mini(box_dicts.size(), state.boxes.size()):
		var box_data: Dictionary = box_dicts[i] as Dictionary
		if box_data == null:
			continue
		state.boxes[i]["name"] = box_data.get("name", state.boxes[i]["name"])
		var slot_dicts: Array = box_data.get("slots", [])
		var slots: Array = state.boxes[i]["slots"]
		for j: int in mini(slot_dicts.size(), slots.size()):
			if slot_dicts[j] is Dictionary:
				slots[j] = DigimonState.from_dict(slot_dicts[j] as Dictionary)
			else:
				slots[j] = null
	return state
