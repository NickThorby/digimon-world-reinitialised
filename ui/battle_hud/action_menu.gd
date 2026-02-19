class_name ActionMenu
extends PanelContainer
## Main action selection menu: Technique, Switch, Rest, Run, Items, Evolve.


signal action_chosen(action_type: BattleAction.ActionType)

@onready var _technique_button: Button = $Grid/TechniqueButton
@onready var _switch_button: Button = $Grid/SwitchButton
@onready var _rest_button: Button = $Grid/RestButton
@onready var _run_button: Button = $Grid/RunButton
@onready var _item_button: Button = $Grid/ItemButton
@onready var _evolve_button: Button = $Grid/EvolveButton


func _ready() -> void:
	_technique_button.pressed.connect(
		func() -> void: action_chosen.emit(BattleAction.ActionType.TECHNIQUE)
	)
	_switch_button.pressed.connect(
		func() -> void: action_chosen.emit(BattleAction.ActionType.SWITCH)
	)
	_rest_button.pressed.connect(
		func() -> void: action_chosen.emit(BattleAction.ActionType.REST)
	)
	_run_button.pressed.connect(
		func() -> void: action_chosen.emit(BattleAction.ActionType.RUN)
	)
	_item_button.pressed.connect(
		func() -> void: action_chosen.emit(BattleAction.ActionType.ITEM)
	)
	_evolve_button.pressed.connect(
		func() -> void: action_chosen.emit(BattleAction.ActionType.EVOLVE)
	)


## Configure visibility of the Run button (only for wild battles).
func set_run_visible(can_run: bool) -> void:
	_run_button.visible = can_run


## Enable/disable switch button.
func set_switch_enabled(enabled: bool) -> void:
	_switch_button.disabled = not enabled


## Enable/disable item button.
func set_item_enabled(enabled: bool) -> void:
	_item_button.disabled = not enabled


## Enable/disable evolve button.
func set_evolve_enabled(enabled: bool) -> void:
	_evolve_button.disabled = not enabled


## Set the text on the evolve button.
func set_evolve_text(text: String) -> void:
	_evolve_button.text = text
