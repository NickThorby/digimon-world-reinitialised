class_name EvolutionChecker
extends RefCounted
## Pure static utility for checking evolution requirements.

## Dex stat abbreviation -> base stat field name on DigimonData.
const STAT_BASE_MAP: Dictionary = {
	"hp": &"base_hp",
	"atk": &"base_attack",
	"def": &"base_defence",
	"spa": &"base_special_attack",
	"spd": &"base_special_defence",
	"spe": &"base_speed",
	"energy": &"base_energy",
}

## Cache: "effect:name" -> item_key for evolution item lookups.
static var _evo_item_cache: Dictionary = {}


## Clear the evolution item lookup cache. Called by test teardown.
static func clear_cache() -> void:
	_evo_item_cache.clear()


## Dex stat abbreviation -> stat key for IVs/TVs lookup.
const STAT_KEY_MAP: Dictionary = {
	"hp": &"hp",
	"atk": &"attack",
	"def": &"defence",
	"spa": &"special_attack",
	"spd": &"special_defence",
	"spe": &"speed",
	"energy": &"energy",
}


## Check all requirements for an evolution link.
## Returns Array of { "type": String, "description": String, "met": bool }.
static func check_requirements(
	link: EvolutionLinkData,
	digimon: DigimonState,
	inventory: InventoryState,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var data: DigimonData = Atlas.digimon.get(digimon.key) as DigimonData

	for req: Dictionary in link.requirements:
		var req_type: String = req.get("type", "")
		match req_type:
			"level":
				var needed: int = int(req.get("level", 1))
				results.append({
					"type": "level",
					"description": "Level %d" % needed,
					"met": digimon.level >= needed,
				})
			"stat":
				results.append(_check_stat_requirement(req, digimon, data))
			"stat_highest_of":
				results.append(_check_stat_highest_of(req, digimon, data))
			"spirit":
				var spirit: String = req.get("item", req.get("spirit", ""))
				var item_key: StringName = find_evolution_item_key(
					"spirit", spirit,
				)
				var has_item: bool = (
					item_key != &""
					and inventory.items.get(item_key, 0) > 0
				)
				results.append({
					"type": "spirit",
					"description": spirit,
					"met": has_item,
				})
			"digimental":
				var digimental: String = req.get(
					"item", req.get("digimental", ""),
				)
				var item_key: StringName = find_evolution_item_key(
					"digimental", digimental,
				)
				var has_item: bool = (
					item_key != &""
					and inventory.items.get(item_key, 0) > 0
				)
				results.append({
					"type": "digimental",
					"description": digimental,
					"met": has_item,
				})
			"mode_change":
				var item_name: String = req.get("item", "")
				var item_key: StringName = find_evolution_item_key(
					"mode_change", item_name,
				)
				var has_item: bool = (
					item_name == ""
					or (item_key != &""
						and inventory.items.get(item_key, 0) > 0)
				)
				results.append({
					"type": "mode_change",
					"description": (
						item_name if item_name != "" else "Mode Change"
					),
					"met": has_item,
				})
			"x_antibody":
				var needed: int = int(req.get("amount", 1))
				var owned: int = digimon.x_antibody
				results.append({
					"type": "x_antibody",
					"description": "X-Antibody x%d" % needed,
					"met": owned >= needed,
				})
			"description":
				# Description requirements are flavour text — never auto-met.
				results.append({
					"type": "description",
					"description": req.get("text", ""),
					"met": false,
				})

	return results


## Convenience: returns true if all requirements are met.
## Pass party and storage to enable jogress partner validation.
static func can_evolve(
	link: EvolutionLinkData,
	digimon: DigimonState,
	inventory: InventoryState,
	party: PartyState = null,
	storage: StorageState = null,
) -> bool:
	var results: Array[Dictionary] = check_requirements(link, digimon, inventory)
	if results.is_empty() and link.jogress_partner_keys.is_empty():
		return false
	for result: Dictionary in results:
		if not result.get("met", false):
			return false
	# Jogress partner check
	if not link.jogress_partner_keys.is_empty():
		if party == null or storage == null:
			return false
		var partner_results: Array[Dictionary] = check_jogress_partners(
			link, digimon, party, storage,
		)
		for pr: Dictionary in partner_results:
			if not pr.get("met", false):
				return false
	return true


## Check jogress partner availability for an evolution link.
## Returns requirement-style dicts: { "type", "description", "met" }.
static func check_jogress_partners(
	link: EvolutionLinkData,
	digimon: DigimonState,
	party: PartyState,
	storage: StorageState,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var level_req: int = _get_level_requirement(link)

	for partner_key: StringName in link.jogress_partner_keys:
		var partner_data: DigimonData = Atlas.digimon.get(partner_key) as DigimonData
		var display_name: String = partner_data.display_name if partner_data else str(partner_key)
		var candidates: Array[Dictionary] = _find_candidates_for_key(
			partner_key, digimon, party, storage, level_req,
		)
		var description: String = "Partner: %s" % display_name
		if level_req > 0:
			description = "Partner: %s (Lv. %d+)" % [display_name, level_req]
		results.append({
			"type": "jogress_partner",
			"description": description,
			"met": not candidates.is_empty(),
		})

	return results


## Find all eligible jogress partner candidates grouped by partner key.
## Returns Dictionary mapping partner_key → Array[Dictionary] of candidate locations.
## Each candidate: { "source", "party_index", "box", "slot", "digimon" }.
static func find_jogress_candidates(
	link: EvolutionLinkData,
	digimon: DigimonState,
	party: PartyState,
	storage: StorageState,
) -> Dictionary:
	var result: Dictionary = {}
	var level_req: int = _get_level_requirement(link)
	for partner_key: StringName in link.jogress_partner_keys:
		result[partner_key] = _find_candidates_for_key(
			partner_key, digimon, party, storage, level_req,
		)
	return result


## Extract the level requirement from a link's requirements array, or 0 if none.
static func _get_level_requirement(link: EvolutionLinkData) -> int:
	for req: Dictionary in link.requirements:
		if req.get("type", "") == "level":
			return int(req.get("level", 0))
	return 0


## Scan party and storage for Digimon matching partner_key, excluding main Digimon.
static func _find_candidates_for_key(
	partner_key: StringName,
	main_digimon: DigimonState,
	party: PartyState,
	storage: StorageState,
	level_req: int,
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	# Scan party
	for i: int in party.members.size():
		var member: DigimonState = party.members[i]
		if member == null:
			continue
		if member.unique_id == main_digimon.unique_id:
			continue
		if member.key != partner_key:
			continue
		if level_req > 0 and member.level < level_req:
			continue
		candidates.append({
			"source": "party",
			"party_index": i,
			"box": -1,
			"slot": -1,
			"digimon": member,
		})

	# Scan storage
	for box_idx: int in storage.boxes.size():
		var slots: Array = storage.boxes[box_idx]["slots"]
		for slot_idx: int in slots.size():
			var stored: DigimonState = slots[slot_idx] as DigimonState
			if stored == null:
				continue
			if stored.unique_id == main_digimon.unique_id:
				continue
			if stored.key != partner_key:
				continue
			if level_req > 0 and stored.level < level_req:
				continue
			candidates.append({
				"source": "storage",
				"party_index": -1,
				"box": box_idx,
				"slot": slot_idx,
				"digimon": stored,
			})

	return candidates


## Check a single stat requirement (e.g. { "type": "stat", "stat": "atk", "operator": ">=", "value": 100 }).
static func _check_stat_requirement(
	req: Dictionary, digimon: DigimonState, data: DigimonData,
) -> Dictionary:
	var stat_abbr: String = req.get("stat", "")
	var operator: String = req.get("operator", ">=")
	var needed: int = int(req.get("value", 0))
	var actual: int = _get_calculated_stat(stat_abbr, digimon, data)

	var met: bool = false
	match operator:
		">": met = actual > needed
		">=": met = actual >= needed
		"=": met = actual == needed
		"<": met = actual < needed
		"<=": met = actual <= needed

	var stat_label: String = STAT_KEY_MAP.get(stat_abbr, stat_abbr)
	return {
		"type": "stat",
		"description": "%s %s %d" % [stat_label, operator, needed],
		"met": met,
	}


## Check a stat_highest_of requirement (e.g. { "stat": "atk", "among": ["def", "spa"] }).
static func _check_stat_highest_of(
	req: Dictionary, digimon: DigimonState, data: DigimonData,
) -> Dictionary:
	var stat_abbr: String = req.get("stat", "")
	var among: Array = req.get("among", [])
	var target_value: int = _get_calculated_stat(stat_abbr, digimon, data)

	var is_highest: bool = true
	for other_abbr: Variant in among:
		var other_value: int = _get_calculated_stat(str(other_abbr), digimon, data)
		if other_value > target_value:
			is_highest = false
			break

	var stat_label: String = STAT_KEY_MAP.get(stat_abbr, stat_abbr)
	var among_labels: Array[String] = []
	for a: Variant in among:
		among_labels.append(STAT_KEY_MAP.get(str(a), str(a)))

	return {
		"type": "stat_highest_of",
		"description": "%s highest of %s" % [stat_label, ", ".join(among_labels)],
		"met": is_highest,
	}


## Calculate the actual stat value for a dex stat abbreviation.
static func _get_calculated_stat(
	stat_abbr: String, digimon: DigimonState, data: DigimonData,
) -> int:
	if data == null:
		return 0
	var base_field: StringName = STAT_BASE_MAP.get(stat_abbr, &"")
	var stat_key: StringName = STAT_KEY_MAP.get(stat_abbr, &"")
	if base_field == &"" or stat_key == &"":
		return 0
	var base: int = data.get(base_field) as int
	var iv: int = digimon.get_final_iv(stat_key)
	var tv: int = digimon.tvs.get(stat_key, 0)
	return StatCalculator.calculate_stat(base, iv, tv, digimon.level)


## Find the item key for an evolution requirement by matching outOfBattleEffect bricks.
## Evolution link requirements store display names (e.g. "Digimental of Courage") but
## inventory items are keyed by game_id (e.g. "digimental_of_courage"). This helper
## searches Atlas.items for an item whose outOfBattleEffect brick matches.
## Results are cached in _evo_item_cache.
static func find_evolution_item_key(effect: String, name: String) -> StringName:
	if name == "":
		return &""
	var cache_key: String = "%s:%s" % [effect, name]
	if _evo_item_cache.has(cache_key):
		return _evo_item_cache[cache_key] as StringName
	# Also try the name directly as a key (in case requirement already uses game_id).
	if Atlas.items.has(StringName(name)):
		_evo_item_cache[cache_key] = StringName(name)
		return StringName(name)
	# Search Atlas items for matching outOfBattleEffect brick.
	for key: StringName in Atlas.items:
		var item_data: Resource = Atlas.items[key]
		if not item_data is ItemData:
			continue
		for brick: Dictionary in (item_data as ItemData).bricks:
			if (brick.get("brick") == "outOfBattleEffect"
				and brick.get("effect") == effect
				and brick.get("value") == name):
				_evo_item_cache[cache_key] = key
				return key
	_evo_item_cache[cache_key] = &""
	return &""
