class_name SwitchMenu
extends PanelContainer
## Shows reserve party members for switching. Emits selection.


signal switch_chosen(party_index: int)
signal back_pressed

@onready var _member_container: VBoxContainer = $VBox/ScrollContainer/MemberContainer
@onready var _back_button: Button = $VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## Populate with the side's reserve party.
func populate(party: Array[DigimonState]) -> void:
	for child: Node in _member_container.get_children():
		child.queue_free()

	for i: int in party.size():
		var state: DigimonState = party[i]
		var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
		var display_name: String = data.display_name if data else str(state.key)

		var button := Button.new()
		button.text = "%s  Lv. %d  HP: %d" % [display_name, state.level, state.current_hp]

		# Disable if fainted
		if state.current_hp <= 0:
			button.disabled = true

		var idx: int = i
		button.pressed.connect(
			func() -> void: switch_chosen.emit(idx)
		)
		_member_container.add_child(button)
