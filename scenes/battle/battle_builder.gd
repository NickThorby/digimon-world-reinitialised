extends Control
## Battle Builder — debug scene for composing teams and launching battles.

const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"
const PICKER_SCENE_PATH := "res://scenes/battle/digimon_picker.tscn"
const SLOT_PANEL_SCENE := preload("res://ui/components/digimon_slot_panel.tscn")
const TEAM_SAVE_POPUP_SCENE := preload("res://ui/components/team_save_popup.tscn")

@onready var _side_selector: TabBar = $MarginContainer/VBox/HSplit/LeftPanel/SideSelector
@onready var _team_list: VBoxContainer = $MarginContainer/VBox/HSplit/LeftPanel/TeamList
@onready var _add_digimon_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/AddDigimonButton
@onready var _save_team_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TeamButtonRow/SaveTeamButton
@onready var _load_team_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TeamButtonRow/LoadTeamButton
@onready var _launch_button: Button = $MarginContainer/VBox/BottomBar/LaunchButton
@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/HBox/BackButton
@onready var _validation_label: RichTextLabel = $MarginContainer/VBox/HSplit/RightPanel/ValidationLabel
# Settings tab
@onready var _format_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Settings/FormatRow/FormatOption
@onready var _xp_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Settings/XPRow/XPToggle
@onready var _exp_share_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Settings/ExpShareRow/ExpShareToggle
@onready var _side_label: Label = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Settings/SideLabel
@onready var _controller_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Settings/ControllerRow/ControllerOption
@onready var _wild_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Settings/WildRow/WildToggle
@onready var _owned_toggle: CheckBox = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Settings/OwnedRow/OwnedToggle
# Field Effects tab
@onready var _weather_option: OptionButton = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/WeatherRow/WeatherOption"
@onready var _weather_permanent: CheckBox = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/WeatherRow/WeatherPermanent"
@onready var _terrain_option: OptionButton = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/TerrainRow/TerrainOption"
@onready var _terrain_permanent: CheckBox = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/TerrainRow/TerrainPermanent"
@onready var _global_effects_list: VBoxContainer = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/GlobalEffectsList"
# Side Presets tab
@onready var _side_effects_list: VBoxContainer = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Side Presets/SidePresetContent/SideEffectsList"
@onready var _hazards_list: VBoxContainer = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Side Presets/SidePresetContent/HazardsList"
# Bag tab
@onready var _bag_category_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Bag/BagCategoryRow/BagCategoryOption
@onready var _bag_item_list: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Bag/BagScroll/BagItemList

var _config: BattleConfig = BattleConfig.new()
var _current_side: int = 0
var _editing_index: int = -1
var _bag_category_filter: int = -1  ## -1 = All
var _balance: GameBalance = null

## Per-side preset state. Key = side_index, value = { side_effects: {key: {enabled, permanent}},
## hazards: {key: {enabled, permanent, layers}} }
var _side_presets: Dictionary = {}


func _ready() -> void:
	MusicManager.play("res://assets/audio/music/07. Save Screen.mp3")
	_balance = load("res://data/config/game_balance.tres") as GameBalance

	var returning_from_battle: bool = Game.builder_context.size() > 0
	var returning_from_picker: bool = Game.picker_context.size() > 0

	if returning_from_battle:
		_restore_from_battle()
	elif returning_from_picker:
		_restore_from_picker()

	_setup_format_options()
	_connect_signals()

	if not returning_from_battle and not returning_from_picker:
		_config.apply_preset(BattleConfig.FormatPreset.SINGLES_1V1)

	if returning_from_battle or returning_from_picker:
		_sync_format_selector()

	_setup_field_effect_options()
	if not returning_from_battle:
		_init_side_presets()
	_update_side_selector()
	_update_team_display()
	_update_controller_display()
	_update_side_presets_display()


func _restore_from_battle() -> void:
	var ctx: Dictionary = Game.builder_context
	Game.builder_context = {}
	if ctx.has("config"):
		_config = ctx["config"] as BattleConfig
	_current_side = int(ctx.get("current_side", 0))
	if ctx.has("side_presets"):
		_side_presets = ctx["side_presets"] as Dictionary
	_restore_party_energy()
	_reset_non_owned_parties()


func _restore_party_energy() -> void:
	for i: int in _config.side_configs.size():
		if not _config.side_configs[i].get("is_owned", false):
			continue
		for digimon: Variant in _config.side_configs[i].get("party", []):
			if digimon is not DigimonState:
				continue
			var state: DigimonState = digimon as DigimonState
			var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
			if data == null:
				continue
			var stats: Dictionary = StatCalculator.calculate_all_stats(data, state)
			var personality: PersonalityData = Atlas.personalities.get(
				state.personality_key,
			) as PersonalityData
			var max_energy: int = StatCalculator.apply_personality(
				stats.get(&"energy", 1), &"energy", personality,
			)
			state.current_energy = max_energy


func _reset_non_owned_parties() -> void:
	for i: int in _config.side_configs.size():
		if _config.side_configs[i].get("is_owned", false):
			continue
		for digimon: Variant in _config.side_configs[i].get("party", []):
			if digimon is not DigimonState:
				continue
			var state: DigimonState = digimon as DigimonState
			var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
			if data == null:
				continue
			var stats: Dictionary = StatCalculator.calculate_all_stats(data, state)
			var personality: PersonalityData = Atlas.personalities.get(
				state.personality_key,
			) as PersonalityData
			var max_hp: int = StatCalculator.apply_personality(
				stats.get(&"hp", 1), &"hp", personality,
			)
			var max_energy: int = StatCalculator.apply_personality(
				stats.get(&"energy", 1), &"energy", personality,
			)
			state.current_hp = max_hp
			state.current_energy = max_energy
			state.status_conditions.clear()


func _restore_from_picker() -> void:
	var ctx: Dictionary = Game.picker_context
	var result: Variant = Game.picker_result
	Game.picker_result = null
	Game.picker_context = {}

	# Always restore config and side from context
	if ctx.has("config"):
		_config = ctx["config"] as BattleConfig
	_current_side = int(ctx.get("side", 0))

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
		var max_size: int = _balance.max_party_size if _balance else 6
		if party.size() >= max_size:
			return
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
	_exp_share_toggle.button_pressed = _config.exp_share_enabled
	_sync_field_effect_selectors()
	_sync_side_presets_from_config()


func _connect_signals() -> void:
	_format_option.item_selected.connect(_on_format_selected)
	_side_selector.tab_changed.connect(_on_side_selected)
	_add_digimon_button.pressed.connect(_on_add_digimon)
	_controller_option.item_selected.connect(_on_controller_selected)
	_wild_toggle.toggled.connect(_on_wild_toggled)
	_owned_toggle.toggled.connect(_on_owned_toggled)
	_xp_toggle.toggled.connect(_on_xp_toggled)
	_exp_share_toggle.toggled.connect(_on_exp_share_toggled)
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
		_init_side_presets()
		_update_side_selector()
		_update_team_display()
		_update_controller_display()
		_update_side_presets_display()
		_clear_validation()


func _on_side_selected(index: int) -> void:
	_save_side_presets()
	_current_side = index
	_update_team_display()
	_update_controller_display()
	_update_side_presets_display()
	_update_bag_display()


func _on_add_digimon() -> void:
	var max_size: int = _balance.max_party_size if _balance else 6
	if _current_side < _config.side_configs.size():
		var party: Array = _config.side_configs[_current_side].get("party", [])
		if party.size() >= max_size:
			_show_validation_message("Party is full (%d max)." % max_size)
			return
	_editing_index = -1
	_navigate_to_picker()


func _on_controller_selected(index: int) -> void:
	if _current_side < _config.side_configs.size():
		_config.side_configs[_current_side]["controller"] = index as BattleConfig.ControllerType


func _on_wild_toggled(pressed: bool) -> void:
	if _current_side < _config.side_configs.size():
		_config.side_configs[_current_side]["is_wild"] = pressed


func _on_owned_toggled(pressed: bool) -> void:
	if _current_side < _config.side_configs.size():
		_config.side_configs[_current_side]["is_owned"] = pressed


func _on_xp_toggled(pressed: bool) -> void:
	_config.xp_enabled = pressed


func _on_exp_share_toggled(pressed: bool) -> void:
	_config.exp_share_enabled = pressed


func _on_launch() -> void:
	_apply_field_effects_to_config()

	var errors: Array[String] = _config.validate()
	if errors.size() > 0:
		_show_validation_errors(errors)
		return

	_save_side_presets()
	Game.builder_context = {
		"config": _config,
		"current_side": _current_side,
		"side_presets": _side_presets.duplicate(true),
	}

	Game.battle_config = _config
	SceneManager.change_scene(BATTLE_SCENE_PATH)


func _on_back() -> void:
	var return_path: String = Game.screen_context.get(
		"return_scene", "res://scenes/main/main.tscn"
	)
	SceneManager.change_scene(return_path)


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


func _on_team_saved(_slot_name: String, team_name: String) -> void:
	_show_validation_message("Saved '%s'" % team_name)
	_free_team_popup()


func _on_team_loaded(team: BuilderTeamState) -> void:
	if _current_side >= _config.side_configs.size():
		_free_team_popup()
		return
	var max_size: int = _balance.max_party_size if _balance else 6
	var party: Array[DigimonState] = []
	for member: DigimonState in team.members:
		if party.size() >= max_size:
			break
		party.append(member)
	_config.side_configs[_current_side]["party"] = party
	_update_team_display()
	var loaded_count: int = party.size()
	var total_count: int = team.members.size()
	if loaded_count < total_count:
		_show_validation_message(
			"Loaded '%s' (%d of %d members — truncated to %d max)."
			% [team.name, loaded_count, total_count, max_size]
		)
	else:
		_show_validation_message("Loaded '%s' (%d members)." % [team.name, loaded_count])
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
		panel.reorder_requested.connect(_on_reorder_requested)


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

	var is_owned: bool = _config.side_configs[_current_side].get("is_owned", false)
	_owned_toggle.button_pressed = is_owned

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


func _on_reorder_requested(from_index: int, to_index: int) -> void:
	if _current_side >= _config.side_configs.size():
		return
	var party: Array = _config.side_configs[_current_side].get("party", [])
	if from_index < 0 or from_index >= party.size() \
			or to_index < 0 or to_index >= party.size():
		return
	var temp: Variant = party[from_index]
	party[from_index] = party[to_index]
	party[to_index] = temp
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


func _get_current_bag() -> BagState:
	if _current_side >= _config.side_configs.size():
		return BagState.new()
	var cfg: Dictionary = _config.side_configs[_current_side]
	if not cfg.has("bag") or cfg["bag"] is not BagState:
		cfg["bag"] = BagState.new()
	return cfg["bag"] as BagState


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

	var quantity: int = _get_current_bag().get_quantity(item.key)

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
		_get_current_bag().remove_item(item_key)
		_update_bag_display()
	)
	plus_button.pressed.connect(func() -> void:
		_get_current_bag().add_item(item_key)
		_update_bag_display()
	)

	return row


# --- Field Effects ---


func _setup_field_effect_options() -> void:
	# Weather dropdown
	_weather_option.clear()
	_weather_option.add_item("None")
	for weather_key: StringName in Registry.WEATHER_TYPES:
		_weather_option.add_item(str(weather_key).capitalize())
	_weather_permanent.button_pressed = true

	# Terrain dropdown
	_terrain_option.clear()
	_terrain_option.add_item("None")
	for terrain_key: StringName in Registry.TERRAIN_TYPES:
		_terrain_option.add_item(str(terrain_key).capitalize())
	_terrain_permanent.button_pressed = true

	# Global effects checkboxes
	_build_global_effects_list()


func _build_global_effects_list() -> void:
	for child: Node in _global_effects_list.get_children():
		child.queue_free()
	for key: StringName in Registry.GLOBAL_EFFECT_TYPES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle := CheckBox.new()
		toggle.text = str(key).replace("_", " ").capitalize()
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(toggle)
		var perm := CheckBox.new()
		perm.text = "Perm"
		perm.button_pressed = true
		row.add_child(perm)
		_global_effects_list.add_child(row)


func _sync_field_effect_selectors() -> void:
	# Sync weather
	var weather: Dictionary = _config.preset_field_effects.get("weather", {})
	if not weather.is_empty():
		var weather_key: StringName = StringName(weather.get("key", ""))
		for i: int in Registry.WEATHER_TYPES.size():
			if Registry.WEATHER_TYPES[i] == weather_key:
				_weather_option.selected = i + 1  # +1 for "None"
				break
		_weather_permanent.button_pressed = weather.get("permanent", true)
	else:
		_weather_option.selected = 0
		_weather_permanent.button_pressed = true

	# Sync terrain
	var terrain: Dictionary = _config.preset_field_effects.get("terrain", {})
	if not terrain.is_empty():
		var terrain_key: StringName = StringName(terrain.get("key", ""))
		for i: int in Registry.TERRAIN_TYPES.size():
			if Registry.TERRAIN_TYPES[i] == terrain_key:
				_terrain_option.selected = i + 1
				break
		_terrain_permanent.button_pressed = terrain.get("permanent", true)
	else:
		_terrain_option.selected = 0
		_terrain_permanent.button_pressed = true

	# Sync global effects
	var global_effects: Array = _config.preset_field_effects.get(
		"global_effects", [],
	)
	var active_keys: Dictionary = {}
	for effect: Variant in global_effects:
		if effect is Dictionary:
			var d: Dictionary = effect as Dictionary
			active_keys[StringName(d.get("key", ""))] = d.get(
				"permanent", true,
			)
	for i: int in _global_effects_list.get_child_count():
		var row: HBoxContainer = _global_effects_list.get_child(i) as HBoxContainer
		if row == null or row.get_child_count() < 2:
			continue
		var key: StringName = Registry.GLOBAL_EFFECT_TYPES[i]
		var toggle: CheckBox = row.get_child(0) as CheckBox
		var perm: CheckBox = row.get_child(1) as CheckBox
		if active_keys.has(key):
			toggle.button_pressed = true
			perm.button_pressed = active_keys[key]
		else:
			toggle.button_pressed = false
			perm.button_pressed = true


func _apply_field_effects_to_config() -> void:
	var presets: Dictionary = {}

	# Weather
	var weather_idx: int = _weather_option.selected
	if weather_idx > 0 and weather_idx - 1 < Registry.WEATHER_TYPES.size():
		presets["weather"] = {
			"key": Registry.WEATHER_TYPES[weather_idx - 1],
			"permanent": _weather_permanent.button_pressed,
		}

	# Terrain
	var terrain_idx: int = _terrain_option.selected
	if terrain_idx > 0 and terrain_idx - 1 < Registry.TERRAIN_TYPES.size():
		presets["terrain"] = {
			"key": Registry.TERRAIN_TYPES[terrain_idx - 1],
			"permanent": _terrain_permanent.button_pressed,
		}

	# Global effects
	var global_effects: Array[Dictionary] = []
	for i: int in _global_effects_list.get_child_count():
		var row: HBoxContainer = _global_effects_list.get_child(i) as HBoxContainer
		if row == null or row.get_child_count() < 2:
			continue
		var toggle: CheckBox = row.get_child(0) as CheckBox
		var perm: CheckBox = row.get_child(1) as CheckBox
		if toggle.button_pressed:
			global_effects.append({
				"key": Registry.GLOBAL_EFFECT_TYPES[i],
				"permanent": perm.button_pressed,
			})
	if not global_effects.is_empty():
		presets["global_effects"] = global_effects

	_config.preset_field_effects = presets

	# Side presets — save current side UI state first
	_save_side_presets()
	_apply_side_presets_to_config()


# --- Side Presets (per-side side effects and hazards) ---


## Initialise empty preset state for each side.
func _init_side_presets() -> void:
	_side_presets.clear()
	for i: int in _config.side_count:
		_side_presets[i] = {
			"side_effects": {},
			"hazards": {},
		}


## Save the current UI toggles into _side_presets for the current side.
func _save_side_presets() -> void:
	if not _side_presets.has(_current_side):
		_side_presets[_current_side] = {"side_effects": {}, "hazards": {}}

	var side_data: Dictionary = _side_presets[_current_side]

	# Side effects
	var se_dict: Dictionary = {}
	for i: int in _side_effects_list.get_child_count():
		var row: HBoxContainer = _side_effects_list.get_child(i) as HBoxContainer
		if row == null or row.get_child_count() < 2:
			continue
		var toggle: CheckBox = row.get_child(0) as CheckBox
		var perm: CheckBox = row.get_child(1) as CheckBox
		var key: StringName = Registry.SIDE_EFFECT_TYPES[i]
		se_dict[key] = {"enabled": toggle.button_pressed, "permanent": perm.button_pressed}
	side_data["side_effects"] = se_dict

	# Hazards — each hazard type has different extra controls
	var hz_dict: Dictionary = {}
	for i: int in _hazards_list.get_child_count():
		var container: VBoxContainer = _hazards_list.get_child(i) as VBoxContainer
		if container == null:
			continue
		var key: StringName = Registry.HAZARD_TYPES[i]
		var header: HBoxContainer = container.get_child(0) as HBoxContainer
		var toggle: CheckBox = header.get_child(0) as CheckBox
		var perm: CheckBox = header.get_child(1) as CheckBox
		var layers_spin: SpinBox = header.get_child(2) as SpinBox
		var aerial_check: CheckBox = header.get_child(3) as CheckBox
		var name_edit: LineEdit = header.get_child(4) as LineEdit
		var entry: Dictionary = {
			"enabled": toggle.button_pressed,
			"permanent": perm.button_pressed,
			"layers": int(layers_spin.value),
			"aerial_is_immune": aerial_check.button_pressed,
			"hazard_name": name_edit.text if name_edit != null else "",
		}
		var extras: HBoxContainer = container.get_child(1) as HBoxContainer
		if key == &"entry_damage":
			var element_opt: OptionButton = extras.get_child(1) as OptionButton
			var dmg_spin: SpinBox = extras.get_child(3) as SpinBox
			var element_idx: int = element_opt.selected
			entry["element"] = _HAZARD_ELEMENTS[element_idx] \
				if element_idx < _HAZARD_ELEMENTS.size() else &""
			entry["damagePercent"] = dmg_spin.value
		elif key == &"entry_stat_reduction":
			var stat_opt: OptionButton = extras.get_child(1) as OptionButton
			var stages_spin: SpinBox = extras.get_child(3) as SpinBox
			entry["stat"] = _HAZARD_STATS[stat_opt.selected] \
				if stat_opt.selected < _HAZARD_STATS.size() else "spe"
			entry["stages"] = int(stages_spin.value)
		elif key == &"entry_status_effect":
			var status_opt: OptionButton = extras.get_child(1) as OptionButton
			entry["status"] = _HAZARD_STATUSES[status_opt.selected] \
				if status_opt.selected < _HAZARD_STATUSES.size() \
				else "poisoned"
		hz_dict[key] = entry
	side_data["hazards"] = hz_dict


## Rebuild the side effects and hazards UI for the current side.
func _update_side_presets_display() -> void:
	_build_side_effects_list()
	_build_hazards_list()


func _build_side_effects_list() -> void:
	for child: Node in _side_effects_list.get_children():
		child.queue_free()

	var saved: Dictionary = {}
	if _side_presets.has(_current_side):
		saved = _side_presets[_current_side].get("side_effects", {})

	for key: StringName in Registry.SIDE_EFFECT_TYPES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle := CheckBox.new()
		toggle.text = str(key).replace("_", " ").capitalize()
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if saved.has(key):
			toggle.button_pressed = saved[key].get("enabled", false)
		row.add_child(toggle)
		var perm := CheckBox.new()
		perm.text = "Perm"
		perm.button_pressed = true
		if saved.has(key):
			perm.button_pressed = saved[key].get("permanent", true)
		row.add_child(perm)
		_side_effects_list.add_child(row)


## Element keys for the entry_damage element dropdown (index 0 = None).
const _HAZARD_ELEMENTS: Array[StringName] = [
	&"", &"fire", &"water", &"air", &"earth", &"ice",
	&"lightning", &"plant", &"metal", &"dark", &"light",
]

## Stat abbreviations for the entry_stat_reduction stat dropdown.
const _HAZARD_STATS: Array[String] = ["atk", "def", "spa", "spd", "spe"]

## Status keys for the entry_status_effect status dropdown.
const _HAZARD_STATUSES: Array[String] = [
	"poisoned", "burned", "frostbitten", "paralysed", "blinded", "seeded",
]


func _build_hazards_list() -> void:
	for child: Node in _hazards_list.get_children():
		child.queue_free()

	var saved: Dictionary = {}
	if _side_presets.has(_current_side):
		saved = _side_presets[_current_side].get("hazards", {})

	for key: StringName in Registry.HAZARD_TYPES:
		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Header row: toggle + perm + layers
		var header := HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle := CheckBox.new()
		toggle.text = str(key).replace("_", " ").capitalize()
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if saved.has(key):
			toggle.button_pressed = saved[key].get("enabled", false)
		header.add_child(toggle)
		var perm := CheckBox.new()
		perm.text = "Perm"
		perm.button_pressed = true
		if saved.has(key):
			perm.button_pressed = saved[key].get("permanent", true)
		header.add_child(perm)
		var layers := SpinBox.new()
		layers.min_value = 1
		layers.max_value = 5
		layers.value = 1
		layers.custom_minimum_size = Vector2(60, 0)
		layers.tooltip_text = "Layers"
		if saved.has(key):
			layers.value = saved[key].get("layers", 1)
		header.add_child(layers)
		var aerial_check := CheckBox.new()
		aerial_check.text = "Aerial Immune"
		aerial_check.button_pressed = false
		if saved.has(key):
			aerial_check.button_pressed = saved[key].get(
				"aerial_is_immune", false,
			)
		header.add_child(aerial_check)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Hazard Name"
		name_edit.custom_minimum_size = Vector2(100, 0)
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if saved.has(key):
			name_edit.text = saved[key].get("hazard_name", "")
		header.add_child(name_edit)
		container.add_child(header)

		# Extras row: type-specific controls
		var extras := HBoxContainer.new()
		extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == &"entry_damage":
			var el_label := Label.new()
			el_label.text = "  Element:"
			extras.add_child(el_label)
			var el_option := OptionButton.new()
			el_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			el_option.add_item("None")
			for el_key: StringName in _HAZARD_ELEMENTS:
				if el_key != &"":
					el_option.add_item(str(el_key).capitalize())
			var saved_element: StringName = &""
			if saved.has(key):
				saved_element = StringName(saved[key].get("element", ""))
			if saved_element != &"":
				for ei: int in _HAZARD_ELEMENTS.size():
					if _HAZARD_ELEMENTS[ei] == saved_element:
						el_option.selected = ei
						break
			extras.add_child(el_option)
			var dmg_label := Label.new()
			dmg_label.text = "Dmg%:"
			extras.add_child(dmg_label)
			var dmg_spin := SpinBox.new()
			dmg_spin.min_value = 0.0
			dmg_spin.max_value = 0.5
			dmg_spin.step = 0.0625
			dmg_spin.value = 0.125
			dmg_spin.custom_minimum_size = Vector2(80, 0)
			if saved.has(key):
				dmg_spin.value = saved[key].get("damagePercent", 0.125)
			extras.add_child(dmg_spin)
		elif key == &"entry_stat_reduction":
			var stat_label := Label.new()
			stat_label.text = "  Stat:"
			extras.add_child(stat_label)
			var stat_option := OptionButton.new()
			stat_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for abbr: String in _HAZARD_STATS:
				stat_option.add_item(abbr.to_upper())
			var saved_stat: String = ""
			if saved.has(key):
				saved_stat = saved[key].get("stat", "spe")
			for si: int in _HAZARD_STATS.size():
				if _HAZARD_STATS[si] == saved_stat:
					stat_option.selected = si
					break
			extras.add_child(stat_option)
			var stages_label := Label.new()
			stages_label.text = "Stages:"
			extras.add_child(stages_label)
			var stages_spin := SpinBox.new()
			stages_spin.min_value = -6
			stages_spin.max_value = -1
			stages_spin.value = -1
			stages_spin.custom_minimum_size = Vector2(60, 0)
			if saved.has(key):
				stages_spin.value = saved[key].get("stages", -1)
			extras.add_child(stages_spin)
		elif key == &"entry_status_effect":
			var status_label := Label.new()
			status_label.text = "  Status:"
			extras.add_child(status_label)
			var status_option := OptionButton.new()
			status_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for status_name: String in _HAZARD_STATUSES:
				status_option.add_item(status_name.capitalize())
			if saved.has(key):
				var saved_status: String = saved[key].get(
					"status", "poisoned",
				)
				for si: int in _HAZARD_STATUSES.size():
					if _HAZARD_STATUSES[si] == saved_status:
						status_option.selected = si
						break
			extras.add_child(status_option)
		container.add_child(extras)

		_hazards_list.add_child(container)


## Convert _side_presets into config arrays.
func _apply_side_presets_to_config() -> void:
	var side_effects: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []

	for side_idx: int in _side_presets:
		var data: Dictionary = _side_presets[side_idx]

		# Side effects
		for key: StringName in data.get("side_effects", {}):
			var entry: Dictionary = data["side_effects"][key]
			if not entry.get("enabled", false):
				continue
			side_effects.append({
				"key": key,
				"sides": [side_idx],
				"permanent": entry.get("permanent", true),
			})

		# Hazards
		for key: StringName in data.get("hazards", {}):
			var entry: Dictionary = data["hazards"][key]
			if not entry.get("enabled", false):
				continue
			var extra: Dictionary = {}
			if key == &"entry_damage":
				var element: StringName = StringName(
					entry.get("element", ""),
				)
				if element != &"":
					extra["element"] = element
				extra["damagePercent"] = entry.get("damagePercent", 0.125)
			elif key == &"entry_stat_reduction":
				extra["stat"] = entry.get("stat", "spe")
				extra["stages"] = entry.get("stages", -1)
			elif key == &"entry_status_effect":
				extra["status"] = entry.get("status", "poisoned")
			if entry.get("aerial_is_immune", false):
				extra["aerial_is_immune"] = true
			var hz_name: String = entry.get("hazard_name", "")
			if hz_name != "":
				extra["hazard_name"] = hz_name
			hazards.append({
				"key": key,
				"sides": [side_idx],
				"layers": entry.get("layers", 1),
				"permanent": entry.get("permanent", true),
				"extra": extra,
			})

	_config.preset_side_effects = side_effects
	_config.preset_hazards = hazards


## Restore _side_presets from config (when returning from picker).
func _sync_side_presets_from_config() -> void:
	_init_side_presets()

	# Side effects
	for entry: Dictionary in _config.preset_side_effects:
		var key: StringName = StringName(entry.get("key", ""))
		var permanent: bool = entry.get("permanent", true)
		for side_idx: Variant in entry.get("sides", []):
			var idx: int = int(side_idx)
			if _side_presets.has(idx):
				_side_presets[idx]["side_effects"][key] = {
					"enabled": true, "permanent": permanent,
				}

	# Hazards
	for entry: Dictionary in _config.preset_hazards:
		var key: StringName = StringName(entry.get("key", ""))
		var permanent: bool = entry.get("permanent", true)
		var layers: int = int(entry.get("layers", 1))
		var extra: Dictionary = entry.get("extra", {})
		for side_idx: Variant in entry.get("sides", []):
			var idx: int = int(side_idx)
			if _side_presets.has(idx):
				var hz_data: Dictionary = {
					"enabled": true, "permanent": permanent, "layers": layers,
				}
				if key == &"entry_damage":
					hz_data["element"] = StringName(extra.get("element", ""))
					hz_data["damagePercent"] = extra.get(
						"damagePercent", 0.125,
					)
				elif key == &"entry_stat_reduction":
					hz_data["stat"] = extra.get("stat", "spe")
					hz_data["stages"] = extra.get("stages", -1)
				elif key == &"entry_status_effect":
					hz_data["status"] = extra.get("status", "poisoned")
				hz_data["aerial_is_immune"] = extra.get(
					"aerial_is_immune", false,
				)
				var sync_hazard_name: String = extra.get(
					"hazard_name", "",
				)
				if sync_hazard_name != "":
					hz_data["hazard_name"] = sync_hazard_name
				_side_presets[idx]["hazards"][key] = hz_data
