class_name DigimonPanel
extends PanelContainer
## Displays name, level, HP bar, energy bar, and status icons for one Digimon.


const HP_COLOUR_GREEN := Color(0.133, 0.773, 0.369)
const HP_COLOUR_YELLOW := Color(0.918, 0.702, 0.031)
const HP_COLOUR_RED := Color(0.937, 0.267, 0.267)
const ENERGY_COLOUR := Color(0.231, 0.510, 0.965)

@onready var _name_label: Label = $VBox/TopRow/NameLabel
@onready var _level_label: Label = $VBox/TopRow/LevelLabel
@onready var _element_icon: TextureRect = $VBox/TopRow/ElementIcon
@onready var _hp_bar: ProgressBar = $VBox/HPRow/HPBar
@onready var _hp_label: Label = $VBox/HPRow/HPLabel
@onready var _energy_bar: ProgressBar = $VBox/EnergyRow/EnergyBar
@onready var _energy_label: Label = $VBox/EnergyRow/EnergyLabel
@onready var _status_label: Label = $VBox/StatusLabel

var _hp_tween: Tween = null
var _energy_tween: Tween = null
var _hp_fill_style: StyleBoxFlat = null
var _energy_fill_style: StyleBoxFlat = null


func _ready() -> void:
	_setup_bar_styles()


func _setup_bar_styles() -> void:
	# Create unique fill styleboxes so we can tween colours per-panel
	_hp_fill_style = StyleBoxFlat.new()
	_hp_fill_style.bg_color = HP_COLOUR_GREEN
	_hp_fill_style.corner_radius_top_left = 4
	_hp_fill_style.corner_radius_top_right = 4
	_hp_fill_style.corner_radius_bottom_right = 4
	_hp_fill_style.corner_radius_bottom_left = 4
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)

	_energy_fill_style = StyleBoxFlat.new()
	_energy_fill_style.bg_color = ENERGY_COLOUR
	_energy_fill_style.corner_radius_top_left = 4
	_energy_fill_style.corner_radius_top_right = 4
	_energy_fill_style.corner_radius_bottom_right = 4
	_energy_fill_style.corner_radius_bottom_left = 4
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill_style)


## Update the panel with a BattleDigimonState.
func update_from_battle_digimon(digimon: BattleDigimonState) -> void:
	if digimon == null:
		_name_label.text = ""
		_level_label.text = ""
		_element_icon.texture = null
		_hp_bar.value = 0
		_hp_label.text = ""
		_energy_bar.value = 0
		_energy_label.text = ""
		_status_label.text = ""
		return

	# Name
	if digimon.source_state != null and digimon.source_state.nickname != "":
		_name_label.text = digimon.source_state.nickname
	elif digimon.data != null:
		_name_label.text = digimon.data.display_name
	else:
		_name_label.text = "???"

	_level_label.text = "Lv. %d" % (
		digimon.source_state.level if digimon.source_state else 1
	)

	# Element icon — show primary element trait
	_update_element_icon(digimon)

	# HP
	_hp_bar.max_value = digimon.max_hp
	_hp_label.text = "%d / %d" % [digimon.current_hp, digimon.max_hp]

	# Energy
	_energy_bar.max_value = digimon.max_energy
	_energy_label.text = "%d / %d" % [digimon.current_energy, digimon.max_energy]

	# Status conditions
	var statuses: Array[String] = []
	for status: Dictionary in digimon.status_conditions:
		statuses.append(str(status.get("key", "")).capitalize())
	_status_label.text = " ".join(statuses) if statuses.size() > 0 else ""

	# Animate bars independently
	_animate_hp(float(digimon.current_hp))
	_animate_energy(float(digimon.current_energy))

	# Update HP bar colour
	_update_hp_colour(digimon.current_hp, digimon.max_hp)


## Update the panel from a snapshot dictionary captured at signal time.
func update_from_snapshot(snapshot: Dictionary) -> void:
	_name_label.text = snapshot.get("name", "???") as String
	_level_label.text = "Lv. %d" % int(snapshot.get("level", 1))

	var max_hp: int = int(snapshot.get("max_hp", 1))
	var current_hp: int = int(snapshot.get("current_hp", 0))
	_hp_bar.max_value = max_hp
	_hp_label.text = "%d / %d" % [current_hp, max_hp]

	var max_energy: int = int(snapshot.get("max_energy", 1))
	var current_energy: int = int(snapshot.get("current_energy", 0))
	_energy_bar.max_value = max_energy
	_energy_label.text = "%d / %d" % [current_energy, max_energy]

	var statuses: Array[String] = []
	var status_conditions: Array = snapshot.get("status_conditions", []) as Array
	for status: Dictionary in status_conditions:
		statuses.append(str(status.get("key", "")).capitalize())
	_status_label.text = " ".join(statuses) if statuses.size() > 0 else ""

	_animate_hp(float(current_hp))
	_animate_energy(float(current_energy))

	# Update HP bar colour
	_update_hp_colour(current_hp, max_hp)


func _animate_hp(target_value: float) -> void:
	if _hp_tween != null:
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(_hp_bar, "value", target_value, 0.3)


func _animate_energy(target_value: float) -> void:
	if _energy_tween != null:
		_energy_tween.kill()
	_energy_tween = create_tween()
	_energy_tween.tween_property(_energy_bar, "value", target_value, 0.3)


func _update_hp_colour(current_hp: int, max_hp: int) -> void:
	if _hp_fill_style == null or max_hp <= 0:
		return
	var ratio: float = float(current_hp) / float(max_hp)
	var target_colour: Color
	if ratio > 0.5:
		target_colour = HP_COLOUR_GREEN
	elif ratio > 0.25:
		target_colour = HP_COLOUR_YELLOW
	else:
		target_colour = HP_COLOUR_RED
	_hp_fill_style.bg_color = target_colour


func _update_element_icon(digimon: BattleDigimonState) -> void:
	if digimon.data == null:
		_element_icon.texture = null
		return
	if digimon.data.element_traits.size() > 0:
		var element_key: StringName = digimon.data.element_traits[0]
		var element_enum: Variant = Registry.ELEMENT_KEY_MAP.get(element_key)
		if element_enum != null:
			_element_icon.texture = Registry.ELEMENT_ICONS.get(
				element_enum as Registry.Element
			) as Texture2D
			return
	_element_icon.texture = null
