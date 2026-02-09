class_name DigimonPickerPopup
extends Window
## Two-stage Digimon picker: browse/preview, then configure before adding.


signal digimon_confirmed(state: DigimonState)
signal cancelled

# --- Stage enum ---

enum Stage { BROWSE, CONFIGURE }

# --- Browse stage nodes ---

@onready var _search_field: LineEdit = $MarginContainer/VBox/HSplit/LeftPanel/SearchField
@onready var _species_list: ItemList = $MarginContainer/VBox/HSplit/LeftPanel/SpeciesList
@onready var _preview_panel: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel
@onready var _sprite_preview: TextureRect = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/SpritePreview
@onready var _name_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/InfoVBox/NameLabel
@onready var _attribute_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/InfoVBox/AttributeLabel
@onready var _element_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/HeaderRow/InfoVBox/ElementLabel
@onready var _stat_bars: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/StatsSection/StatBars
@onready var _bst_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/StatsSection/BSTLabel
@onready var _abilities_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/AbilitiesLabel
@onready var _technique_count_label: Label = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/TechniqueCountLabel

# --- Configure stage nodes ---

@onready var _config_panel: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel
@onready var _config_title: Label = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigTitle
@onready var _level_spinbox: SpinBox = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/LevelRow/LevelSpinBox
@onready var _ability_option: OptionButton = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/AbilityRow/AbilityOption
@onready var _iv_sliders: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/IVSection/IVSliders
@onready var _tv_sliders: VBoxContainer = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/TVSection/TVSliders
@onready var _technique_list: ItemList = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigScroll/ScrollVBox/TechniqueSection/TechniqueList
@onready var _back_button: Button = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigButtonRow/BackButton
@onready var _confirm_button: Button = $MarginContainer/VBox/HSplit/RightPanel/ConfigPanel/ConfigButtonRow/ConfirmButton

# --- Bottom buttons ---

@onready var _add_button: Button = $MarginContainer/VBox/ButtonRow/AddButton
@onready var _cancel_button: Button = $MarginContainer/VBox/ButtonRow/CancelButton

# --- State ---

var _filtered_keys: Array[StringName] = []
var _selected_key: StringName = &""
var _stage: Stage = Stage.BROWSE
var _max_equipped: int = 4
var _max_iv: int = 50
var _max_tv: int = 500
var _max_level: int = 100

## Pending state created by DigimonFactory, modified by config sliders.
var _pending_state: DigimonState = null

## Slider references for reading values: stat_key -> { "slider": HSlider, "label": Label }
var _iv_slider_map: Dictionary = {}
var _tv_slider_map: Dictionary = {}

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


func _ready() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	if balance:
		_max_equipped = balance.max_equipped_techniques
		_max_level = balance.max_level
		_max_iv = balance.max_iv
		_max_tv = balance.max_tv

	_level_spinbox.min_value = 1
	_level_spinbox.max_value = _max_level
	_level_spinbox.value = 5
	_technique_list.select_mode = ItemList.SELECT_MULTI

	_search_field.text_changed.connect(_on_search_changed)
	_species_list.item_selected.connect(_on_species_selected)
	_add_button.pressed.connect(_on_add_pressed)
	_cancel_button.pressed.connect(_on_cancel)
	_back_button.pressed.connect(_on_back_pressed)
	_confirm_button.pressed.connect(_on_confirm)
	_level_spinbox.value_changed.connect(_on_level_changed)
	_technique_list.multi_selected.connect(_on_technique_multi_selected)
	close_requested.connect(_on_cancel)

	_populate_species_list("")
	_set_stage(Stage.BROWSE)
	_clear_preview()


## Prepopulate the picker with an existing DigimonState for editing.
## Call after instantiation, before popup_centered().
func prepopulate(state: DigimonState) -> void:
	_selected_key = state.key
	# Find and highlight species in list
	for i: int in _filtered_keys.size():
		if _filtered_keys[i] == state.key:
			_species_list.select(i)
			break
	_update_preview()
	_level_spinbox.value = state.level
	_enter_config_stage(state)


## --- Stage Management ---


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


## --- Browse Stage ---


func _populate_species_list(filter_text: String) -> void:
	_species_list.clear()
	_filtered_keys.clear()

	var filter_lower: String = filter_text.to_lower()
	var sorted_keys: Array = Atlas.digimon.keys()
	sorted_keys.sort()

	for digi_key: StringName in sorted_keys:
		var data: DigimonData = Atlas.digimon[digi_key] as DigimonData
		if data == null:
			continue
		var display: String = data.display_name
		if filter_lower == "" or display.to_lower().contains(filter_lower) or \
				str(digi_key).to_lower().contains(filter_lower):
			_species_list.add_item(display)
			_filtered_keys.append(digi_key)


func _on_search_changed(new_text: String) -> void:
	_populate_species_list(new_text)
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
	_attribute_label.text = ""
	_element_label.text = ""
	_bst_label.text = ""
	_abilities_label.text = ""
	_technique_count_label.text = ""
	_sprite_preview.texture = null
	_clear_stat_bars()


func _clear_stat_bars() -> void:
	for child: Node in _stat_bars.get_children():
		child.queue_free()


func _update_preview() -> void:
	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		_clear_preview()
		return

	_name_label.text = data.display_name
	_attribute_label.text = "Attribute: %s" % Registry.attribute_labels.get(
		data.attribute, "Unknown"
	)

	# Elements
	var elements: Array[String] = []
	for element_key: StringName in data.element_traits:
		elements.append(str(element_key).capitalize())
	_element_label.text = "Elements: %s" % (
		" / ".join(elements) if elements.size() > 0 else "—"
	)

	# Sprite
	_sprite_preview.texture = data.sprite_texture

	# Stat bars
	_clear_stat_bars()
	for stat_key: StringName in STAT_KEYS:
		var base_val: int = data.get(BASE_STAT_FIELDS[stat_key]) as int
		_add_stat_bar(STAT_DISPLAY_NAMES[stat_key], base_val)

	_bst_label.text = "BST: %d" % data.bst

	# Abilities
	var ability_parts: Array[String] = []
	var ability_slots: Array[StringName] = [
		data.ability_slot_1_key,
		data.ability_slot_2_key,
		data.ability_slot_3_key,
	]
	for i: int in ability_slots.size():
		var akey: StringName = ability_slots[i]
		if akey == &"":
			continue
		var adata: Resource = Atlas.abilities.get(akey)
		var aname: String = adata.name if adata and "name" in adata else str(akey)
		ability_parts.append("Slot %d: %s" % [i + 1, aname])
	_abilities_label.text = "Abilities: %s" % (
		", ".join(ability_parts) if ability_parts.size() > 0 else "—"
	)

	# Technique count
	var total_techs: int = data.get_all_technique_keys().size()
	_technique_count_label.text = "Techniques: %d total" % total_techs


func _add_stat_bar(stat_name: String, value: int) -> void:
	var hbox := HBoxContainer.new()

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(80, 0)
	name_label.text = stat_name
	hbox.add_child(name_label)

	var bar := ProgressBar.new()
	bar.max_value = 255.0
	bar.value = float(value)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	# Colour by value
	var colour: Color = _stat_bar_colour(value)
	bar.add_theme_stylebox_override("fill", _create_flat_stylebox(colour))
	hbox.add_child(bar)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(36, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(value)
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


## --- Transition to Configure ---


func _on_add_pressed() -> void:
	if _selected_key == &"":
		return
	_enter_config_stage()


func _enter_config_stage(existing_state: DigimonState = null) -> void:
	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	_config_title.text = "Configure %s" % data.display_name

	if existing_state != null:
		_pending_state = existing_state
	else:
		var level: int = int(_level_spinbox.value)
		_pending_state = DigimonFactory.create_digimon(_selected_key, level)
		if _pending_state == null:
			return

	# Populate ability options
	_populate_abilities(data)

	# Select ability matching existing state
	if existing_state != null:
		for i: int in _ability_option.item_count:
			if _ability_option.get_item_metadata(i) as int == existing_state.active_ability_slot:
				_ability_option.selected = i
				break

	# Build IV sliders
	_build_stat_sliders(_iv_sliders, _iv_slider_map, _max_iv, _pending_state.ivs)

	# Build TV sliders
	_build_stat_sliders(_tv_sliders, _tv_slider_map, _max_tv, _pending_state.tvs)

	# Populate techniques at current level
	var preselect: Array[StringName] = []
	if existing_state != null:
		preselect = existing_state.equipped_technique_keys
	_populate_techniques(preselect)

	_set_stage(Stage.CONFIGURE)


func _populate_abilities(data: DigimonData) -> void:
	_ability_option.clear()
	var slots: Array[StringName] = [
		data.ability_slot_1_key,
		data.ability_slot_2_key,
		data.ability_slot_3_key,
	]
	for i: int in slots.size():
		var ability_key: StringName = slots[i]
		if ability_key == &"":
			continue
		var ability_data: Resource = Atlas.abilities.get(ability_key)
		var label: String = ability_data.name if ability_data and "name" in ability_data \
			else str(ability_key)
		_ability_option.add_item("Slot %d: %s" % [i + 1, label])
		_ability_option.set_item_metadata(_ability_option.item_count - 1, i + 1)


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
		name_label.custom_minimum_size = Vector2(80, 0)
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
	_technique_list.clear()

	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	var level: int = int(_level_spinbox.value)
	var available_keys: Array[StringName] = data.get_technique_keys_at_level(level)

	for i: int in available_keys.size():
		var tech_key: StringName = available_keys[i]
		var tech_data: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		var label: String = tech_data.display_name if tech_data else str(tech_key)
		if tech_data:
			label += " [%s, %d EN, %d Pow]" % [
				Registry.technique_class_labels.get(tech_data.technique_class, ""),
				tech_data.energy_cost,
				tech_data.power,
			]
		_technique_list.add_item(label)
		if preselect_keys.size() > 0:
			if tech_key in preselect_keys:
				_technique_list.select(i, false)
		elif i < _max_equipped:
			_technique_list.select(i, false)


func _on_level_changed(_value: float) -> void:
	if _stage == Stage.CONFIGURE:
		_populate_techniques()


func _on_technique_multi_selected(index: int, _selected: bool) -> void:
	var selected_indices: Array[int] = []
	for i: int in _technique_list.item_count:
		if _technique_list.is_selected(i):
			selected_indices.append(i)

	if selected_indices.size() > _max_equipped:
		_technique_list.deselect(index)


## --- Config Stage Buttons ---


func _on_back_pressed() -> void:
	_pending_state = null
	_set_stage(Stage.BROWSE)


func _on_confirm() -> void:
	if _selected_key == &"" or _pending_state == null:
		return

	var level: int = int(_level_spinbox.value)
	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	# Recreate state at configured level
	_pending_state = DigimonFactory.create_digimon(_selected_key, level)
	if _pending_state == null:
		return

	# Override IVs from sliders
	for stat_key: StringName in STAT_KEYS:
		if _iv_slider_map.has(stat_key):
			var entry: Dictionary = _iv_slider_map[stat_key]
			var slider: HSlider = entry["slider"] as HSlider
			_pending_state.ivs[stat_key] = int(slider.value)

	# Override TVs from sliders
	for stat_key: StringName in STAT_KEYS:
		if _tv_slider_map.has(stat_key):
			var entry: Dictionary = _tv_slider_map[stat_key]
			var slider: HSlider = entry["slider"] as HSlider
			_pending_state.tvs[stat_key] = int(slider.value)

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
	var available_keys: Array[StringName] = data.get_technique_keys_at_level(level)
	_pending_state.equipped_technique_keys.clear()
	_pending_state.known_technique_keys.clear()

	# Add all available as known
	for tech_key: StringName in available_keys:
		_pending_state.known_technique_keys.append(tech_key)

	# Add selected as equipped
	for i: int in _technique_list.item_count:
		if _technique_list.is_selected(i) and i < available_keys.size():
			_pending_state.equipped_technique_keys.append(available_keys[i])

	# Set ability slot
	if _ability_option.item_count > 0:
		var selected_idx: int = _ability_option.selected
		if selected_idx >= 0:
			_pending_state.active_ability_slot = _ability_option.get_item_metadata(
				selected_idx
			) as int

	digimon_confirmed.emit(_pending_state)
	_pending_state = null
	hide()


func _on_cancel() -> void:
	_pending_state = null
	_set_stage(Stage.BROWSE)
	cancelled.emit()
	hide()
