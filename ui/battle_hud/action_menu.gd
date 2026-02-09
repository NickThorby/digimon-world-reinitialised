class_name ActionMenu
extends PanelContainer
## Main action selection menu: Technique, Switch, Rest, Run, Items.


signal action_chosen(action_type: BattleAction.ActionType)

@onready var _technique_button: Button = %TechniqueButton
@onready var _switch_button: Button = %SwitchButton
@onready var _rest_button: Button = %RestButton
@onready var _run_button: Button = %RunButton
@onready var _item_button: Button = %ItemButton


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


## Configure visibility of the Run button (only for wild battles).
func set_run_visible(can_run: bool) -> void:
	_run_button.visible = can_run


## Enable/disable switch button.
func set_switch_enabled(enabled: bool) -> void:
	_switch_button.disabled = not enabled
