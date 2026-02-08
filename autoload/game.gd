extends Node
## Game lifecycle manager — holds runtime state and orchestrates game flow.


const SCENE_MAIN_MENU := "res://scenes/main/main.tscn"

## The current game state (null if no game active).
var state: GameState = null


## Start a new game with fresh state.
func new_game() -> void:
	state = GameState.new()
	# TODO: Transition to overworld or intro scene
	print("Game: New game started")


## Load a game from a save slot.
## Returns true on success.
func load_game(slot_name: String) -> bool:
	var loaded_state := SaveManager.load_game(slot_name)
	if loaded_state == null:
		push_error("Game: Failed to load save: %s" % slot_name)
		return false

	state = loaded_state
	print("Game: Loaded save from slot: %s" % slot_name)
	return true


## Save the current game to a slot.
## Returns true on success.
func save_game(slot_name: String) -> bool:
	if state == null:
		push_error("Game: No active game state to save")
		return false

	return SaveManager.save_game(state, slot_name)


## Return to main menu (clears current state).
func return_to_menu() -> void:
	state = null
	SceneManager.change_scene(SCENE_MAIN_MENU)
