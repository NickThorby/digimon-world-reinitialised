extends Control
## Full-screen Digimon picker: browse/preview with filters, then configure before adding.


# --- Stage enum ---

enum Stage { BROWSE, CONFIGURE }

# --- Browse stage nodes ---

@onready var _search_field: LineEdit = $MarginContainer/VBox/HSplit/LeftPanel/SearchField
@onready var _level_filters: HFlowContainer = $MarginContainer/VBox/HSplit/LeftPanel/FilterSection/LevelFilters
@onready var _attribute_filters: HFlowContainer = $MarginContainer/VBox/HSplit/LeftPanel/FilterSection/AttributeFilters
@onready var _species_list: ItemList = $MarginContainer/VBox/HSplit/LeftPanel/SpeciesList
@onready var _preview_panel: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel
@onready var _sprite_preview: TextureRect = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/SpritePreview
@onready var _name_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/InfoVBox/NameLabel
@onready var _attribute_icon: TextureRect = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/InfoVBox/IconRow/AttributeIcon
@onready var _element_icons: HBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/InfoVBox/IconRow/ElementIcons
@onready var _preview_content: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewContent
@onready var _stat_bars: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewContent/StatsSection/StatBars
@onready var _bst_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewContent/StatsSection/BSTLabel
@onready var _abilities_container: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewContent/AbilitiesSection/AbilitiesContainer
@onready var _technique_header: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewContent/TechniqueSection/TechniqueHeader
@onready var _technique_preview_container: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewContent/TechniqueSection/TechniqueScroll/TechniquePreviewContainer

# --- Configure stage nodes ---

@onready var _config_panel: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel
@onready var _config_title: Label = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigTitle
@onready var _level_slider: HSlider = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/LevelRow/LevelSlider
@onready var _level_value_label: Label = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/LevelRow/LevelValue
@onready var _tp_slider: HSlider = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/TPRow/TPSlider
@onready var _tp_value_label: Label = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/TPRow/TPValue
@onready var _ability_buttons: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/AbilitySection/AbilityButtons
@onready var _iv_sliders: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/IVSection/IVSliders
@onready var _tv_sliders: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/TVSection/TVSliders
@onready var _technique_label: Label = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/TechniqueConfigSection/TechniqueLabel
@onready var _technique_buttons: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/TechniqueConfigSection/TechniqueButtons
@onready var _equipable_gear_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/GearSection/EquipableGearRow/EquipableGearOption
@onready var _consumable_gear_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/GearSection/ConsumableGearRow/ConsumableGearOption
@onready var _back_config_button: Button = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigButtonRow/BackConfigButton
@onready var _confirm_button: Button = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigButtonRow/ConfirmButton

# --- Bottom buttons ---

@onready var _add_button: Button = $MarginContainer/VBox/BottomBar/AddButton
@onready var _cancel_button: Button = $MarginContainer/VBox/BottomBar/CancelButton
@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/BackButton

# --- State ---

var _filtered_keys: Array[StringName] = []
var _selected_key: StringName = &""
var _stage: Stage = Stage.BROWSE
var _max_equipped: int = 4
var _max_iv: int = 50
var _max_tv: int = 500
var _max_total_tvs: int = 1000
var _max_level: int = 100
var _max_tp: int = 999

## Pending state created by DigimonFactory, modified by config sliders.
var _pending_state: DigimonState = null

## Slider references for reading values: stat_key -> { "slider": HSlider, "label": Label }
var _iv_slider_map: Dictionary = {}
var _tv_slider_map: Dictionary = {}

## When true, skip the CONFIGURE stage and return species key only.
var _species_only: bool = false

## Active filter sets (empty = no filter / show all).
var _active_levels: Dictionary = {}
var _active_attributes: Dictionary = {}

## Selected ability slot (1-based), tracked via ability buttons.
var _selected_ability_slot: int = 1
## Selected technique keys for equipping, tracked via technique buttons.
var _selected_technique_keys: Array[StringName] = []
## Available technique keys at current level (parallel to button order).
var _available_technique_keys: Array[StringName] = []
## Gear keys parallel to OptionButton indices (index 0 = "None" = &"").
var _equipable_gear_keys: Array[StringName] = []
var _consumable_gear_keys: Array[StringName] = []

## Stat keys in display order.
const STAT_KEYS: Array[StringName] = [
	&"hp", &"energy", &"attack", &"defence",
	&"special_attack", &"special_defence", &"speed",
]

const STAT_DISPLAY_NAMES: Dictionary = {
	&"hp": "HP",
	&"energy": "Energy",
	&"attack": "Attack",
	&"defence": "Defence",
	&"special_attack": "Sp. Attack",
	&"special_defence": "Sp. Defence",
	&"speed": "Speed",
}

const BASE_STAT_FIELDS: Dictionary = {
	&"hp": "base_hp",
	&"energy": "base_energy",
	&"attack": "base_attack",
	&"defence": "base_defence",
	&"special_attack": "base_special_attack",
	&"special_defence": "base_special_defence",
	&"speed": "base_speed",
}

const BUILDER_SCENE_PATH := "res://scenes/battle/battle_builder.tscn"


func _ready() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	if balance:
		_max_equipped = balance.max_equipped_techniques
		_max_level = balance.max_level
		_max_iv = balance.max_iv
		_max_tv = balance.max_tv
		_max_total_tvs = balance.max_total_tvs
		_max_tp = balance.max_training_points

	_technique_label.text = "Techniques (select up to %d)" % _max_equipped

	_level_slider.min_value = 1
	_level_slider.max_value = _max_level
	_level_slider.step = 1
	_level_slider.value = 5

	_tp_slider.min_value = 0
	_tp_slider.max_value = _max_tp
	_tp_slider.step = 1
	_tp_slider.value = 0

	_search_field.text_changed.connect(_on_search_changed)
	_species_list.item_selected.connect(_on_species_selected)
	_add_button.pressed.connect(_on_add_pressed)
	_cancel_button.pressed.connect(_on_cancel)
	_back_button.pressed.connect(_on_cancel)
	_back_config_button.pressed.connect(_on_back_pressed)
	_confirm_button.pressed.connect(_on_confirm)
	_level_slider.value_changed.connect(_on_level_changed)
	_tp_slider.value_changed.connect(_on_tp_changed)

	# Check for species-only mode (e.g. wild encounter table)
	var ctx: Dictionary = Game.picker_context
	_species_only = ctx.get("species_only", false)
	if _species_only:
		_add_button.text = ctx.get("add_button_text", "Add to Encounter Table")

	_build_filter_pills()
	_populate_species_list()
	_set_stage(Stage.BROWSE)
	_clear_preview()

	# Prepopulate if editing an existing Digimon
	var existing: Variant = ctx.get("existing_state")
	if existing is DigimonState:
		_prepopulate(existing as DigimonState)


## Prepopulate the picker with an existing DigimonState for editing.
func _prepopulate(state: DigimonState) -> void:
	_selected_key = state.key
	# Find and highlight species in list
	for i: int in _filtered_keys.size():
		if _filtered_keys[i] == state.key:
			_species_list.select(i)
			break
	_update_preview()
	_level_slider.value = state.level
	_enter_config_stage(state)


# --- Filter Pills ---


func _build_filter_pills() -> void:
	# Level pills
	var level_values: Array = [
		Registry.EvolutionLevel.BABY_I,
		Registry.EvolutionLevel.BABY_II,
		Registry.EvolutionLevel.CHILD,
		Registry.EvolutionLevel.ADULT,
		Registry.EvolutionLevel.PERFECT,
		Registry.EvolutionLevel.ULTIMATE,
		Registry.EvolutionLevel.SUPER_ULTIMATE,
		Registry.EvolutionLevel.ARMOR,
		Registry.EvolutionLevel.HYBRID,
		Registry.EvolutionLevel.UNKNOWN,
	]
	var level_labels: Dictionary = Registry.evolution_level_labels
	for level_val: Variant in level_values:
		var label_text: String = level_labels.get(level_val, "Unknown")
		_create_pill_button(label_text, null, _active_levels, level_val, _level_filters)

	# Attribute pills
	var attr_values: Array = [
		Registry.Attribute.VACCINE,
		Registry.Attribute.VIRUS,
		Registry.Attribute.DATA,
		Registry.Attribute.FREE,
		Registry.Attribute.VARIABLE,
		Registry.Attribute.UNKNOWN,
	]
	for attr_val: Variant in attr_values:
		var label_text: String = Registry.attribute_labels.get(attr_val, "Unknown")
		var icon: Texture2D = Registry.ATTRIBUTE_ICONS.get(attr_val) as Texture2D
		_create_pill_button(label_text, icon, _active_attributes, attr_val, _attribute_filters)


func _create_pill_button(
	text: String,
	icon_texture: Texture2D,
	group_dict: Dictionary,
	key: Variant,
	container: HFlowContainer,
) -> void:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = false
	btn.custom_minimum_size = Vector2(0, 28)

	if icon_texture:
		btn.icon = icon_texture
		btn.expand_icon = true

	# Use smaller font
	btn.add_theme_font_size_override("font_size", 13)

	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			group_dict[key] = true
		else:
			group_dict.erase(key)
		_apply_filters()
	)

	container.add_child(btn)


func _apply_filters() -> void:
	_populate_species_list()

	# Try to re-select previous selection
	if _selected_key != &"":
		var found: bool = false
		for i: int in _filtered_keys.size():
			if _filtered_keys[i] == _selected_key:
				_species_list.select(i)
				found = true
				break
		if not found:
			_selected_key = &""
			_clear_preview()
			_add_button.disabled = true


# --- Stage Management ---


func _set_stage(stage: Stage) -> void:
	_stage = stage
	match stage:
		Stage.BROWSE:
			_preview_panel.visible = true
			_config_panel.visible = false
			_add_button.visible = true
			_add_button.disabled = (_selected_key == &"")
		Stage.CONFIGURE:
			_preview_panel.visible = false
			_config_panel.visible = true
			_add_button.visible = false


# --- Browse Stage ---


func _populate_species_list() -> void:
	_species_list.clear()
	_filtered_keys.clear()

	var filter_lower: String = _search_field.text.to_lower()
	var sorted_keys: Array = Atlas.digimon.keys()

	# Sort by evolution level, then alphabetically by display name
	sorted_keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da: DigimonData = Atlas.digimon[a]
		var db: DigimonData = Atlas.digimon[b]
		if da.level != db.level:
			return da.level < db.level
		return da.display_name.naturalnocasecmp_to(db.display_name) < 0
	)

	for digi_key: StringName in sorted_keys:
		var data: DigimonData = Atlas.digimon[digi_key] as DigimonData
		if data == null:
			continue

		# Apply level filter
		if _active_levels.size() > 0:
			if not _active_levels.has(data.level):
				continue

		# Apply attribute filter
		if _active_attributes.size() > 0:
			if not _active_attributes.has(data.attribute):
				continue

		# Apply search text filter
		var display: String = data.display_name
		if filter_lower != "":
			if not display.to_lower().contains(filter_lower) and \
					not str(digi_key).to_lower().contains(filter_lower):
				continue

		_species_list.add_item(display)
		_filtered_keys.append(digi_key)


func _on_search_changed(_new_text: String) -> void:
	_populate_species_list()
	_selected_key = &""
	_clear_preview()
	_add_button.disabled = true


func _on_species_selected(index: int) -> void:
	if index < 0 or index >= _filtered_keys.size():
		return
	_selected_key = _filtered_keys[index]
	_update_preview()
	_add_button.disabled = false


func _clear_preview() -> void:
	_name_label.text = ""
	_attribute_icon.texture = null
	_clear_element_icons()
	_bst_label.text = ""
	_sprite_preview.texture = null
	_preview_content.visible = false
	_clear_stat_bars()
	_clear_abilities()
	_clear_technique_preview()


func _clear_stat_bars() -> void:
	for child: Node in _stat_bars.get_children():
		child.queue_free()


func _clear_element_icons() -> void:
	for child: Node in _element_icons.get_children():
		child.queue_free()


func _clear_abilities() -> void:
	for child: Node in _abilities_container.get_children():
		child.queue_free()


func _clear_technique_preview() -> void:
	for child: Node in _technique_preview_container.get_children():
		child.queue_free()


func _update_preview() -> void:
	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		_clear_preview()
		return

	_preview_content.visible = true
	_name_label.text = data.display_name

	# Attribute icon
	_attribute_icon.texture = Registry.ATTRIBUTE_ICONS.get(data.attribute) as Texture2D

	# Element icons
	_clear_element_icons()
	for element_key: StringName in data.element_traits:
		var element_enum: Variant = Registry.ELEMENT_KEY_MAP.get(element_key)
		if element_enum == null:
			continue
		var icon_tex: Texture2D = Registry.ELEMENT_ICONS.get(element_enum) as Texture2D
		if icon_tex == null:
			continue
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon_tex
		_element_icons.add_child(icon_rect)

	# Sprite
	_sprite_preview.texture = data.sprite_texture

	# Stat bars
	_clear_stat_bars()
	for stat_key: StringName in STAT_KEYS:
		var base_val: int = data.get(BASE_STAT_FIELDS[stat_key]) as int
		_add_stat_bar(STAT_DISPLAY_NAMES[stat_key], base_val)

	_bst_label.text = "BST: %d" % data.bst

	# Abilities (detailed)
	_clear_abilities()
	var ability_slots: Array[StringName] = [
		data.ability_slot_1_key,
		data.ability_slot_2_key,
		data.ability_slot_3_key,
	]
	for i: int in ability_slots.size():
		var akey: StringName = ability_slots[i]
		if akey == &"":
			continue
		var adata: AbilityData = Atlas.abilities.get(akey) as AbilityData
		if adata == null:
			continue
		_add_ability_card(i + 1, adata)

	# Techniques (detailed list)
	_clear_technique_preview()
	var all_tech_keys: Array[StringName] = data.get_all_technique_keys()
	_technique_header.text = "Techniques (%d total)" % all_tech_keys.size()
	for tech_key: StringName in all_tech_keys:
		var tech_data: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		if tech_data == null:
			continue
		_add_technique_row(tech_data)


func _add_ability_card(slot: int, adata: AbilityData) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var slot_label := Label.new()
	slot_label.custom_minimum_size = Vector2(50, 0)
	slot_label.text = "Slot %d:" % slot
	slot_label.add_theme_color_override("font_color", Color(0.631, 0.631, 0.667, 1))
	slot_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(slot_label)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = adata.name
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)

	if adata.description != "":
		var desc_label := Label.new()
		desc_label.text = adata.description
		desc_label.add_theme_color_override("font_color", Color(0.631, 0.631, 0.667, 1))
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_label)

	hbox.add_child(info_vbox)
	_abilities_container.add_child(hbox)


func _add_technique_row(tech_data: TechniqueData) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	# Element icon
	var element_enum: Variant = Registry.ELEMENT_KEY_MAP.get(tech_data.element_key)
	if element_enum != null:
		var icon_tex: Texture2D = Registry.ELEMENT_ICONS.get(element_enum) as Texture2D
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(16, 16)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = icon_tex
			hbox.add_child(icon_rect)

	# Name
	var name_label := Label.new()
	name_label.text = tech_data.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_label)

	# Class
	var class_label := Label.new()
	class_label.text = Registry.technique_class_labels.get(tech_data.technique_class, "")
	class_label.add_theme_color_override("font_color", Color(0.631, 0.631, 0.667, 1))
	class_label.add_theme_font_size_override("font_size", 13)
	class_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(class_label)

	# Power
	var power_label := Label.new()
	power_label.text = "Pow: %d" % tech_data.power if tech_data.power > 0 else "—"
	power_label.add_theme_color_override("font_color", Color(0.631, 0.631, 0.667, 1))
	power_label.add_theme_font_size_override("font_size", 13)
	power_label.custom_minimum_size = Vector2(60, 0)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(power_label)

	_technique_preview_container.add_child(hbox)


func _add_stat_bar(stat_name: String, value: int) -> void:
	var hbox := HBoxContainer.new()

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_label)

	var bar := ProgressBar.new()
	bar.max_value = 255.0
	bar.value = float(value)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	var colour: Color = _stat_bar_colour(value)
	bar.add_theme_stylebox_override("fill", _create_flat_stylebox(colour))
	hbox.add_child(bar)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(value)
	value_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(value_label)

	_stat_bars.add_child(hbox)


func _stat_bar_colour(value: int) -> Color:
	if value < 50:
		return Color(0.85, 0.25, 0.25)  # Red
	elif value < 80:
		return Color(0.9, 0.55, 0.2)    # Orange
	elif value < 100:
		return Color(0.9, 0.85, 0.2)    # Yellow
	elif value < 130:
		return Color(0.3, 0.75, 0.3)    # Green
	else:
		return Color(0.3, 0.5, 0.85)    # Blue


func _create_flat_stylebox(colour: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colour
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb


# --- Transition to Configure ---


func _on_add_pressed() -> void:
	if _selected_key == &"":
		return
	if _species_only:
		_confirm_species_only()
		return
	_enter_config_stage()


## In species-only mode, return a minimal DigimonState with just the key set.
## The caller (e.g. WildBattleTestScreen) uses only the key for its encounter table.
func _confirm_species_only() -> void:
	var state := DigimonState.new()
	state.key = _selected_key
	Game.picker_result = state
	var return_path: String = Game.picker_context.get(
		"return_scene", BUILDER_SCENE_PATH
	)
	SceneManager.change_scene(return_path)


func _enter_config_stage(existing_state: DigimonState = null) -> void:
	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	_config_title.text = "Configure %s" % data.display_name

	if existing_state != null:
		_pending_state = existing_state
	else:
		var level: int = int(_level_slider.value)
		_pending_state = DigimonFactory.create_digimon_with_history(
			_selected_key, level,
		)
		if _pending_state == null:
			return

	# Set TP slider from pending state
	_tp_slider.value = _pending_state.training_points
	_tp_value_label.text = str(_pending_state.training_points)

	# Populate ability buttons
	_selected_ability_slot = existing_state.active_ability_slot if existing_state else 1
	_populate_abilities(data)

	# Build IV sliders
	_build_stat_sliders(_iv_sliders, _iv_slider_map, _max_iv, _pending_state.ivs)

	# Build TV sliders
	_build_stat_sliders(_tv_sliders, _tv_slider_map, _max_tv, _pending_state.tvs)

	# Populate technique buttons at current level
	var preselect: Array[StringName] = []
	if existing_state != null:
		preselect = existing_state.equipped_technique_keys
	_populate_techniques(preselect)

	# Populate gear dropdowns
	var preselect_equipable: StringName = existing_state.equipped_gear_key if existing_state else &""
	var preselect_consumable: StringName = existing_state.equipped_consumable_key if existing_state else &""
	_populate_gear_options(preselect_equipable, preselect_consumable)

	_set_stage(Stage.CONFIGURE)


func _populate_abilities(data: DigimonData) -> void:
	for child: Node in _ability_buttons.get_children():
		child.queue_free()

	var slots: Array[StringName] = [
		data.ability_slot_1_key,
		data.ability_slot_2_key,
		data.ability_slot_3_key,
	]
	for i: int in slots.size():
		var ability_key: StringName = slots[i]
		if ability_key == &"":
			continue
		var ability_data: AbilityData = Atlas.abilities.get(ability_key) as AbilityData
		if ability_data == null:
			continue
		var slot_num: int = i + 1
		_add_ability_button(slot_num, ability_data)


func _add_ability_button(slot: int, adata: AbilityData) -> void:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.button_pressed = (slot == _selected_ability_slot)

	# Build label text
	var label_text: String = adata.name
	if adata.description != "":
		label_text += "  —  %s" % adata.description
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 14)

	btn.pressed.connect(func() -> void:
		_selected_ability_slot = slot
		_refresh_ability_buttons()
	)

	_ability_buttons.add_child(btn)


func _refresh_ability_buttons() -> void:
	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return
	var slots: Array[StringName] = [
		data.ability_slot_1_key,
		data.ability_slot_2_key,
		data.ability_slot_3_key,
	]
	var btn_idx: int = 0
	for i: int in slots.size():
		if slots[i] == &"":
			continue
		var slot_num: int = i + 1
		if btn_idx < _ability_buttons.get_child_count():
			var btn: Button = _ability_buttons.get_child(btn_idx) as Button
			btn.button_pressed = (slot_num == _selected_ability_slot)
		btn_idx += 1


func _build_stat_sliders(
	container: VBoxContainer,
	slider_map: Dictionary,
	max_val: int,
	values: Dictionary,
) -> void:
	# Clear existing
	for child: Node in container.get_children():
		child.queue_free()
	slider_map.clear()

	for stat_key: StringName in STAT_KEYS:
		var hbox := HBoxContainer.new()

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.text = STAT_DISPLAY_NAMES[stat_key]
		hbox.add_child(name_label)

		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = max_val
		slider.value = int(values.get(stat_key, 0))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.step = 1
		hbox.add_child(slider)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(40, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = str(int(slider.value))
		hbox.add_child(value_label)

		# Connect slider to update label
		slider.value_changed.connect(
			func(val: float) -> void: value_label.text = str(int(val))
		)

		container.add_child(hbox)
		slider_map[stat_key] = {"slider": slider, "label": value_label}


func _populate_techniques(preselect_keys: Array[StringName] = []) -> void:
	for child: Node in _technique_buttons.get_children():
		child.queue_free()

	_selected_technique_keys.clear()
	_available_technique_keys.clear()

	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	var level: int = int(_level_slider.value)
	_available_technique_keys = data.get_technique_keys_at_level(level)

	for i: int in _available_technique_keys.size():
		var tech_key: StringName = _available_technique_keys[i]
		var tech_data: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		var selected: bool = false
		if preselect_keys.size() > 0:
			selected = tech_key in preselect_keys
		else:
			selected = i < _max_equipped

		if selected:
			_selected_technique_keys.append(tech_key)

		_add_technique_button(tech_key, tech_data, selected)


func _add_technique_button(tech_key: StringName, tech_data: TechniqueData, selected: bool) -> void:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = selected
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Build an HBox inside the button via a custom approach:
	# Use text with details since buttons don't support child layouts easily
	var display: String = tech_data.display_name if tech_data else str(tech_key)
	var details: String = ""
	if tech_data:
		var class_text: String = Registry.technique_class_labels.get(
			tech_data.technique_class, ""
		)
		var power_text: String = "Pow: %d" % tech_data.power if tech_data.power > 0 else "—"
		details = "  [%s | %d EN | %s]" % [class_text, tech_data.energy_cost, power_text]
	btn.text = display + details
	btn.add_theme_font_size_override("font_size", 14)

	# Element icon
	if tech_data:
		var element_enum: Variant = Registry.ELEMENT_KEY_MAP.get(tech_data.element_key)
		if element_enum != null:
			var icon_tex: Texture2D = Registry.ELEMENT_ICONS.get(element_enum) as Texture2D
			if icon_tex:
				btn.icon = icon_tex
				btn.expand_icon = true

	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			if _selected_technique_keys.size() >= _max_equipped:
				# At limit — reject the toggle
				btn.button_pressed = false
				return
			if tech_key not in _selected_technique_keys:
				_selected_technique_keys.append(tech_key)
		else:
			_selected_technique_keys.erase(tech_key)
	)

	_technique_buttons.add_child(btn)


func _populate_gear_options(
	preselect_equipable: StringName = &"",
	preselect_consumable: StringName = &"",
) -> void:
	_equipable_gear_option.clear()
	_consumable_gear_option.clear()
	_equipable_gear_keys.clear()
	_consumable_gear_keys.clear()

	# Collect gear items from Atlas, split by slot
	var equipable_list: Array[Dictionary] = []
	var consumable_list: Array[Dictionary] = []
	for item_key: StringName in Atlas.items:
		var item: Resource = Atlas.items[item_key]
		if not item is GearData:
			continue
		var gear: GearData = item as GearData
		var entry: Dictionary = {"key": gear.key, "name": gear.name}
		if gear.gear_slot == Registry.GearSlot.EQUIPABLE:
			equipable_list.append(entry)
		elif gear.gear_slot == Registry.GearSlot.CONSUMABLE:
			consumable_list.append(entry)

	# Sort alphabetically
	equipable_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["name"] as String).naturalnocasecmp_to(b["name"] as String) < 0
	)
	consumable_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["name"] as String).naturalnocasecmp_to(b["name"] as String) < 0
	)

	# Populate equipable dropdown
	_equipable_gear_keys.append(&"")
	_equipable_gear_option.add_item("None")
	for entry: Dictionary in equipable_list:
		_equipable_gear_keys.append(entry["key"] as StringName)
		_equipable_gear_option.add_item(entry["name"] as String)

	# Populate consumable dropdown
	_consumable_gear_keys.append(&"")
	_consumable_gear_option.add_item("None")
	for entry: Dictionary in consumable_list:
		_consumable_gear_keys.append(entry["key"] as StringName)
		_consumable_gear_option.add_item(entry["name"] as String)

	# Pre-select existing gear
	if preselect_equipable != &"":
		var idx: int = _equipable_gear_keys.find(preselect_equipable)
		if idx >= 0:
			_equipable_gear_option.selected = idx
	if preselect_consumable != &"":
		var idx: int = _consumable_gear_keys.find(preselect_consumable)
		if idx >= 0:
			_consumable_gear_option.selected = idx


func _on_level_changed(value: float) -> void:
	_level_value_label.text = str(int(value))
	if _stage == Stage.CONFIGURE:
		_populate_techniques()


func _on_tp_changed(value: float) -> void:
	_tp_value_label.text = str(int(value))


# --- Config Stage Buttons ---


func _on_back_pressed() -> void:
	_pending_state = null
	_set_stage(Stage.BROWSE)


func _on_confirm() -> void:
	if _selected_key == &"" or _pending_state == null:
		return

	var level: int = int(_level_slider.value)
	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	# Recreate state at configured level (with evolution history backfill)
	_pending_state = DigimonFactory.create_digimon_with_history(
		_selected_key, level,
	)
	if _pending_state == null:
		return

	# Override IVs from sliders
	for stat_key: StringName in STAT_KEYS:
		if _iv_slider_map.has(stat_key):
			var entry: Dictionary = _iv_slider_map[stat_key]
			var slider: HSlider = entry["slider"] as HSlider
			_pending_state.ivs[stat_key] = int(slider.value)

	# Override TVs from sliders, enforcing global TV cap
	var tv_total: int = 0
	for stat_key: StringName in STAT_KEYS:
		if _tv_slider_map.has(stat_key):
			var entry: Dictionary = _tv_slider_map[stat_key]
			var slider: HSlider = entry["slider"] as HSlider
			var tv_val: int = int(slider.value)
			var headroom: int = maxi(_max_total_tvs - tv_total, 0)
			tv_val = mini(tv_val, headroom)
			_pending_state.tvs[stat_key] = tv_val
			tv_total += tv_val

	# Recalculate HP and energy with overridden IVs/TVs
	_pending_state.current_hp = StatCalculator.calculate_stat(
		data.base_hp, _pending_state.ivs.get(&"hp", 0),
		_pending_state.tvs.get(&"hp", 0), level
	)
	_pending_state.current_energy = StatCalculator.calculate_stat(
		data.base_energy, _pending_state.ivs.get(&"energy", 0),
		_pending_state.tvs.get(&"energy", 0), level
	)

	# Override equipped techniques with user selection
	_pending_state.equipped_technique_keys.clear()
	_pending_state.known_technique_keys.clear()

	# Add all available as known
	for tech_key: StringName in _available_technique_keys:
		_pending_state.known_technique_keys.append(tech_key)

	# Add selected as equipped
	for tech_key: StringName in _selected_technique_keys:
		_pending_state.equipped_technique_keys.append(tech_key)

	# Set ability slot
	_pending_state.active_ability_slot = _selected_ability_slot

	# Set training points from slider
	_pending_state.training_points = int(_tp_slider.value)

	# Set equipped gear from dropdowns
	var eq_idx: int = _equipable_gear_option.selected
	if eq_idx >= 0 and eq_idx < _equipable_gear_keys.size():
		_pending_state.equipped_gear_key = _equipable_gear_keys[eq_idx]
	var con_idx: int = _consumable_gear_option.selected
	if con_idx >= 0 and con_idx < _consumable_gear_keys.size():
		_pending_state.equipped_consumable_key = _consumable_gear_keys[con_idx]

	Game.picker_result = _pending_state
	_pending_state = null
	var return_path: String = Game.picker_context.get(
		"return_scene", BUILDER_SCENE_PATH
	)
	SceneManager.change_scene(return_path)


func _on_cancel() -> void:
	_pending_state = null
	Game.picker_result = null
	var return_path: String = Game.picker_context.get(
		"return_scene", BUILDER_SCENE_PATH
	)
	SceneManager.change_scene(return_path)
