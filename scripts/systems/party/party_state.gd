class_name PartyState
extends RefCounted
## Holds the player's active party of Digimon.

## Active party members. Max size governed by GameBalance.max_party_size.
var members: Array[DigimonState] = []


func to_dict() -> Dictionary:
	var member_dicts: Array[Dictionary] = []
	for member: DigimonState in members:
		member_dicts.append(member.to_dict())
	return {"members": member_dicts}


static func from_dict(data: Dictionary) -> PartyState:
	var state := PartyState.new()
	for member_data: Dictionary in data.get("members", []):
		state.members.append(DigimonState.from_dict(member_data))
	return state
