extends Control
## Title screen — entry point with mode selection and settings.

const SAVE_SCREEN_PATH := "res://scenes/screens/save_screen.tscn"
const SETTINGS_PATH := "res://ui/menus/settings_screen.tscn"


func _ready() -> void:
	MusicManager.play("res://assets/audio/music/07. Save Screen.mp3")

	var test_button: Button = $CentreContainer/VBox/TestModeButton
	test_button.pressed.connect(_on_test_mode_pressed)

	var story_button: Button = $CentreContainer/VBox/StoryModeButton
	story_button.disabled = true
	story_button.tooltip_text = tr("Coming Soon")
	story_button.pressed.connect(_on_story_mode_pressed)

	var settings_button: Button = $CentreContainer/VBox/SettingsButton
	settings_button.pressed.connect(_on_settings_pressed)

	print("Digimon World: Reinitialised — main scene loaded.")


func _on_test_mode_pressed() -> void:
	Game.screen_context = {
		"action": "select",
		"mode": Registry.GameMode.TEST,
		"return_scene": "res://scenes/main/main.tscn",
	}
	SceneManager.change_scene(SAVE_SCREEN_PATH)


func _on_story_mode_pressed() -> void:
	pass  # Future: navigate to story mode save select


func _on_settings_pressed() -> void:
	Game.screen_context = {
		"return_scene": "res://scenes/main/main.tscn",
	}
	SceneManager.change_scene(SETTINGS_PATH)
