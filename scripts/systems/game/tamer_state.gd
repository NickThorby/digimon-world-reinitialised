class_name TamerState
extends RefCounted
## Mutable runtime state for an NPC tamer, built from TamerData.

var key: StringName = &""
var name: String = ""
var party: Array[DigimonState] = []
var inventory: InventoryState = InventoryState.new()
var ai_type: StringName = &"default"


## Create a TamerState from a TamerData template.
## Uses DigimonFactory to generate each party member, then applies overrides.
static func from_tamer_data(data: TamerData) -> TamerState:
	var state := TamerState.new()
	state.key = data.key
	state.name = data.name
	state.ai_type = data.ai_type

	# Build party from config
	for config: Dictionary in data.party_config:
		var digimon_key: StringName = StringName(config.get("digimon_key", ""))
		var level: int = config.get("level", 1)
		var digimon: DigimonState = DigimonFactory.create_digimon(digimon_key, level)
		if digimon == null:
			continue

		# Apply overrides from config
		var ability_slot: int = config.get("ability_slot", 0)
		if ability_slot > 0:
			digimon.active_ability_slot = ability_slot

		var tech_keys: Array = config.get("technique_keys", [])
		if not tech_keys.is_empty():
			digimon.equipped_technique_keys.clear()
			for tech_key: Variant in tech_keys:
				var key_str: StringName = StringName(str(tech_key))
				digimon.equipped_technique_keys.append(key_str)
				if key_str not in digimon.known_technique_keys:
					digimon.known_technique_keys.append(key_str)

		var gear_key: String = config.get("gear_key", "")
		if gear_key != "":
			digimon.equipped_gear_key = StringName(gear_key)

		var consumable_key: String = config.get("consumable_key", "")
		if consumable_key != "":
			digimon.equipped_consumable_key = StringName(consumable_key)

		state.party.append(digimon)

	# Build inventory from item keys
	for item_key: StringName in data.item_keys:
		state.inventory.items[item_key] = state.inventory.items.get(item_key, 0) + 1

	return state


## Build a side_configs Dictionary suitable for BattleConfig construction.
## Returns { "party": Array[DigimonState], "ai_type": StringName }.
func to_battle_side_config() -> Dictionary:
	return {
		"party": party,
		"ai_type": ai_type,
	}
