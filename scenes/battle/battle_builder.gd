extends Control
## Battle Builder — debug scene for composing teams and launching battles.

const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"
const PICKER_SCENE_PATH := "res://scenes/battle/digimon_picker.tscn"
const SLOT_PANEL_SCENE := preload("res://ui/components/digimon_slot_panel.tscn")
const TEAM_SAVE_POPUP_SCENE := preload("res://ui/components/team_save_popup.tscn")

@onready var _format_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/FormatRow/FormatOption
@onready var _side_selector: TabBar = $MarginContainer/VBox/HSplit/LeftPanel/SideSelector
@onready var _team_list: VBoxContainer = $MarginContainer/VBox/HSplit/LeftPanel/TeamList
@onready var _add_digimon_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/AddDigimonButton
@onready var _controller_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/ControllerRow/ControllerOption
@onready var _wild_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/WildRow/WildToggle
@onready var _xp_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/XPRow/XPToggle
@onready var _launch_button: Button = $MarginContainer/VBox/BottomBar/LaunchButton
@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/HBox/BackButton
@onready var _save_team_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TeamButtonRow/SaveTeamButton
@onready var _load_team_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TeamButtonRow/LoadTeamButton
@onready var _validation_label: RichTextLabel = $MarginContainer/VBox/HSplit/RightPanel/ValidationLabel
@onready var _side_label: Label = $MarginContainer/VBox/HSplit/RightPanel/SideLabel
@onready var _bag_category_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/BagSection/BagCategoryRow/BagCategoryOption
@onready var _bag_item_list: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/BagSection/BagScroll/BagItemList

var _config: BattleConfig = BattleConfig.new()
var _current_side: int = 0
var _editing_index: int = -1
var _builder_bag: BagState = BagState.new()
var _bag_category_filter: int = -1  ## -1 = All


func _ready() -> void:
	var returning_from_picker: bool = Game.picker_context.size() > 0
	if returning_from_picker:
		_restore_from_picker()

	_setup_format_options()
	_connect_signals()

	if not returning_from_picker:
		_config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	if returning_from_picker:
		_sync_format_selector()

	_update_side_selector()
	_update_team_display()
	_update_controller_display()


func _restore_from_picker() -> void:
	var ctx: Dictionary = Game.picker_context
	var result: Variant = Game.picker_result
	Game.picker_result = null
	Game.picker_context = {}

	# Always restore config and side from context
	if ctx.has("config"):
		_config = ctx["config"] as BattleConfig
	_current_side = int(ctx.get("side", 0))
	if ctx.has("bag"):
		_builder_bag = ctx["bag"] as BagState

	# If user cancelled (null result), just restore state without adding
	if result == null or result is not DigimonState:
		return

	var state: DigimonState = result as DigimonState
	var side: int = int(ctx.get("side", 0))
	var editing_idx: int = int(ctx.get("editing_index", -1))

	if side >= _config.side_configs.size():
		return

	var party: Array = _config.side_configs[side].get("party", [])

	if editing_idx >= 0 and editing_idx < party.size():
		party[editing_idx] = state
	else:
		party.append(state)

	_config.side_configs[side]["party"] = party


func _setup_format_options() -> void:
	_format_option.clear()
	_format_option.add_item("Singles 1v1")
	_format_option.add_item("Doubles 2v2")
	_format_option.add_item("Doubles Multi (4 tamers)")
	_format_option.add_item("Triples 3v3")
	_format_option.add_item("FFA 3-player")
	_format_option.add_item("FFA 4-player")


func _sync_format_selector() -> void:
	var preset_map: Dictionary = {
		BattleConfig.FormatPreset.SINGLES_1V1: 0,
		BattleConfig.FormatPreset.DOUBLES_2V2: 1,
		BattleConfig.FormatPreset.DOUBLES_MULTI: 2,
		BattleConfig.FormatPreset.TRIPLES_3V3: 3,
		BattleConfig.FormatPreset.FFA_3: 4,
		BattleConfig.FormatPreset.FFA_4: 5,
	}
	var idx: int = preset_map.get(_config.format_preset, 0)
	_format_option.selected = idx
	_xp_toggle.button_pressed = _config.xp_enabled


func _connect_signals() -> void:
	_format_option.item_selected.connect(_on_format_selected)
	_side_selector.tab_changed.connect(_on_side_selected)
	_add_digimon_button.pressed.connect(_on_add_digimon)
	_controller_option.item_selected.connect(_on_controller_selected)
	_wild_toggle.toggled.connect(_on_wild_toggled)
	_xp_toggle.toggled.connect(_on_xp_toggled)
	_launch_button.pressed.connect(_on_launch)
	_back_button.pressed.connect(_on_back)
	_save_team_button.pressed.connect(_on_save_team)
	_load_team_button.pressed.connect(_on_load_team)
	_bag_category_option.item_selected.connect(_on_bag_category_selected)
	_setup_bag_category_options()


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
	_navigate_to_picker()


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

	# Inject bag into all player-controlled sides
	if not _builder_bag.is_empty():
		for i: int in _config.side_configs.size():
			var controller: int = int(
				_config.side_configs[i].get("controller", 0)
			)
			if controller == BattleConfig.ControllerType.PLAYER:
				_config.side_configs[i]["bag"] = _builder_bag

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

	_open_team_popup(TeamSavePopup.PopupMode.SAVE, team)


func _on_load_team() -> void:
	_open_team_popup(TeamSavePopup.PopupMode.LOAD)


func _open_team_popup(mode: TeamSavePopup.PopupMode, team: BuilderTeamState = null) -> void:
	var popup: TeamSavePopup = TEAM_SAVE_POPUP_SCENE.instantiate() as TeamSavePopup
	add_child(popup)
	popup.team_saved.connect(_on_team_saved)
	popup.team_loaded.connect(_on_team_loaded)
	popup.cancelled.connect(func() -> void: popup.queue_free())
	popup.setup(mode, team)
	popup.popup_centered()


func _on_team_saved(slot_name: String, team_name: String) -> void:
	_show_validation_message("Saved '%s'" % team_name)
	_free_team_popup()


func _on_team_loaded(team: BuilderTeamState) -> void:
	if _current_side >= _config.side_configs.size():
		_free_team_popup()
		return
	var party: Array[DigimonState] = []
	for member: DigimonState in team.members:
		party.append(member)
	_config.side_configs[_current_side]["party"] = party
	_update_team_display()
	_show_validation_message("Loaded '%s' (%d members)" % [team.name, team.members.size()])
	_free_team_popup()


func _free_team_popup() -> void:
	for child: Node in get_children():
		if child is TeamSavePopup:
			child.queue_free()


func _navigate_to_picker(existing: DigimonState = null) -> void:
	Game.picker_context = {
		"side": _current_side,
		"editing_index": _editing_index,
		"existing_state": existing,
		"config": _config,
		"bag": _builder_bag,
	}
	Game.picker_result = null
	SceneManager.change_scene(PICKER_SCENE_PATH)


func _update_side_selector() -> void:
	_side_selector.clear_tabs()
	for i: int in _config.side_count:
		var team_idx: int = _config.team_assignments[i] if i < _config.team_assignments.size() else i
		_side_selector.add_tab("Side %d (Team %d)" % [i + 1, team_idx + 1])
	if _current_side >= _config.side_count:
		_current_side = 0
	_side_selector.current_tab = _current_side


func _update_team_display() -> void:
	# Clear existing slot panels
	for child: Node in _team_list.get_children():
		child.queue_free()

	if _current_side >= _config.side_configs.size():
		return

	var party: Array = _config.side_configs[_current_side].get("party", [])

	if party.size() == 0:
		_add_empty_placeholder()
		return

	for i: int in party.size():
		var state: DigimonState = party[i] as DigimonState
		if state == null:
			continue
		var panel: DigimonSlotPanel = SLOT_PANEL_SCENE.instantiate() as DigimonSlotPanel
		_team_list.add_child(panel)
		panel.setup(i, state)
		panel.edit_pressed.connect(_on_slot_edit)
		panel.remove_pressed.connect(_on_slot_remove)


func _add_empty_placeholder() -> void:
	var placeholder := Label.new()
	placeholder.text = "No Digimon added yet.\nClick 'Add Digimon' to get started."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placeholder.add_theme_color_override("font_color", Color(0.631, 0.631, 0.667, 1))
	_team_list.add_child(placeholder)


func _update_controller_display() -> void:
	if _current_side >= _config.side_configs.size():
		return
	var controller: int = _config.side_configs[_current_side].get(
		"controller", BattleConfig.ControllerType.PLAYER
	)
	_controller_option.selected = controller

	var is_wild: bool = _config.side_configs[_current_side].get("is_wild", false)
	_wild_toggle.button_pressed = is_wild

	# Update side label
	_side_label.text = "Side %d Settings" % (_current_side + 1)


func _on_slot_edit(index: int) -> void:
	_editing_index = index
	var party: Array = _config.side_configs[_current_side].get("party", [])
	var existing: DigimonState = party[index] as DigimonState if index < party.size() else null
	_navigate_to_picker(existing)


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


func _setup_bag_category_options() -> void:
	_bag_category_option.clear()
	_bag_category_option.add_item("All")
	_bag_category_option.add_item("Medicine")
	_bag_category_option.add_item("Gear")
	_bag_category_option.add_item("Capture/Scan")
	_bag_category_option.add_item("General")
	_bag_category_option.add_item("Performance")
	_bag_category_option.selected = 0
	_update_bag_display()


func _on_bag_category_selected(index: int) -> void:
	_bag_category_filter = index - 1  ## 0=All(-1), 1=Medicine(2), 2=Gear(4), etc.
	_update_bag_display()


func _get_bag_filter_category() -> int:
	## Maps dropdown index to Registry.ItemCategory. Returns -1 for "All".
	match _bag_category_filter:
		0: return Registry.ItemCategory.MEDICINE
		1: return Registry.ItemCategory.GEAR
		2: return Registry.ItemCategory.CAPTURE_SCAN
		3: return Registry.ItemCategory.GENERAL
		4: return Registry.ItemCategory.PERFORMANCE
		_: return -1


func _update_bag_display() -> void:
	for child: Node in _bag_item_list.get_children():
		child.queue_free()

	var filter: int = _get_bag_filter_category()
	var shown_items: Array[ItemData] = []

	for key: StringName in Atlas.items:
		var item: ItemData = Atlas.items[key] as ItemData
		if item == null:
			continue
		if filter >= 0 and item.category != filter:
			continue
		shown_items.append(item)

	shown_items.sort_custom(
		func(a: ItemData, b: ItemData) -> bool: return a.name < b.name
	)

	if shown_items.is_empty():
		var label := Label.new()
		label.text = "No items available."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.631, 0.631, 0.667))
		_bag_item_list.add_child(label)
		return

	for item: ItemData in shown_items:
		var row := _create_bag_item_row(item)
		_bag_item_list.add_child(row)


func _create_bag_item_row(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = item.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var quantity: int = _builder_bag.get_quantity(item.key)

	var minus_button := Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(30, 0)
	minus_button.disabled = quantity <= 0
	row.add_child(minus_button)

	var qty_label := Label.new()
	qty_label.text = str(quantity)
	qty_label.custom_minimum_size = Vector2(30, 0)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_label)

	var plus_button := Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(30, 0)
	row.add_child(plus_button)

	var item_key: StringName = item.key
	minus_button.pressed.connect(func() -> void:
		_builder_bag.remove_item(item_key)
		_update_bag_display()
	)
	plus_button.pressed.connect(func() -> void:
		_builder_bag.add_item(item_key)
		_update_bag_display()
	)

	return row
