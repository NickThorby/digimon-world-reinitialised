extends Control
## Battle Builder — debug scene for composing teams and launching battles.

const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"
const SLOT_PANEL_SCENE := preload("res://ui/components/digimon_slot_panel.tscn")
const PICKER_POPUP_SCENE := preload("res://ui/components/digimon_picker_popup.tscn")

@onready var _format_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/FormatRow/FormatOption
@onready var _side_selector: OptionButton = $MarginContainer/VBox/HSplit/LeftPanel/SideSelectorRow/SideSelector
@onready var _team_list: VBoxContainer = $MarginContainer/VBox/HSplit/LeftPanel/TeamList
@onready var _add_digimon_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/AddDigimonButton
@onready var _controller_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/ControllerRow/ControllerOption
@onready var _wild_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/WildToggle
@onready var _xp_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/XPToggle
@onready var _launch_button: Button = $MarginContainer/VBox/HSplit/RightPanel/LaunchButton
@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/BackButton
@onready var _save_team_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TeamButtonRow/SaveTeamButton
@onready var _load_team_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TeamButtonRow/LoadTeamButton
@onready var _validation_label: RichTextLabel = $MarginContainer/VBox/HSplit/RightPanel/ValidationLabel

var _config: BattleConfig = BattleConfig.new()
var _current_side: int = 0
var _editing_index: int = -1


func _ready() -> void:
	_setup_format_options()
	_connect_signals()
	_config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)
	_update_side_selector()
	_update_team_display()
	_update_controller_display()


func _setup_format_options() -> void:
	_format_option.clear()
	_format_option.add_item("Singles 1v1")
	_format_option.add_item("Doubles 2v2")
	_format_option.add_item("Doubles Multi (4 tamers)")
	_format_option.add_item("Triples 3v3")
	_format_option.add_item("FFA 3-player")
	_format_option.add_item("FFA 4-player")


func _connect_signals() -> void:
	_format_option.item_selected.connect(_on_format_selected)
	_side_selector.item_selected.connect(_on_side_selected)
	_add_digimon_button.pressed.connect(_on_add_digimon)
	_controller_option.item_selected.connect(_on_controller_selected)
	_wild_toggle.toggled.connect(_on_wild_toggled)
	_xp_toggle.toggled.connect(_on_xp_toggled)
	_launch_button.pressed.connect(_on_launch)
	_back_button.pressed.connect(_on_back)
	_save_team_button.pressed.connect(_on_save_team)
	_load_team_button.pressed.connect(_on_load_team)


func _on_format_selected(index: int) -> void:
	var presets: Array[BattleConfig.FormatPreset] = [
		BattleConfig.FormatPreset.SINGLES_1V1,
		BattleConfig.FormatPreset.DOUBLES_2V2,
		BattleConfig.FormatPreset.DOUBLES_MULTI,
		BattleConfig.FormatPreset.TRIPLES_3V3,
		BattleConfig.FormatPreset.FFA_3,
		BattleConfig.FormatPreset.FFA_4,
	]
	if index >= 0 and index < presets.size():
		_config.apply_preset(presets[index])
		_current_side = 0
		_update_side_selector()
		_update_team_display()
		_update_controller_display()
		_clear_validation()


func _on_side_selected(index: int) -> void:
	_current_side = index
	_update_team_display()
	_update_controller_display()


func _on_add_digimon() -> void:
	_editing_index = -1
	_open_picker()


func _on_controller_selected(index: int) -> void:
	if _current_side < _config.side_configs.size():
		_config.side_configs[_current_side]["controller"] = index as BattleConfig.ControllerType


func _on_wild_toggled(pressed: bool) -> void:
	if _current_side < _config.side_configs.size():
		_config.side_configs[_current_side]["is_wild"] = pressed


func _on_xp_toggled(pressed: bool) -> void:
	_config.xp_enabled = pressed


func _on_launch() -> void:
	var errors: Array[String] = _config.validate()
	if errors.size() > 0:
		_show_validation_errors(errors)
		return

	Game.battle_config = _config
	SceneManager.change_scene(BATTLE_SCENE_PATH)


func _on_back() -> void:
	SceneManager.change_scene("res://scenes/main/main.tscn")


func _on_save_team() -> void:
	if _current_side >= _config.side_configs.size():
		return
	var party: Array = _config.side_configs[_current_side].get("party", [])
	if party.size() == 0:
		return

	var team := BuilderTeamState.new()
	team.name = "Side %d Team" % (_current_side + 1)
	for member: Variant in party:
		if member is DigimonState:
			team.members.append(member as DigimonState)

	var slot_name: String = "team_%d" % Time.get_unix_time_from_system()
	BuilderSaveManager.save_team(team, slot_name)
	_show_validation_message("Team saved as '%s'" % slot_name)


func _on_load_team() -> void:
	var slots: Array[String] = BuilderSaveManager.get_team_slots()
	if slots.size() == 0:
		_show_validation_message("No saved teams found.")
		return

	# Load most recent team
	var latest_slot: String = slots[slots.size() - 1]
	var team: BuilderTeamState = BuilderSaveManager.load_team(latest_slot)
	if team == null:
		_show_validation_message("Failed to load team.")
		return

	if _current_side >= _config.side_configs.size():
		return

	var party: Array[DigimonState] = []
	for member: DigimonState in team.members:
		party.append(member)
	_config.side_configs[_current_side]["party"] = party
	_update_team_display()
	_show_validation_message("Loaded team '%s' (%d members)" % [team.name, team.members.size()])


func _open_picker(existing: DigimonState = null) -> void:
	var picker: DigimonPickerPopup = PICKER_POPUP_SCENE.instantiate() as DigimonPickerPopup
	add_child(picker)
	picker.digimon_confirmed.connect(_on_digimon_picked)
	picker.cancelled.connect(func() -> void: picker.queue_free())
	if existing != null:
		picker.prepopulate(existing)
	picker.popup_centered()


func _on_digimon_picked(state: DigimonState) -> void:
	if _current_side >= _config.side_configs.size():
		return

	var party: Array = _config.side_configs[_current_side].get("party", [])

	if _editing_index >= 0 and _editing_index < party.size():
		party[_editing_index] = state
	else:
		party.append(state)

	_config.side_configs[_current_side]["party"] = party
	_update_team_display()
	_clear_validation()

	# Clean up picker
	for child: Node in get_children():
		if child is DigimonPickerPopup:
			child.queue_free()


func _update_side_selector() -> void:
	_side_selector.clear()
	for i: int in _config.side_count:
		var team_idx: int = _config.team_assignments[i] if i < _config.team_assignments.size() else i
		_side_selector.add_item("Side %d (Team %d)" % [i + 1, team_idx + 1])
	if _current_side >= _config.side_count:
		_current_side = 0
	_side_selector.selected = _current_side


func _update_team_display() -> void:
	# Clear existing slot panels
	for child: Node in _team_list.get_children():
		child.queue_free()

	if _current_side >= _config.side_configs.size():
		return

	var party: Array = _config.side_configs[_current_side].get("party", [])
	for i: int in party.size():
		var state: DigimonState = party[i] as DigimonState
		if state == null:
			continue
		var panel: DigimonSlotPanel = SLOT_PANEL_SCENE.instantiate() as DigimonSlotPanel
		_team_list.add_child(panel)
		panel.setup(i, state)
		panel.edit_pressed.connect(_on_slot_edit)
		panel.remove_pressed.connect(_on_slot_remove)


func _update_controller_display() -> void:
	if _current_side >= _config.side_configs.size():
		return
	var controller: int = _config.side_configs[_current_side].get(
		"controller", BattleConfig.ControllerType.PLAYER
	)
	_controller_option.selected = controller

	var is_wild: bool = _config.side_configs[_current_side].get("is_wild", false)
	_wild_toggle.button_pressed = is_wild


func _on_slot_edit(index: int) -> void:
	_editing_index = index
	var party: Array = _config.side_configs[_current_side].get("party", [])
	var existing: DigimonState = party[index] as DigimonState if index < party.size() else null
	_open_picker(existing)


func _on_slot_remove(index: int) -> void:
	if _current_side >= _config.side_configs.size():
		return
	var party: Array = _config.side_configs[_current_side].get("party", [])
	if index >= 0 and index < party.size():
		party.remove_at(index)
		_config.side_configs[_current_side]["party"] = party
		_update_team_display()


func _show_validation_errors(errors: Array[String]) -> void:
	_validation_label.text = "[color=red]" + "\n".join(errors) + "[/color]"


func _show_validation_message(msg: String) -> void:
	_validation_label.text = msg


func _clear_validation() -> void:
	_validation_label.text = ""
