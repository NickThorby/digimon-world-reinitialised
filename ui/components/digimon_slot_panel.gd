class_name DigimonSlotPanel
extends PanelContainer
## Compact widget showing one Digimon in a team slot.
## Displays name, level, element icons, and edit/remove buttons.


signal edit_pressed(index: int)
signal remove_pressed(index: int)

@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _element_label: Label = %ElementLabel
@onready var _edit_button: Button = %EditButton
@onready var _remove_button: Button = %RemoveButton

var _index: int = -1
var _digimon_state: DigimonState = null


func setup(index: int, state: DigimonState) -> void:
	_index = index
	_digimon_state = state
	_update_display()


func _ready() -> void:
	_edit_button.pressed.connect(_on_edit_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)


func _update_display() -> void:
	if _digimon_state == null:
		_name_label.text = tr("(Empty)")
		_level_label.text = ""
		_element_label.text = ""
		return

	var data: DigimonData = Atlas.digimon.get(_digimon_state.key) as DigimonData
	if data == null:
		_name_label.text = str(_digimon_state.key)
		_level_label.text = "Lv. %d" % _digimon_state.level
		_element_label.text = ""
		return

	_name_label.text = data.display_name
	_level_label.text = "Lv. %d" % _digimon_state.level
	var elements: Array[String] = []
	for element_key: StringName in data.element_traits:
		elements.append(str(element_key).capitalize())
	_element_label.text = " / ".join(elements) if elements.size() > 0 else "Null"


func _on_edit_pressed() -> void:
	edit_pressed.emit(_index)


func _on_remove_pressed() -> void:
	remove_pressed.emit(_index)
