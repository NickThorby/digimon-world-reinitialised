class_name DigimonSlotPanel
extends PanelContainer
## Compact widget showing one Digimon in a team slot.
## Displays name, level, element icons, and edit/remove buttons.


signal edit_pressed(index: int)
signal remove_pressed(index: int)

@onready var _sprite_rect: TextureRect = $HBox/SpriteRect
@onready var _name_label: Label = $HBox/InfoVBox/TopRow/NameLabel
@onready var _level_label: Label = $HBox/InfoVBox/TopRow/LevelLabel
@onready var _element_label: Label = $HBox/InfoVBox/ElementLabel
@onready var _edit_button: Button = $HBox/ButtonVBox/EditButton
@onready var _remove_button: Button = $HBox/ButtonVBox/RemoveButton

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
		_sprite_rect.texture = null
		return

	var data: DigimonData = Atlas.digimon.get(_digimon_state.key) as DigimonData
	if data == null:
		_name_label.text = str(_digimon_state.key)
		_level_label.text = "Lv. %d" % _digimon_state.level
		_element_label.text = ""
		_sprite_rect.texture = null
		return

	_name_label.text = data.display_name
	_level_label.text = "Lv. %d" % _digimon_state.level
	_sprite_rect.texture = data.sprite_texture
	var elements: Array[String] = []
	for element_key: StringName in data.element_traits:
		elements.append(str(element_key).capitalize())
	_element_label.text = " / ".join(elements) if elements.size() > 0 else "—"


func _on_edit_pressed() -> void:
	edit_pressed.emit(_index)


func _on_remove_pressed() -> void:
	remove_pressed.emit(_index)
