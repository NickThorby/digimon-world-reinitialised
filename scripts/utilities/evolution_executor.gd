class_name EvolutionExecutor
extends RefCounted
## Static utility for executing evolution mutations on DigimonState.
## Shared by evolution_screen and jogress_select_screen.


## Execute a standard, armor, spirit, or x_antibody evolution.
## Returns { "success": bool, "error": String }.
static func execute_evolution(
	digimon: DigimonState,
	link: EvolutionLinkData,
	inventory: InventoryState,
) -> Dictionary:
	var new_data: DigimonData = Atlas.digimon.get(link.to_key) as DigimonData
	if new_data == null:
		return {"success": false, "error": "Evolution target not found"}

	var old_key: StringName = digimon.key
	var old_data: DigimonData = Atlas.digimon.get(old_key) as DigimonData

	# Mutate species
	digimon.key = link.to_key

	# Scale HP/energy proportionally
	_scale_hp_energy(digimon, old_data, new_data)

	# Learn innate techniques from new form
	_learn_innate_techniques(digimon, new_data)

	# Determine item key for item-holding evolutions (armor/spirit)
	var item_key: StringName = _get_item_key_from_requirements(link)

	# Consume items from inventory and set held item
	match link.evolution_type:
		Registry.EvolutionType.ARMOR, Registry.EvolutionType.SPIRIT:
			if item_key != &"":
				_remove_inventory_item(inventory, item_key, 1)
				digimon.evolution_item_key = item_key

	# Build and append history entry
	var entry: Dictionary = _build_history_entry(
		old_key, link.to_key, link.evolution_type, item_key, [],
	)
	digimon.evolution_history.append(entry)

	return {"success": true, "error": ""}


## Execute a jogress (DNA) evolution, consuming partner Digimon.
## selected_partners: Dictionary mapping partner_key → candidate dict.
## Returns { "success": bool, "error": String }.
static func execute_jogress(
	digimon: DigimonState,
	link: EvolutionLinkData,
	selected_partners: Dictionary,
	inventory: InventoryState,
	party: PartyState,
	storage: StorageState,
) -> Dictionary:
	var new_data: DigimonData = Atlas.digimon.get(link.to_key) as DigimonData
	if new_data == null:
		return {"success": false, "error": "Evolution target not found"}

	var old_key: StringName = digimon.key
	var old_data: DigimonData = Atlas.digimon.get(old_key) as DigimonData

	# Store partner snapshots
	var partner_snapshots: Array[Dictionary] = []
	for partner_key: StringName in link.jogress_partner_keys:
		var candidate: Dictionary = selected_partners.get(partner_key, {})
		var partner: DigimonState = candidate.get("digimon") as DigimonState
		if partner != null:
			partner_snapshots.append(partner.to_dict())

	# Consume partners — collect party removals then execute
	var party_removals: Array[int] = []
	for partner_key: StringName in link.jogress_partner_keys:
		var candidate: Dictionary = selected_partners.get(partner_key, {})
		var source: String = candidate.get("source", "") as String
		if source == "party":
			party_removals.append(candidate.get("party_index", -1) as int)
		elif source == "storage":
			var box: int = candidate.get("box", -1) as int
			var slot: int = candidate.get("slot", -1) as int
			storage.remove_digimon(box, slot)

	# Remove party members in descending index order
	party_removals.sort()
	party_removals.reverse()
	for idx: int in party_removals:
		if idx >= 0 and idx < party.members.size():
			party.members.remove_at(idx)

	# Mutate species
	digimon.key = link.to_key
	_scale_hp_energy(digimon, old_data, new_data)
	_learn_innate_techniques(digimon, new_data)

	# Build and append history entry
	var entry: Dictionary = _build_history_entry(
		old_key, link.to_key, link.evolution_type, &"", partner_snapshots,
	)
	digimon.evolution_history.append(entry)

	return {"success": true, "error": ""}


## Execute a slide or mode change evolution.
## Replaces the last history entry (lateral evo within same tier).
## Returns { "success": bool, "error": String }.
static func execute_slide_or_mode_change(
	digimon: DigimonState,
	link: EvolutionLinkData,
	inventory: InventoryState,
) -> Dictionary:
	var new_data: DigimonData = Atlas.digimon.get(link.to_key) as DigimonData
	if new_data == null:
		return {"success": false, "error": "Evolution target not found"}

	var old_key: StringName = digimon.key
	var old_data: DigimonData = Atlas.digimon.get(old_key) as DigimonData

	# Return old held item to inventory
	if digimon.evolution_item_key != &"":
		_add_inventory_item(inventory, digimon.evolution_item_key, 1)
		digimon.evolution_item_key = &""

	# Take new item from inventory if required
	var new_item_key: StringName = _get_item_key_from_requirements(link)
	if new_item_key != &"":
		_remove_inventory_item(inventory, new_item_key, 1)
		digimon.evolution_item_key = new_item_key

	# Mutate species
	digimon.key = link.to_key
	_scale_hp_energy(digimon, old_data, new_data)
	_learn_innate_techniques(digimon, new_data)

	# Replace last history entry or append if empty
	var entry: Dictionary = _build_history_entry(
		&"", link.to_key, link.evolution_type, new_item_key, [],
	)
	if digimon.evolution_history.is_empty():
		entry["from_key"] = old_key
		digimon.evolution_history.append(entry)
	else:
		# Keep the original from_key (previous tier), update to_key/type/item
		var last: Dictionary = digimon.evolution_history.back()
		entry["from_key"] = last.get("from_key", old_key)
		digimon.evolution_history[digimon.evolution_history.size() - 1] = entry

	return {"success": true, "error": ""}


## Execute de-digivolution — revert to previous form.
## Returns { "success": bool, "error": String, "restored_partners": Array }.
static func execute_de_digivolution(
	digimon: DigimonState,
	inventory: InventoryState,
	party: PartyState,
	storage: StorageState,
) -> Dictionary:
	if digimon.evolution_history.is_empty():
		return {
			"success": false,
			"error": "No evolution history to revert",
			"restored_partners": [],
		}

	# Pop last history entry
	var entry: Dictionary = digimon.evolution_history.pop_back()

	# Return held item to inventory
	if digimon.evolution_item_key != &"":
		_add_inventory_item(inventory, digimon.evolution_item_key, 1)
		digimon.evolution_item_key = &""

	# Revert species
	var old_key: StringName = digimon.key
	var from_key: StringName = StringName(entry.get("from_key", ""))
	if from_key == &"":
		return {
			"success": false,
			"error": "History entry missing from_key",
			"restored_partners": [],
		}

	var old_data: DigimonData = Atlas.digimon.get(old_key) as DigimonData
	digimon.key = from_key
	var new_data: DigimonData = Atlas.digimon.get(from_key) as DigimonData

	if new_data != null:
		_scale_hp_energy(digimon, old_data, new_data)
		_learn_innate_techniques(digimon, new_data)

	# Update evolution_item_key from the now-current last history entry
	if not digimon.evolution_history.is_empty():
		var current_last: Dictionary = digimon.evolution_history.back()
		digimon.evolution_item_key = StringName(
			current_last.get("evolution_item_key", ""),
		)
	else:
		digimon.evolution_item_key = &""

	# Restore jogress partners
	var restored_partners: Array[DigimonState] = []
	var partner_dicts: Array = entry.get("jogress_partners", [])
	for partner_dict: Variant in partner_dicts:
		if partner_dict is not Dictionary:
			continue
		var partner: DigimonState = DigimonState.from_dict(
			partner_dict as Dictionary,
		)
		restored_partners.append(partner)
		# Add to party, or storage if party full
		var balance: GameBalance = load(
			"res://data/config/game_balance.tres",
		) as GameBalance
		var max_party: int = balance.max_party_size if balance else 6
		if party.members.size() < max_party:
			party.members.append(partner)
		else:
			var slot_info: Dictionary = storage.find_first_empty_slot()
			if not slot_info.is_empty():
				storage.set_digimon(
					slot_info["box"], slot_info["slot"], partner,
				)

	return {
		"success": true,
		"error": "",
		"restored_partners": restored_partners,
	}


# --- Internal helpers ---


## Scale current HP/energy proportionally based on old vs new max stats.
static func _scale_hp_energy(
	digimon: DigimonState, old_data: DigimonData, new_data: DigimonData,
) -> void:
	var old_stats: Dictionary = (
		StatCalculator.calculate_all_stats(old_data, digimon)
		if old_data else {}
	)
	# Temporarily set key to new for stat calculation (already set by caller)
	var new_stats: Dictionary = StatCalculator.calculate_all_stats(
		new_data, digimon,
	)

	var old_max_hp: int = old_stats.get(&"hp", 1) as int
	var old_max_energy: int = old_stats.get(&"energy", 1) as int
	var new_max_hp: int = new_stats.get(&"hp", 1) as int
	var new_max_energy: int = new_stats.get(&"energy", 1) as int

	if old_max_hp > 0:
		digimon.current_hp = maxi(
			floori(
				float(digimon.current_hp)
				/ float(old_max_hp)
				* float(new_max_hp)
			),
			1,
		)
	else:
		digimon.current_hp = new_max_hp

	if old_max_energy > 0:
		digimon.current_energy = maxi(
			floori(
				float(digimon.current_energy)
				/ float(old_max_energy)
				* float(new_max_energy)
			),
			1,
		)
	else:
		digimon.current_energy = new_max_energy


## Add innate techniques from a new form that aren't already known.
static func _learn_innate_techniques(
	digimon: DigimonState, new_data: DigimonData,
) -> void:
	var new_innate: Array[StringName] = new_data.get_innate_technique_keys()
	for tech_key: StringName in new_innate:
		if tech_key not in digimon.known_technique_keys:
			digimon.known_technique_keys.append(tech_key)


## Extract the spirit/digimental/mode_change item key from requirements.
## Uses EvolutionChecker.find_evolution_item_key to resolve display names
## to actual inventory keys.
static func _get_item_key_from_requirements(
	link: EvolutionLinkData,
) -> StringName:
	for req: Dictionary in link.requirements:
		var req_type: String = req.get("type", "")
		match req_type:
			"spirit":
				var name: String = req.get("item", req.get("spirit", ""))
				return EvolutionChecker.find_evolution_item_key(
					"spirit", name,
				)
			"digimental":
				var name: String = req.get(
					"item", req.get("digimental", ""),
				)
				return EvolutionChecker.find_evolution_item_key(
					"digimental", name,
				)
			"mode_change":
				var name: String = req.get("item", "")
				if name == "":
					return &""
				return EvolutionChecker.find_evolution_item_key(
					"mode_change", name,
				)
	return &""


## Build a history entry dictionary.
static func _build_history_entry(
	from_key: StringName,
	to_key: StringName,
	evo_type: Registry.EvolutionType,
	item_key: StringName,
	jogress_partners: Array,
) -> Dictionary:
	var entry: Dictionary = {
		"from_key": from_key,
		"to_key": to_key,
		"evolution_type": evo_type,
		"evolution_item_key": item_key,
	}
	if not jogress_partners.is_empty():
		entry["jogress_partners"] = jogress_partners
	return entry


## Remove an item from inventory.
static func _remove_inventory_item(
	inventory: InventoryState, item_key: StringName, amount: int,
) -> void:
	if item_key == &"":
		return
	var current: int = inventory.items.get(item_key, 0)
	var new_qty: int = current - amount
	if new_qty <= 0:
		inventory.items.erase(item_key)
	else:
		inventory.items[item_key] = new_qty


## Add an item to inventory.
static func _add_inventory_item(
	inventory: InventoryState, item_key: StringName, amount: int,
) -> void:
	if item_key == &"":
		return
	var current: int = inventory.items.get(item_key, 0)
	inventory.items[item_key] = current + amount
