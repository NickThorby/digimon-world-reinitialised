extends Control
## Settings screen — allows the player to configure display and battle preferences.

const MAIN_MENU_PATH := "res://scenes/main/main.tscn"

const _PANEL := "MarginContainer/VBox/CentreContainer/SettingsPanel/PanelMargin/SettingsVBox"

@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/HBox/BackButton
@onready var _name_style_option: OptionButton = get_node(
	_PANEL + "/NameStyleRow/NameStyleOption")
@onready var _use_game_names_check: CheckBox = get_node(
	_PANEL + "/UseGameNamesRow/UseGameNamesCheck")
@onready var _window_scale_option: OptionButton = get_node(
	_PANEL + "/WindowScaleRow/WindowScaleOption")
@onready var _text_speed_option: OptionButton = get_node(
	_PANEL + "/TextSpeedRow/TextSpeedOption")
@onready var _advance_mode_option: OptionButton = get_node(
	_PANEL + "/AdvanceModeRow/AdvanceModeOption")


func _ready() -> void:
	_populate_options()
	_load_current_values()
	_connect_signals()


func _populate_options() -> void:
	_name_style_option.clear()
	_name_style_option.add_item("Japanese", Settings.DisplayPreference.JAPANESE)
	_name_style_option.add_item("Dub", Settings.DisplayPreference.DUB)

	_window_scale_option.clear()
	for scale_key: Settings.WindowScale in Settings.WINDOW_SCALE_LABELS:
		var label: String = Settings.WINDOW_SCALE_LABELS[scale_key]
		_window_scale_option.add_item(label, scale_key)

	_text_speed_option.clear()
	_text_speed_option.add_item("Slow", Settings.TextSpeed.SLOW)
	_text_speed_option.add_item("Medium", Settings.TextSpeed.MEDIUM)
	_text_speed_option.add_item("Fast", Settings.TextSpeed.FAST)
	_text_speed_option.add_item("Instant", Settings.TextSpeed.INSTANT)

	_advance_mode_option.clear()
	_advance_mode_option.add_item("Manual", Settings.AdvanceMode.MANUAL)
	_advance_mode_option.add_item("Auto", Settings.AdvanceMode.AUTO)


func _load_current_values() -> void:
	_name_style_option.selected = _get_index_by_id(
		_name_style_option, Settings.display_preference
	)
	_use_game_names_check.button_pressed = Settings.use_game_names
	_window_scale_option.selected = _get_index_by_id(
		_window_scale_option, Settings.window_scale
	)
	_text_speed_option.selected = _get_index_by_id(
		_text_speed_option, Settings.text_speed
	)
	_advance_mode_option.selected = _get_index_by_id(
		_advance_mode_option, Settings.advance_mode
	)


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back)
	_name_style_option.item_selected.connect(_on_name_style_changed)
	_use_game_names_check.toggled.connect(_on_use_game_names_toggled)
	_window_scale_option.item_selected.connect(_on_window_scale_changed)
	_text_speed_option.item_selected.connect(_on_text_speed_changed)
	_advance_mode_option.item_selected.connect(_on_advance_mode_changed)


func _on_back() -> void:
	SceneManager.change_scene(MAIN_MENU_PATH)


func _on_name_style_changed(index: int) -> void:
	Settings.display_preference = _name_style_option.get_item_id(index) as Settings.DisplayPreference


func _on_use_game_names_toggled(enabled: bool) -> void:
	Settings.use_game_names = enabled


func _on_window_scale_changed(index: int) -> void:
	Settings.window_scale = _window_scale_option.get_item_id(index) as Settings.WindowScale


func _on_text_speed_changed(index: int) -> void:
	Settings.text_speed = _text_speed_option.get_item_id(index) as Settings.TextSpeed


func _on_advance_mode_changed(index: int) -> void:
	Settings.advance_mode = _advance_mode_option.get_item_id(index) as Settings.AdvanceMode


func _get_index_by_id(option_button: OptionButton, id: int) -> int:
	for i: int in option_button.item_count:
		if option_button.get_item_id(i) == id:
			return i
	return 0
