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
@onready var _field_display: FieldStatusDisplay = $BattleHUD/TopBar/FieldStatusDisplay
@onready var _ally_side_display: SideStatusDisplay = $BattleHUD/AllySideStatus
@onready var _foe_side_display: SideStatusDisplay = $BattleHUD/FoeSideStatus
@onready var _near_side: HBoxContainer = $BattleField/NearSide
@onready var _far_side: HBoxContainer = $BattleField/FarSide
@onready var _target_back_button: Button = $BattleHUD/TargetBackButton
@onready var _evolution_sub_menu: EvolutionSubMenu = $BattleHUD/EvolutionSubMenu
@onready var _battle_evolution_menu: BattleEvolutionMenu = $BattleHUD/BattleEvolutionMenu
@onready var _battle_jogress_menu: BattleJogressMenu = $BattleHUD/BattleJogressMenu

@onready var _event_replay: BattleEventReplay = $EventReplay
@onready var _display: BattlefieldDisplay = $BattlefieldDisplay
@onready var _input_manager: BattleInputManager = $InputManager

var _evolution_animator: BattleEvolutionAnimator = null

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

	# Create evolution animator
	_evolution_animator = BattleEvolutionAnimator.new()
	add_child(_evolution_animator)

	# Initialise child subsystems
	_event_replay.initialise(_battle)
	_event_replay.connect_engine_signals(_engine)

	_display.initialise(
		_battle, _near_side, _far_side, _ally_panels, _foe_panels,
	)
	_display.phase_ref = _get_phase_value

	_evolution_animator.initialise(_display, _battle, $BattleHUD)
	_event_replay.set_evolution_animator(_evolution_animator)

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
		_field_display, _ally_side_display, _foe_side_display,
		_evolution_sub_menu, _battle_evolution_menu, _battle_jogress_menu,
	)
	_input_manager.connect_ui_signals()

	# Connect post-battle
	_post_battle_screen.continue_pressed.connect(_on_continue_pressed)

	# Setup UI
	_hide_all_menus()
	_field_display.initialise(_battle)
	_display.setup_digimon_panels()
	_display.setup_battlefield_placeholders()
	_display.position_battlefield(self)
	_display.update_all_panels()

	# Wait one frame for layout to resolve
	await get_tree().process_frame

	# Initial field/side status refresh (for preset effects)
	_field_display.refresh()
	_ally_side_display.refresh_from_side(_battle.sides[0])
	if _battle.sides.size() > 1:
		_foe_side_display.refresh_from_side(_battle.sides[1])

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
			_field_display, _ally_side_display, _foe_side_display,
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
	_evolution_sub_menu.visible = false
	_battle_evolution_menu.visible = false
	_battle_jogress_menu.visible = false
	if _display.is_targeting():
		_display.exit_targeting_mode()


func _get_phase_value() -> int:
	return _phase


func _set_phase_value(value: int) -> void:
	_phase = value as BattlePhase


func _on_continue_pressed() -> void:
	# Revert all battle evolutions before leaving
	_revert_battle_evolutions()

	var return_path: String = Game.builder_context.get(
		"return_scene", BUILDER_PATH
	)
	Game.battle_config = null
	SceneManager.change_scene(return_path)


## Collect and revert all evolutions that occurred during battle.
func _revert_battle_evolutions() -> void:
	if _battle == null or Game.state == null:
		return

	var evolutions: Array[Dictionary] = []

	# Collect from all sides' active slots and retired Digimon
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.evolved_in_battle:
				evolutions.append({
					"source_state": slot.digimon.source_state,
					"snapshot": slot.digimon.pre_battle_snapshot,
				})
		for retired: BattleDigimonState in side.retired_battle_digimon:
			if retired.evolved_in_battle:
				# Avoid duplicates (source_state identity check)
				var already_added: bool = false
				for existing: Dictionary in evolutions:
					if existing.get("source_state") == retired.source_state:
						already_added = true
						break
				if not already_added:
					evolutions.append({
						"source_state": retired.source_state,
						"snapshot": retired.pre_battle_snapshot,
					})

	if evolutions.is_empty():
		return

	BattleEvolutionReverter.revert_battle_evolutions(
		evolutions,
		Game.state.party,
		Game.state.storage,
		Game.state.inventory,
	)
