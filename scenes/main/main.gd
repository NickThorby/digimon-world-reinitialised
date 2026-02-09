extends Control
## Entry point scene. Redirects to appropriate screen on load.

const BATTLE_BUILDER_PATH := "res://scenes/battle/battle_builder.tscn"
const SETTINGS_PATH := "res://ui/menus/settings_screen.tscn"


func _ready() -> void:
	var builder_button: Button = get_node("CentreContainer/VBox/BuilderButton") as Button
	if builder_button:
		builder_button.pressed.connect(_on_builder_pressed)
	var settings_button: Button = get_node("CentreContainer/VBox/SettingsButton") as Button
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	print("Digimon World: Reinitialised — main scene loaded.")


func _on_builder_pressed() -> void:
	SceneManager.change_scene(BATTLE_BUILDER_PATH)


func _on_settings_pressed() -> void:
	SceneManager.change_scene(SETTINGS_PATH)
