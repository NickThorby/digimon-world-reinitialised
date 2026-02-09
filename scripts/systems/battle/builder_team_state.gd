class_name BuilderTeamState
extends RefCounted
## A named, saveable team for reuse across builder sessions.


## Display name for this team.
var name: String = ""

## Unix timestamp when the team was last saved.
var saved_at: int = 0

## Team members.
var members: Array[DigimonState] = []


func to_dict() -> Dictionary:
	var member_dicts: Array[Dictionary] = []
	for member: DigimonState in members:
		member_dicts.append(member.to_dict())
	return {
		"name": name,
		"saved_at": saved_at,
		"members": member_dicts,
	}


static func from_dict(data: Dictionary) -> BuilderTeamState:
	var state := BuilderTeamState.new()
	state.name = data.get("name", "")
	state.saved_at = data.get("saved_at", 0)
	for member_data: Dictionary in data.get("members", []):
		state.members.append(DigimonState.from_dict(member_data))
	return state
