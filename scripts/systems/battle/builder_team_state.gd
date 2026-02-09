class_name BuilderTeamState
extends RefCounted
## A named, saveable team for reuse across builder sessions.


## Display name for this team.
var name: String = ""

## Team members.
var members: Array[DigimonState] = []


func to_dict() -> Dictionary:
	var member_dicts: Array[Dictionary] = []
	for member: DigimonState in members:
		member_dicts.append(member.to_dict())
	return {
		"name": name,
		"members": member_dicts,
	}


static func from_dict(data: Dictionary) -> BuilderTeamState:
	var state := BuilderTeamState.new()
	state.name = data.get("name", "")
	for member_data: Dictionary in data.get("members", []):
		state.members.append(DigimonState.from_dict(member_data))
	return state
