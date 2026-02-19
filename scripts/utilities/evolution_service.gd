class_name EvolutionService
extends RefCounted
## Static utility consolidating evolution discovery and warp logic.
## Provides a single entry point for finding available evolutions,
## warp evolution chains, and de-evolution eligibility.


## Find all evolution links available from the given Digimon.
## Filters out incomplete data entries (no requirements + no partners for
## non-slide/mode_change types).
static func find_available_evolutions(
	digimon: DigimonState,
) -> Array[EvolutionLinkData]:
	var result: Array[EvolutionLinkData] = []
	for evo_key: StringName in Atlas.evolutions:
		var link: EvolutionLinkData = Atlas.evolutions[evo_key] as EvolutionLinkData
		if link == null or link.from_key != digimon.key:
			continue
		# Hide non-slide/mode-change links that have no requirements and no
		# jogress partners — these are incomplete data entries.
		if link.requirements.is_empty() and link.jogress_partner_keys.is_empty():
			if link.evolution_type != Registry.EvolutionType.SLIDE \
					and link.evolution_type != Registry.EvolutionType.MODE_CHANGE:
				continue
		result.append(link)
	return result


## Check if a Digimon can de-digivolve (has evolution history).
static func can_de_digivolve(digimon: DigimonState) -> bool:
	return digimon.evolution_history.size() > 0


## Check if any evolution is currently possible for this Digimon.
static func can_evolve_any(
	digimon: DigimonState,
	inventory: InventoryState,
	party: PartyState = null,
	storage: StorageState = null,
) -> bool:
	var links: Array[EvolutionLinkData] = find_available_evolutions(digimon)
	for link: EvolutionLinkData in links:
		if EvolutionChecker.can_evolve(link, digimon, inventory, party, storage):
			return true
	return false


## Find all reachable warp evolution endpoints via STANDARD-type links.
## Returns only leaf/terminal forms (highest reachable per path).
## Each result: { "chain": Array[EvolutionLinkData], "final_key": StringName }
static func find_warp_evolutions(
	digimon: DigimonState,
	inventory: InventoryState,
	party: PartyState = null,
	storage: StorageState = null,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var start_links: Array[EvolutionLinkData] = _get_standard_links(digimon.key)

	for link: EvolutionLinkData in start_links:
		if not EvolutionChecker.can_evolve(link, digimon, inventory, party, storage):
			continue
		# Build a temporary state to check further evolutions
		var chain: Array[EvolutionLinkData] = [link]
		_explore_warp_chain(
			link.to_key, digimon, inventory, party, storage, chain, results,
		)

	return results


## Get all STANDARD-type evolution links from a given Digimon key.
static func _get_standard_links(
	from_key: StringName,
) -> Array[EvolutionLinkData]:
	var links: Array[EvolutionLinkData] = []
	for evo_key: StringName in Atlas.evolutions:
		var link: EvolutionLinkData = Atlas.evolutions[evo_key] as EvolutionLinkData
		if link == null:
			continue
		if link.from_key == from_key \
				and link.evolution_type == Registry.EvolutionType.STANDARD:
			# Filter incomplete data
			if link.requirements.is_empty() and link.jogress_partner_keys.is_empty():
				continue
			links.append(link)
	return links


## Recursively explore warp chains, collecting terminal forms.
static func _explore_warp_chain(
	current_key: StringName,
	original_digimon: DigimonState,
	inventory: InventoryState,
	party: PartyState,
	storage: StorageState,
	chain: Array[EvolutionLinkData],
	results: Array[Dictionary],
) -> void:
	var next_links: Array[EvolutionLinkData] = _get_standard_links(current_key)
	var found_next: bool = false

	for link: EvolutionLinkData in next_links:
		# Check requirements using the original Digimon's stats/level
		if not EvolutionChecker.can_evolve(
			link, original_digimon, inventory, party, storage,
		):
			continue
		found_next = true
		var extended_chain: Array[EvolutionLinkData] = chain.duplicate()
		extended_chain.append(link)
		_explore_warp_chain(
			link.to_key, original_digimon, inventory, party, storage,
			extended_chain, results,
		)

	# If no further links are reachable, this is a terminal form
	if not found_next and chain.size() > 1:
		results.append({
			"chain": chain,
			"final_key": current_key,
		})
