class_name GameState
extends RefCounted
## Root save state containing all persistent game data.

var tamer_name: String = ""
var tamer_id: StringName = &""
var play_time: int = 0

var party: PartyState = PartyState.new()
var storage: StorageState = StorageState.new()
var inventory: InventoryState = InventoryState.new()
var story_flags: Dictionary = {}
## Digimon key -> scan progress (0.0-1.0).
var scan_log: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"tamer_name": tamer_name,
		"tamer_id": tamer_id,
		"play_time": play_time,
		"party": party.to_dict(),
		"storage": storage.to_dict(),
		"inventory": inventory.to_dict(),
		"story_flags": story_flags.duplicate(),
		"scan_log": scan_log.duplicate(),
	}


static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.tamer_name = data.get("tamer_name", "")
	state.tamer_id = StringName(data.get("tamer_id", ""))
	state.play_time = data.get("play_time", 0)
	state.party = PartyState.from_dict(data.get("party", {}))
	state.storage = StorageState.from_dict(data.get("storage", {}))
	state.inventory = InventoryState.from_dict(data.get("inventory", {}))
	state.story_flags = data.get("story_flags", {})
	state.scan_log = data.get("scan_log", {})
	return state
