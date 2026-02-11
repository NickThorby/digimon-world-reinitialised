class_name BattleConfig
extends RefCounted
## Data contract between the battle builder and battle scene.
## Describes the format, sides, parties, and settings for a battle.


enum FormatPreset {
	SINGLES_1V1,
	DOUBLES_2V2,
	DOUBLES_MULTI,
	TRIPLES_3V3,
	FFA_3,
	FFA_4,
	CUSTOM,
}

enum ControllerType {
	PLAYER,
	AI,
}


## Which preset format this battle uses.
var format_preset: FormatPreset = FormatPreset.SINGLES_1V1

## Number of sides in the battle (2-4).
var side_count: int = 2

## Active Digimon slots per side (1-3).
var slots_per_side: int = 1

## Team assignments — sides with the same value are allies.
## Length must equal side_count.
var team_assignments: Array[int] = [0, 1]

## Per-side configuration. Each element is a Dictionary:
##   { "controller": ControllerType, "party": Array[DigimonState], "is_wild": bool,
##     "is_owned": bool }
var side_configs: Array[Dictionary] = []

## Whether XP is awarded after battle.
var xp_enabled: bool = true

## Whether non-participants receive 50% XP (EXP Share).
var exp_share_enabled: bool = false

## Preset field effects applied at battle start.
## { "weather": { "key": StringName, "permanent": bool, "duration": int },
##   "terrain": { "key": StringName, "permanent": bool, "duration": int },
##   "global_effects": [{ "key": StringName, "permanent": bool, "duration": int }] }
var preset_field_effects: Dictionary = {}

## Preset side effects. Each entry targets specific sides.
## [{ "key": StringName, "sides": Array[int], "duration": int, "permanent": bool }]
## sides = [] means ALL sides. duration is ignored when permanent = true.
var preset_side_effects: Array[Dictionary] = []

## Preset hazards. Each entry targets specific sides.
## [{ "key": StringName, "sides": Array[int], "layers": int, "permanent": bool, "extra": {} }]
## sides = [] means ALL sides.
var preset_hazards: Array[Dictionary] = []


## Apply a preset format, setting side_count, slots_per_side, and team_assignments.
func apply_preset(preset: FormatPreset) -> void:
	format_preset = preset
	match preset:
		FormatPreset.SINGLES_1V1:
			side_count = 2
			slots_per_side = 1
			team_assignments = [0, 1]
		FormatPreset.DOUBLES_2V2:
			side_count = 2
			slots_per_side = 2
			team_assignments = [0, 1]
		FormatPreset.DOUBLES_MULTI:
			side_count = 4
			slots_per_side = 1
			team_assignments = [0, 0, 1, 1]
		FormatPreset.TRIPLES_3V3:
			side_count = 2
			slots_per_side = 3
			team_assignments = [0, 1]
		FormatPreset.FFA_3:
			side_count = 3
			slots_per_side = 1
			team_assignments = [0, 1, 2]
		FormatPreset.FFA_4:
			side_count = 4
			slots_per_side = 1
			team_assignments = [0, 1, 2, 3]
		FormatPreset.CUSTOM:
			pass  # User sets manually

	_ensure_side_configs()


## Validate the configuration. Returns an array of error messages (empty = valid).
func validate() -> Array[String]:
	var errors: Array[String] = []

	if side_count < 2 or side_count > 4:
		errors.append("Side count must be between 2 and 4.")

	if slots_per_side < 1 or slots_per_side > 3:
		errors.append("Slots per side must be between 1 and 3.")

	if team_assignments.size() != side_count:
		errors.append("Team assignments length must match side count.")

	if side_configs.size() != side_count:
		errors.append("Side configs length must match side count.")
		return errors

	for i: int in side_configs.size():
		var cfg: Dictionary = side_configs[i]
		var party: Array = cfg.get("party", []) as Array
		if party.size() < slots_per_side:
			errors.append("Side %d needs at least %d Digimon (has %d)." % [
				i, slots_per_side, party.size()
			])

	return errors


## Serialise to dictionary for saving builder configs.
func to_dict() -> Dictionary:
	var configs_data: Array[Dictionary] = []
	for cfg: Dictionary in side_configs:
		var party_data: Array[Dictionary] = []
		for digimon: Variant in cfg.get("party", []):
			if digimon is DigimonState:
				party_data.append((digimon as DigimonState).to_dict())
		var cfg_dict: Dictionary = {
			"controller": cfg.get("controller", ControllerType.PLAYER),
			"party": party_data,
			"is_wild": cfg.get("is_wild", false),
			"is_owned": cfg.get("is_owned", false),
		}
		var bag: Variant = cfg.get("bag")
		if bag is BagState:
			cfg_dict["bag"] = (bag as BagState).to_dict()
		configs_data.append(cfg_dict)

	var result: Dictionary = {
		"format_preset": format_preset,
		"side_count": side_count,
		"slots_per_side": slots_per_side,
		"team_assignments": Array(team_assignments),
		"side_configs": configs_data,
		"xp_enabled": xp_enabled,
		"exp_share_enabled": exp_share_enabled,
	}
	if not preset_field_effects.is_empty():
		result["preset_field_effects"] = preset_field_effects
	if not preset_side_effects.is_empty():
		result["preset_side_effects"] = Array(preset_side_effects)
	if not preset_hazards.is_empty():
		result["preset_hazards"] = Array(preset_hazards)
	return result


## Deserialise from dictionary.
static func from_dict(data: Dictionary) -> BattleConfig:
	var config := BattleConfig.new()
	config.format_preset = data.get("format_preset", FormatPreset.SINGLES_1V1) as FormatPreset
	config.side_count = data.get("side_count", 2)
	config.slots_per_side = data.get("slots_per_side", 1)
	config.xp_enabled = data.get("xp_enabled", true)
	config.exp_share_enabled = data.get("exp_share_enabled", false)

	for ta: Variant in data.get("team_assignments", [0, 1]):
		config.team_assignments.append(int(ta))

	for cfg_data: Dictionary in data.get("side_configs", []):
		var party: Array[DigimonState] = []
		for digimon_data: Dictionary in cfg_data.get("party", []):
			party.append(DigimonState.from_dict(digimon_data))
		var side_cfg: Dictionary = {
			"controller": cfg_data.get("controller", ControllerType.PLAYER) as ControllerType,
			"party": party,
			"is_wild": cfg_data.get("is_wild", false),
			"is_owned": cfg_data.get("is_owned", false),
		}
		var bag_data: Variant = cfg_data.get("bag")
		if bag_data is Dictionary and not (bag_data as Dictionary).is_empty():
			side_cfg["bag"] = BagState.from_dict(bag_data as Dictionary)
		config.side_configs.append(side_cfg)

	config.preset_field_effects = data.get("preset_field_effects", {})
	for se: Dictionary in data.get("preset_side_effects", []):
		config.preset_side_effects.append(se)
	for hz: Dictionary in data.get("preset_hazards", []):
		config.preset_hazards.append(hz)

	return config


## Ensure side_configs has the right number of entries.
func _ensure_side_configs() -> void:
	while side_configs.size() < side_count:
		side_configs.append({
			"controller": ControllerType.PLAYER if side_configs.size() == 0 else ControllerType.AI,
			"party": [] as Array[DigimonState],
			"is_wild": false,
			"is_owned": side_configs.size() == 0,
		})
	while side_configs.size() > side_count:
		side_configs.pop_back()
