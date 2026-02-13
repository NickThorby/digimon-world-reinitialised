class_name DigimonSlotPanel
extends PanelContainer
## Compact widget showing one Digimon in a team slot.
## Displays name, level, element icons, HP/XP bars, statuses, and edit/remove buttons.
## Supports drag-and-drop reordering.


signal edit_pressed(index: int)
signal remove_pressed(index: int)
signal reorder_requested(from_index: int, to_index: int)
signal slot_clicked(index: int)

enum ButtonMode { EDIT_REMOVE, CONTEXT_MENU, HIDDEN }

const HP_COLOUR_GREEN := Color(0.133, 0.773, 0.369)
const HP_COLOUR_YELLOW := Color(0.918, 0.702, 0.031)
const HP_COLOUR_RED := Color(0.937, 0.267, 0.267)
const XP_COLOUR := Color(0.024, 0.714, 0.831)
const ENERGY_COLOUR := Color(0.647, 0.318, 0.878)

@onready var _sprite_rect: TextureRect = $HBox/SpriteRect
@onready var _name_label: Label = $HBox/InfoVBox/TopRow/NameLabel
@onready var _level_label: Label = $HBox/InfoVBox/TopRow/LevelLabel
@onready var _element_label: Label = $HBox/InfoVBox/ElementLabel
@onready var _hp_bar: ProgressBar = $HBox/InfoVBox/HPBarRow/HPBar
@onready var _hp_value_label: Label = $HBox/InfoVBox/HPBarRow/HPValueLabel
@onready var _energy_bar_row: HBoxContainer = $HBox/InfoVBox/EnergyBarRow
@onready var _energy_bar: ProgressBar = $HBox/InfoVBox/EnergyBarRow/EnergyBar
@onready var _energy_value_label: Label = $HBox/InfoVBox/EnergyBarRow/EnergyValueLabel
@onready var _xp_bar: ProgressBar = $HBox/InfoVBox/XPBarRow/XPBar
@onready var _status_label: Label = $HBox/InfoVBox/StatusLabel
@onready var _edit_button: Button = $HBox/ButtonVBox/EditButton
@onready var _remove_button: Button = $HBox/ButtonVBox/RemoveButton

var _index: int = -1
var _digimon_state: DigimonState = null
var _button_mode: ButtonMode = ButtonMode.EDIT_REMOVE
var _hp_tween: Tween = null
var _energy_tween: Tween = null


func setup(index: int, state: DigimonState) -> void:
	_index = index
	_digimon_state = state
	if is_node_ready():
		_update_display()


func _ready() -> void:
	_edit_button.pressed.connect(_on_edit_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_setup_bar_styles()
	_apply_button_mode()
	_update_display()


func set_button_mode(mode: ButtonMode) -> void:
	_button_mode = mode
	if is_node_ready():
		_apply_button_mode()


func set_sprite_flipped(flipped: bool) -> void:
	if _sprite_rect:
		_sprite_rect.flip_h = flipped


func set_greyed_out(greyed: bool) -> void:
	modulate.a = 0.4 if greyed else 1.0


func get_digimon_state() -> DigimonState:
	return _digimon_state


func _setup_bar_styles() -> void:
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = HP_COLOUR_GREEN
	hp_fill.corner_radius_top_left = 2
	hp_fill.corner_radius_top_right = 2
	hp_fill.corner_radius_bottom_left = 2
	hp_fill.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)

	var energy_fill := StyleBoxFlat.new()
	energy_fill.bg_color = ENERGY_COLOUR
	energy_fill.corner_radius_top_left = 2
	energy_fill.corner_radius_top_right = 2
	energy_fill.corner_radius_bottom_left = 2
	energy_fill.corner_radius_bottom_right = 2
	_energy_bar.add_theme_stylebox_override("fill", energy_fill)

	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = XP_COLOUR
	xp_fill.corner_radius_top_left = 2
	xp_fill.corner_radius_top_right = 2
	xp_fill.corner_radius_bottom_left = 2
	xp_fill.corner_radius_bottom_right = 2
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)


func _update_display() -> void:
	if _digimon_state == null:
		_name_label.text = tr("(Empty)")
		_level_label.text = ""
		_element_label.text = ""
		_sprite_rect.texture = null
		_hp_bar.value = 0
		_hp_value_label.text = ""
		_xp_bar.value = 0
		_status_label.text = ""
		return

	var data: DigimonData = Atlas.digimon.get(_digimon_state.key) as DigimonData
	if data == null:
		_name_label.text = str(_digimon_state.key)
		_level_label.text = "Lv. %d" % _digimon_state.level
		_element_label.text = ""
		_sprite_rect.texture = null
		_hp_bar.value = 0
		_hp_value_label.text = ""
		_xp_bar.value = 0
		_status_label.text = ""
		return

	_name_label.text = data.display_name
	_level_label.text = "Lv. %d" % _digimon_state.level
	_sprite_rect.texture = data.sprite_texture
	var elements: Array[String] = []
	for element_key: StringName in data.element_traits:
		elements.append(str(element_key).capitalize())
	_element_label.text = " / ".join(elements) if elements.size() > 0 else "—"

	_update_hp_bar(data)
	_update_energy_bar(data)
	_update_xp_bar(data)
	_update_status_display()


func _update_hp_bar(data: DigimonData) -> void:
	var stats: Dictionary = StatCalculator.calculate_all_stats(data, _digimon_state)
	var personality: PersonalityData = Atlas.personalities.get(
		_digimon_state.get_effective_personality_key(),
	) as PersonalityData
	var max_hp: int = StatCalculator.apply_personality(
		stats.get(&"hp", 1), &"hp", personality,
	)
	var current_hp: int = _digimon_state.current_hp

	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_value_label.text = "%d / %d" % [current_hp, max_hp]
	_update_hp_colour(current_hp)


func _update_energy_bar(data: DigimonData) -> void:
	var stats: Dictionary = StatCalculator.calculate_all_stats(data, _digimon_state)
	var personality: PersonalityData = Atlas.personalities.get(
		_digimon_state.get_effective_personality_key(),
	) as PersonalityData
	var max_energy: int = StatCalculator.apply_personality(
		stats.get(&"energy", 1), &"energy", personality,
	)
	var current_energy: int = _digimon_state.current_energy

	_energy_bar.max_value = max_energy
	_energy_bar.value = current_energy
	_energy_value_label.text = "%d / %d" % [current_energy, max_energy]


func set_energy_bar_visible(show: bool) -> void:
	if _energy_bar_row:
		_energy_bar_row.visible = show


func _update_hp_colour(current_hp: int) -> void:
	var max_hp: int = int(_hp_bar.max_value) if _hp_bar.max_value > 0 else 1
	var ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var fill: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		if ratio > 0.5:
			fill.bg_color = HP_COLOUR_GREEN
		elif ratio > 0.25:
			fill.bg_color = HP_COLOUR_YELLOW
		else:
			fill.bg_color = HP_COLOUR_RED


## Animates the HP bar to a target value over 0.3 seconds.
func animate_hp_to(target: int) -> void:
	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(_hp_bar, "value", float(target), 0.3)
	_hp_tween.tween_callback(func() -> void:
		_hp_value_label.text = "%d / %d" % [target, int(_hp_bar.max_value)]
		_update_hp_colour(target)
	)


## Animates the energy bar to a target value over 0.3 seconds.
func animate_energy_to(target: int) -> void:
	if _energy_tween and _energy_tween.is_valid():
		_energy_tween.kill()
	_energy_tween = create_tween()
	_energy_tween.tween_property(_energy_bar, "value", float(target), 0.3)
	_energy_tween.tween_callback(func() -> void:
		_energy_value_label.text = "%d / %d" % [target, int(_energy_bar.max_value)]
	)


## Public wrapper to re-run _update_display for the current state.
func refresh_display() -> void:
	_update_display()


func _update_xp_bar(data: DigimonData) -> void:
	var level: int = _digimon_state.level
	var current_xp: int = _digimon_state.experience
	var current_threshold: int = XPCalculator.total_xp_for_level(
		level, data.growth_rate,
	)
	var next_threshold: int = XPCalculator.total_xp_for_level(
		level + 1, data.growth_rate,
	)

	if next_threshold <= current_threshold:
		# Max level — show full bar
		_xp_bar.max_value = 1
		_xp_bar.value = 1
		return

	var level_range: int = next_threshold - current_threshold
	var progress: int = current_xp - current_threshold
	_xp_bar.max_value = level_range
	_xp_bar.value = clampi(progress, 0, level_range)


func _update_status_display() -> void:
	if _digimon_state.status_conditions.is_empty():
		_status_label.text = ""
		_status_label.visible = false
		return
	var names: Array[String] = []
	for condition: Dictionary in _digimon_state.status_conditions:
		var key: String = str(condition.get("key", ""))
		if key != "":
			names.append(key.capitalize())
	_status_label.text = ", ".join(names)
	_status_label.visible = names.size() > 0


# --- Drag-and-drop reordering ---


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _digimon_state == null:
		return null
	var preview := Label.new()
	preview.text = _name_label.text
	preview.modulate = Color(1, 1, 1, 0.7)
	set_drag_preview(preview)
	return {"slot_index": _index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is not Dictionary:
		return false
	return (data as Dictionary).has("slot_index") \
		and int((data as Dictionary)["slot_index"]) != _index


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and (data as Dictionary).has("slot_index"):
		reorder_requested.emit(
			int((data as Dictionary)["slot_index"]), _index,
		)


func _on_edit_pressed() -> void:
	edit_pressed.emit(_index)


func _on_remove_pressed() -> void:
	remove_pressed.emit(_index)


func _apply_button_mode() -> void:
	var button_vbox: VBoxContainer = $HBox/ButtonVBox
	match _button_mode:
		ButtonMode.EDIT_REMOVE:
			button_vbox.visible = true
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		ButtonMode.CONTEXT_MENU:
			button_vbox.visible = false
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ButtonMode.HIDDEN:
			button_vbox.visible = false
			mouse_default_cursor_shape = Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if _button_mode != ButtonMode.CONTEXT_MENU:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(_index)
			accept_event()
