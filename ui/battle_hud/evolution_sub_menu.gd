class_name EvolutionSubMenu
extends PanelContainer
## Two-button sub-menu for choosing between evolve and devolve.


signal evolve_chosen()
signal devolve_chosen()
signal back_pressed()

@onready var _evolve_button: Button = $VBox/EvolveButton
@onready var _devolve_button: Button = $VBox/DevolveButton
@onready var _back_button: Button = $VBox/BackButton


func _ready() -> void:
	_evolve_button.pressed.connect(func() -> void: evolve_chosen.emit())
	_devolve_button.pressed.connect(func() -> void: devolve_chosen.emit())
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## Configure the sub-menu based on what's available.
func populate(can_evolve: bool, can_devolve: bool) -> void:
	_evolve_button.text = Settings.get_evolve_imperative()
	_evolve_button.disabled = not can_evolve
	_evolve_button.visible = true

	_devolve_button.text = Settings.get_de_evolution_noun()
	_devolve_button.disabled = not can_devolve
	_devolve_button.visible = true
