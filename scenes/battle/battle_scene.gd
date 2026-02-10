extends Node2D
## Battle scene orchestrator — wires engine, AI, and child subsystems together.
## Delegates event replay, battlefield display, and input management to child nodes.

const BUILDER_PATH := "res://scenes/battle/battle_builder.tscn"

enum BattlePhase {
	INITIALISING,
	INPUT,
	EXECUTING,
	SWITCHING,
	ENDED,
}

@onready var _ally_panels: HBoxContainer = $BattleHUD/AllyPanels
@onready var _foe_panels: HBoxContainer = $BattleHUD/FoePanels
@onready var _action_menu: ActionMenu = $BattleHUD/ActionMenu
@onready var _technique_menu: TechniqueMenu = $BattleHUD/TechniqueMenu
@onready var _switch_menu: SwitchMenu = $BattleHUD/SwitchMenu
@onready var _item_menu: ItemMenu = $BattleHUD/ItemMenu
@onready var _item_target_menu: ItemTargetMenu = $BattleHUD/ItemTargetMenu
@onready var _target_selector: TargetSelector = $BattleHUD/TargetSelector
@onready var _message_box: BattleMessageBox = $BattleHUD/BattleMessageBox
@onready var _post_battle_screen: PostBattleScreen = $BattleHUD/PostBattleScreen
@onready var _turn_label: Label = $BattleHUD/TopBar/TurnLabel
@onready var _near_side: HBoxContainer = $BattleField/NearSide
@onready var _far_side: HBoxContainer = $BattleField/FarSide
@onready var _target_back_button: Button = $BattleHUD/TargetBackButton

@onready var _event_replay: BattleEventReplay = $EventReplay
@onready var _display: BattlefieldDisplay = $BattlefieldDisplay
@onready var _input_manager: BattleInputManager = $InputManager

var _battle: BattleState = null
var _engine: BattleEngine = BattleEngine.new()
var _ai: BattleAI = BattleAI.new()
var _phase: BattlePhase = BattlePhase.INITIALISING
var _player_sides: Array[int] = []


func _ready() -> void:
	var config: BattleConfig = Game.battle_config
	if config == null:
		push_error("BattleScene: No battle config set!")
		_message_box.show_prompt("Error: No battle configuration found.")
		return

	# Create battle state
	_battle = BattleFactory.create_battle(config)
	_engine.initialise(_battle)
	_ai.initialise(_battle)

	# Initialise child subsystems
	_event_replay.initialise(_battle)
	_event_replay.connect_engine_signals(_engine)

	_display.initialise(
		_battle, _near_side, _far_side, _ally_panels, _foe_panels,
	)
	_display.phase_ref = _get_phase_value

	# Determine player-controlled sides
	for i: int in config.side_count:
		var side_cfg: Dictionary = config.side_configs[i] \
			if i < config.side_configs.size() else {}
		if int(side_cfg.get("controller", 0)) == \
				BattleConfig.ControllerType.PLAYER:
			_player_sides.append(i)

	_input_manager.initialise(
		_battle, _engine, _ai, _display, _event_replay, _player_sides,
		_get_phase_value, _set_phase_value, _hide_all_menus,
	)
	_input_manager.set_hud_refs(
		_action_menu, _technique_menu, _switch_menu,
		_item_menu, _item_target_menu,
		_target_selector,
		_message_box, _target_back_button, _turn_label, _post_battle_screen,
	)
	_input_manager.connect_ui_signals()

	# Connect post-battle
	_post_battle_screen.continue_pressed.connect(_on_continue_pressed)

	# Setup UI
	_hide_all_menus()
	_display.setup_digimon_panels()
	_display.setup_battlefield_placeholders()
	_display.position_battlefield(self)
	_display.update_all_panels()

	# Check if this is a wild battle (for run button and music)
	var is_wild: bool = false
	for side: SideState in _battle.sides:
		if side.is_wild:
			is_wild = true
			break
	_action_menu.set_run_visible(is_wild)

	if is_wild:
		MusicManager.play("res://assets/audio/music/33. Wild Digimon Battle.mp3")
	else:
		MusicManager.play("res://assets/audio/music/35. Tamer Battle.mp3")

	# Start input phase
	await _message_box.show_message("Battle start!")

	# Fire ON_ENTRY abilities for all starting Digimon
	_event_replay.clear_queue()
	_engine.start_battle()
	if not _event_replay.is_queue_empty():
		await _event_replay.replay_events(
			self, _message_box, _display, _turn_label, _post_battle_screen,
		)

	_input_manager.start_input_phase()


func _hide_all_menus() -> void:
	_action_menu.visible = false
	_technique_menu.visible = false
	_switch_menu.visible = false
	_item_menu.visible = false
	_item_target_menu.visible = false
	_target_selector.visible = false
	_target_back_button.visible = false
	if _display.is_targeting():
		_display.exit_targeting_mode()


func _get_phase_value() -> int:
	return _phase


func _set_phase_value(value: int) -> void:
	_phase = value as BattlePhase


func _on_continue_pressed() -> void:
	Game.battle_config = null
	SceneManager.change_scene(BUILDER_PATH)
