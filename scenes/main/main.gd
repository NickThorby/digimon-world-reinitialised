extends Node2D
## Entry point scene. Redirects to appropriate screen on load.

const BATTLE_BUILDER_PATH := "res://scenes/battle/battle_builder.tscn"


func _ready() -> void:
	var builder_button: Button = get_node("CentreContainer/VBox/BuilderButton") as Button
	if builder_button:
		builder_button.pressed.connect(_on_builder_pressed)
	print("Digimon World: Reinitialised — main scene loaded.")


func _on_builder_pressed() -> void:
	SceneManager.change_scene(BATTLE_BUILDER_PATH)
