extends Control
## Mode Screen — central hub for navigation after loading/creating a game.

const MODE_SCREEN_PATH := "res://scenes/screens/mode_screen.tscn"
const SAVE_SCREEN_PATH := "res://scenes/screens/save_screen.tscn"
const BATTLE_BUILDER_PATH := "res://scenes/battle/battle_builder.tscn"
const SETTINGS_PATH := "res://ui/menus/settings_screen.tscn"
const MAIN_MENU_PATH := "res://scenes/main/main.tscn"
const PARTY_SCREEN_PATH := "res://scenes/screens/party_screen.tscn"
const BAG_SCREEN_PATH := "res://scenes/screens/bag_screen.tscn"

var _mode: Registry.GameMode = Registry.GameMode.TEST

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _GRID := "MarginContainer/VBox/CentreWrap/ButtonGrid"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _tamer_label: Label = get_node(_HEADER + "/TamerLabel")
@onready var _bits_label: Label = get_node(_HEADER + "/BitsLabel")
@onready var _party_strip: HBoxContainer = $MarginContainer/VBox/PartyStrip
@onready var _party_button: Button = get_node(_GRID + "/PartyButton")
@onready var _bag_button: Button = get_node(_GRID + "/BagButton")
@onready var _storage_button: Button = get_node(_GRID + "/StorageButton")
@onready var _save_button: Button = get_node(_GRID + "/SaveButton")
@onready var _battle_button: Button = get_node(_GRID + "/BattleButton")
@onready var _wild_battle_button: Button = get_node(_GRID + "/WildBattleButton")
@onready var _shop_button: Button = get_node(_GRID + "/ShopButton")
@onready var _training_button: Button = get_node(_GRID + "/TrainingButton")
@onready var _settings_button: Button = get_node(_GRID + "/SettingsButton")


func _ready() -> void:
	_mode = Game.screen_context.get("mode", Registry.GameMode.TEST)

	_update_header()
	_build_party_strip()
	_configure_buttons()
	_connect_signals()


func _update_header() -> void:
	if Game.state:
		_tamer_label.text = Game.state.tamer_name
		_bits_label.text = "%s Bits" % _format_bits(
			Game.state.inventory.bits
		)
	else:
		_tamer_label.text = "No Game"
		_bits_label.text = "0 Bits"


func _build_party_strip() -> void:
	for child: Node in _party_strip.get_children():
		child.queue_free()

	if Game.state == null or Game.state.party.members.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("No Digimon in party")
		empty_label.add_theme_color_override(
			"font_color", Color(0.443, 0.443, 0.478, 1)
		)
		empty_label.add_theme_font_size_override("font_size", 14)
		_party_strip.add_child(empty_label)
		return

	for i: int in Game.state.party.members.size():
		if i > 0:
			var sep := Label.new()
			sep.text = " | "
			sep.add_theme_font_size_override("font_size", 14)
			sep.add_theme_color_override(
				"font_color", Color(0.443, 0.443, 0.478, 1)
			)
			_party_strip.add_child(sep)

		var member: DigimonState = Game.state.party.members[i]
		var digimon_data: DigimonData = Atlas.digimon.get(member.key)
		var display: String = digimon_data.display_name if digimon_data else str(member.key)
		var label := Label.new()
		label.text = "%s Lv.%d" % [display, member.level]
		label.add_theme_font_size_override("font_size", 14)
		_party_strip.add_child(label)


func _configure_buttons() -> void:
	var coming_soon: String = tr("Coming Soon")

	# Always visible: Party, Bag, Storage, Save, Settings
	# TEST only: Battle, Wild Battle, Shop, Training
	var is_test: bool = _mode == Registry.GameMode.TEST
	_battle_button.visible = is_test
	_wild_battle_button.visible = is_test
	_shop_button.visible = is_test
	_training_button.visible = is_test

	# Enabled: Party, Bag, Save, Battle, Settings
	# Disabled: Storage, Wild Battle, Shop, Training
	_storage_button.disabled = true
	_storage_button.tooltip_text = coming_soon
	_wild_battle_button.disabled = true
	_wild_battle_button.tooltip_text = coming_soon
	_shop_button.disabled = true
	_shop_button.tooltip_text = coming_soon
	_training_button.disabled = true
	_training_button.tooltip_text = coming_soon


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_party_button.pressed.connect(_on_party_pressed)
	_bag_button.pressed.connect(_on_bag_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_battle_button.pressed.connect(_on_battle_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)


func _on_party_pressed() -> void:
	Game.screen_context = {
		"mode": _mode,
		"return_scene": MODE_SCREEN_PATH,
	}
	SceneManager.change_scene(PARTY_SCREEN_PATH)


func _on_bag_pressed() -> void:
	Game.screen_context = {
		"mode": _mode,
		"return_scene": MODE_SCREEN_PATH,
	}
	SceneManager.change_scene(BAG_SCREEN_PATH)


func _on_save_pressed() -> void:
	Game.screen_context = {
		"action": "save",
		"mode": _mode,
		"return_scene": MODE_SCREEN_PATH,
	}
	SceneManager.change_scene(SAVE_SCREEN_PATH)


func _on_battle_pressed() -> void:
	Game.screen_context = {"return_scene": MODE_SCREEN_PATH}
	SceneManager.change_scene(BATTLE_BUILDER_PATH)


func _on_settings_pressed() -> void:
	Game.screen_context = {"return_scene": MODE_SCREEN_PATH}
	SceneManager.change_scene(SETTINGS_PATH)


func _on_back_pressed() -> void:
	Game.state = null
	SceneManager.change_scene(MAIN_MENU_PATH)


func _format_bits(amount: int) -> String:
	var text: String = str(amount)
	var result: String = ""
	var count: int = 0
	for i: int in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result
