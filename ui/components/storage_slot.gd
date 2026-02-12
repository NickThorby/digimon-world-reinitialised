class_name StorageSlot
extends PanelContainer
## Grid cell for storage box display. Shows a Digimon sprite thumbnail or empty.

signal slot_clicked(box_index: int, slot_index: int)

var _box_index: int = -1
var _slot_index: int = -1
var _digimon: DigimonState = null

@onready var _sprite_rect: TextureRect = $SpriteRect


func setup(box_index: int, slot_index: int, digimon: DigimonState) -> void:
	_box_index = box_index
	_slot_index = slot_index
	_digimon = digimon

	if digimon != null:
		var data: DigimonData = Atlas.digimon.get(digimon.key) as DigimonData
		if data and data.sprite_texture:
			_sprite_rect.texture = data.sprite_texture
			_sprite_rect.flip_h = true
		tooltip_text = "%s Lv.%d" % [
			data.display_name if data else str(digimon.key),
			digimon.level,
		]
	else:
		_sprite_rect.texture = null
		tooltip_text = ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			slot_clicked.emit(_box_index, _slot_index)


func is_occupied() -> bool:
	return _digimon != null


func get_digimon() -> DigimonState:
	return _digimon
