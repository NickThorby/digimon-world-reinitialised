class_name DigimonPickerPopup
extends Window
## Modal popup for selecting and configuring a Digimon.
## Provides species search, level setting, and technique selection.


signal digimon_confirmed(state: DigimonState)
signal cancelled

@onready var _search_field: LineEdit = $MarginContainer/VBox/SearchField
@onready var _species_list: ItemList = $MarginContainer/VBox/SpeciesList
@onready var _level_spinbox: SpinBox = $MarginContainer/VBox/LevelRow/LevelSpinBox
@onready var _technique_list: ItemList = $MarginContainer/VBox/TechniqueList
@onready var _confirm_button: Button = $MarginContainer/VBox/ButtonRow/ConfirmButton
@onready var _cancel_button: Button = $MarginContainer/VBox/ButtonRow/CancelButton
@onready var _ability_option: OptionButton = $MarginContainer/VBox/AbilityRow/AbilityOption

var _filtered_keys: Array[StringName] = []
var _selected_key: StringName = &""
var _selected_techniques: Array[StringName] = []
var _max_equipped: int = 4


func _ready() -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
	if balance:
		_max_equipped = balance.max_equipped_techniques
		_level_spinbox.max_value = balance.max_level

	_search_field.text_changed.connect(_on_search_changed)
	_species_list.item_selected.connect(_on_species_selected)
	_technique_list.multi_selected.connect(_on_technique_multi_selected)
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_cancel)
	close_requested.connect(_on_cancel)

	_level_spinbox.min_value = 1
	_level_spinbox.value = 5
	_technique_list.select_mode = ItemList.SELECT_MULTI

	_populate_species_list("")


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
		var name: String = data.display_name
		if filter_lower == "" or name.to_lower().contains(filter_lower) or \
				str(digi_key).to_lower().contains(filter_lower):
			_species_list.add_item(name)
			_filtered_keys.append(digi_key)


func _on_search_changed(new_text: String) -> void:
	_populate_species_list(new_text)
	_selected_key = &""
	_technique_list.clear()
	_ability_option.clear()


func _on_species_selected(index: int) -> void:
	if index < 0 or index >= _filtered_keys.size():
		return
	_selected_key = _filtered_keys[index]
	_populate_techniques()
	_populate_abilities()


func _populate_techniques() -> void:
	_technique_list.clear()
	_selected_techniques.clear()

	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	var level: int = int(_level_spinbox.value)
	var available_keys: Array[StringName] = data.get_technique_keys_at_level(level)

	for tech_key: StringName in available_keys:
		var tech_data: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		var label: String = tech_data.display_name if tech_data else str(tech_key)
		if tech_data:
			label += " [%s, %d EN, %d Pow]" % [
				Registry.technique_class_labels.get(tech_data.technique_class, ""),
				tech_data.energy_cost,
				tech_data.power,
			]
		_technique_list.add_item(label)
		# Auto-select first techniques up to max
		if _selected_techniques.size() < _max_equipped:
			_technique_list.select(_technique_list.item_count - 1, false)
			_selected_techniques.append(tech_key)


func _populate_abilities() -> void:
	_ability_option.clear()

	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

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
		var label: String = ability_data.name if ability_data and "name" in ability_data else str(ability_key)
		_ability_option.add_item("Slot %d: %s" % [i + 1, label])
		_ability_option.set_item_metadata(_ability_option.item_count - 1, i + 1)


func _on_technique_multi_selected(index: int, _selected: bool) -> void:
	_selected_techniques.clear()

	var data: DigimonData = Atlas.digimon.get(_selected_key) as DigimonData
	if data == null:
		return

	var level: int = int(_level_spinbox.value)
	var available_keys: Array[StringName] = data.get_technique_keys_at_level(level)

	var selected_indices: Array[int] = []
	for i: int in _technique_list.item_count:
		if _technique_list.is_selected(i):
			selected_indices.append(i)

	# Enforce max selection
	if selected_indices.size() > _max_equipped:
		_technique_list.deselect(index)
		return

	for i: int in selected_indices:
		if i < available_keys.size():
			_selected_techniques.append(available_keys[i])


func _on_confirm() -> void:
	if _selected_key == &"":
		return

	var level: int = int(_level_spinbox.value)
	var state: DigimonState = DigimonFactory.create_digimon(_selected_key, level)
	if state == null:
		return

	# Override equipped techniques with user selection
	state.equipped_technique_keys.clear()
	for tech_key: StringName in _selected_techniques:
		state.equipped_technique_keys.append(tech_key)
		if tech_key not in state.known_technique_keys:
			state.known_technique_keys.append(tech_key)

	# Set ability slot
	if _ability_option.item_count > 0:
		var selected_idx: int = _ability_option.selected
		if selected_idx >= 0:
			state.active_ability_slot = _ability_option.get_item_metadata(selected_idx) as int

	digimon_confirmed.emit(state)
	hide()


func _on_cancel() -> void:
	cancelled.emit()
	hide()
