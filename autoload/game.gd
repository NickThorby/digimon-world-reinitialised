extends Node
## Game lifecycle manager — holds runtime state and orchestrates game flow.


const SCENE_MAIN_MENU := "res://scenes/main/main.tscn"

## The current game state (null if no game active).
var state: GameState = null

## Battle configuration for the next battle (set by builder, consumed by battle scene).
var battle_config: BattleConfig = null

## Context for digimon picker scene (set by builder before navigating).
var picker_context: Dictionary = {}
## Result from digimon picker (set by picker on confirm, null on cancel).
var picker_result: Variant = null

## Context for restoring battle builder state after a battle.
var builder_context: Dictionary = {}

## Current game mode (TEST for battle testing, STORY for story playthrough).
var game_mode: Registry.GameMode = Registry.GameMode.TEST
## Context dictionary passed to the current screen (set before navigating).
var screen_context: Dictionary = {}
## Result from the current screen (set by screen on exit, null on cancel).
var screen_result: Variant = null


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
	if not Engine.has_singleton(&"SceneManager"):
		return
	var sm: Node = Engine.get_singleton(&"SceneManager")
	if sm:
		sm.change_scene(SCENE_MAIN_MENU)
