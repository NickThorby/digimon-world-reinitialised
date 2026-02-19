class_name BattleEvolutionReverter
extends RefCounted
## Reverts all battle evolutions after the post-battle XP screen.
## Restores species, evolution history, and jogress partners.


## Revert all Digimon that evolved during battle to their pre-battle state.
## Preserves current HP/energy as a percentage of current max.
static func revert_battle_evolutions(
	evolutions: Array[Dictionary],
	party: PartyState,
	storage: StorageState,
	inventory: InventoryState,
) -> void:
	var balance: GameBalance = load(
		"res://data/config/game_balance.tres",
	) as GameBalance
	var max_party: int = balance.max_party_size if balance else 6

	for entry: Dictionary in evolutions:
		var source: DigimonState = entry.get("source_state") as DigimonState
		var snapshot: Dictionary = entry.get("snapshot", {})
		if source == null or snapshot.is_empty():
			continue

		# Save current HP/energy as percentages before reverting
		var current_data: DigimonData = Atlas.digimon.get(source.key) as DigimonData
		var current_stats: Dictionary = {}
		if current_data != null:
			current_stats = StatCalculator.calculate_all_stats(current_data, source)
		var current_max_hp: int = current_stats.get(&"hp", 1) as int
		var current_max_energy: int = current_stats.get(&"energy", 1) as int
		var hp_pct: float = float(source.current_hp) / float(maxi(current_max_hp, 1))
		var energy_pct: float = float(source.current_energy) / float(
			maxi(current_max_energy, 1),
		)

		# Determine which history entries were added during battle
		var snapshot_history: Array = snapshot.get("evolution_history", [])
		var current_history: Array = source.evolution_history

		# Restore species and evolution state from snapshot
		source.key = StringName(snapshot.get("key", ""))
		source.evolution_history = []
		for hist_entry: Variant in snapshot_history:
			if hist_entry is Dictionary:
				source.evolution_history.append(hist_entry as Dictionary)
		source.evolution_item_key = StringName(
			snapshot.get("evolution_item_key", ""),
		)

		# Recalculate stats for restored species
		var restored_data: DigimonData = Atlas.digimon.get(source.key) as DigimonData
		if restored_data != null:
			var restored_stats: Dictionary = StatCalculator.calculate_all_stats(
				restored_data, source,
			)
			var new_max_hp: int = restored_stats.get(&"hp", 1) as int
			var new_max_energy: int = restored_stats.get(&"energy", 1) as int
			source.current_hp = maxi(floori(hp_pct * float(new_max_hp)), 1)
			source.current_energy = maxi(
				floori(energy_pct * float(new_max_energy)), 1,
			)

		# Find new history entries that have jogress partners to restore
		var new_entries: Array[Dictionary] = _find_new_history_entries(
			snapshot_history, current_history,
		)
		for new_entry: Dictionary in new_entries:
			var partners: Array = new_entry.get("jogress_partners", [])
			for partner_dict: Variant in partners:
				if partner_dict is not Dictionary:
					continue
				var partner: DigimonState = DigimonState.from_dict(
					partner_dict as Dictionary,
				)
				# Skip if partner already exists (battle jogress doesn't
				# remove from game state party, only from battle reserves)
				if _partner_already_exists(partner, party, storage):
					continue
				if party.members.size() < max_party:
					party.members.append(partner)
				else:
					var slot_info: Dictionary = storage.find_first_empty_slot()
					if not slot_info.is_empty():
						storage.set_digimon(
							slot_info["box"], slot_info["slot"], partner,
						)

			# Return consumed evolution items to inventory
			var item_key: StringName = StringName(
				new_entry.get("evolution_item_key", ""),
			)
			if item_key != &"":
				var current_qty: int = inventory.items.get(item_key, 0)
				inventory.items[item_key] = current_qty + 1

		# Re-learn innate techniques for restored form
		if restored_data != null:
			var innate: Array[StringName] = restored_data.get_innate_technique_keys()
			for tech_key: StringName in innate:
				if tech_key not in source.known_technique_keys:
					source.known_technique_keys.append(tech_key)


## Check if a partner with the same identity already exists in party or storage.
static func _partner_already_exists(
	partner: DigimonState,
	party: PartyState,
	storage: StorageState,
) -> bool:
	for member: DigimonState in party.members:
		if member.display_id == partner.display_id \
				and member.secret_id == partner.secret_id:
			return true
	for box: Dictionary in storage.boxes:
		var slots: Array = box.get("slots", [])
		for slot: Variant in slots:
			if slot is DigimonState:
				var stored: DigimonState = slot as DigimonState
				if stored.display_id == partner.display_id \
						and stored.secret_id == partner.secret_id:
					return true
	return false


## Find history entries in current that don't exist in snapshot (added during battle).
static func _find_new_history_entries(
	snapshot_history: Array,
	current_history: Array,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var snapshot_size: int = snapshot_history.size()
	for i: int in range(snapshot_size, current_history.size()):
		if current_history[i] is Dictionary:
			result.append(current_history[i] as Dictionary)
	return result
