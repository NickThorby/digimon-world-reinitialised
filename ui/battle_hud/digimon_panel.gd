class_name DigimonPanel
extends PanelContainer
## Displays name, level, HP bar, energy bar, and status icons for one Digimon.


@onready var _name_label: Label = $VBox/TopRow/NameLabel
@onready var _level_label: Label = $VBox/TopRow/LevelLabel
@onready var _hp_bar: ProgressBar = $VBox/HPRow/HPBar
@onready var _hp_label: Label = $VBox/HPRow/HPLabel
@onready var _energy_bar: ProgressBar = $VBox/EnergyRow/EnergyBar
@onready var _energy_label: Label = $VBox/EnergyRow/EnergyLabel
@onready var _status_label: Label = $VBox/StatusLabel

var _tween: Tween = null


## Update the panel with a BattleDigimonState.
func update_from_battle_digimon(digimon: BattleDigimonState) -> void:
	if digimon == null:
		_name_label.text = ""
		_level_label.text = ""
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

	# Animate bars
	_animate_bar(_hp_bar, float(digimon.current_hp))
	_animate_bar(_energy_bar, float(digimon.current_energy))


func _animate_bar(bar: ProgressBar, target_value: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(bar, "value", target_value, 0.3)
