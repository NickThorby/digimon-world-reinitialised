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
				var spirit: String = req.get("spirit", "")
				var item_key: StringName = StringName(spirit)
				var has_item: bool = inventory.items.get(item_key, 0) > 0
				results.append({
					"type": "spirit",
					"description": spirit,
					"met": has_item,
				})
			"digimental":
				var digimental: String = req.get("digimental", "")
				var item_key: StringName = StringName(digimental)
				var has_item: bool = inventory.items.get(item_key, 0) > 0
				results.append({
					"type": "digimental",
					"description": digimental,
					"met": has_item,
				})
			"x_antibody":
				var needed: int = int(req.get("amount", 1))
				var x_key: StringName = &"x_antibody"
				var owned: int = inventory.items.get(x_key, 0)
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
static func can_evolve(
	link: EvolutionLinkData,
	digimon: DigimonState,
	inventory: InventoryState,
) -> bool:
	var results: Array[Dictionary] = check_requirements(link, digimon, inventory)
	if results.is_empty():
		return false
	for result: Dictionary in results:
		if not result.get("met", false):
			return false
	return true


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
	var iv: int = digimon.ivs.get(stat_key, 0)
	var tv: int = digimon.tvs.get(stat_key, 0)
	return StatCalculator.calculate_stat(base, iv, tv, digimon.level)
