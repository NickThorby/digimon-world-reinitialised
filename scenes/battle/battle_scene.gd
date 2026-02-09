extends Node2D
## Battle scene — integrates engine, AI, and UI for a full battle flow.

const DIGIMON_PANEL_SCENE := preload("res://ui/battle_hud/digimon_panel.tscn")
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
@onready var _target_selector: TargetSelector = $BattleHUD/TargetSelector
@onready var _battle_log: BattleLog = $BattleHUD/BattleLog
@onready var _post_battle_screen: PostBattleScreen = $PostBattleScreen
@onready var _turn_label: Label = $BattleHUD/TopBar/TurnLabel
@onready var _near_side: HBoxContainer = $BattleField/NearSide
@onready var _far_side: HBoxContainer = $BattleField/FarSide

var _battle: BattleState = null
var _engine: BattleEngine = BattleEngine.new()
var _ai: BattleAI = BattleAI.new()
var _phase: BattlePhase = BattlePhase.INITIALISING

# Input state tracking
var _pending_actions: Array[BattleAction] = []
var _current_input_side: int = -1
var _current_input_slot: int = -1
var _player_sides: Array[int] = []
var _input_queue: Array[Dictionary] = []  # [{ "side": int, "slot": int }]
var _selected_technique_key: StringName = &""

# Digimon panel references
var _ally_panel_map: Dictionary = {}  # "side_slot" -> DigimonPanel
var _foe_panel_map: Dictionary = {}


func _ready() -> void:
	var config: BattleConfig = Game.battle_config
	if config == null:
		push_error("BattleScene: No battle config set!")
		_battle_log.add_message("Error: No battle configuration found.")
		return

	# Create battle state
	_battle = BattleFactory.create_battle(config)
	_engine.initialise(_battle)
	_ai.initialise(_battle)

	# Connect engine signals
	_connect_engine_signals()

	# Connect UI signals
	_connect_ui_signals()

	# Setup UI
	_hide_all_menus()
	_setup_digimon_panels()
	_setup_battlefield_placeholders()
	_update_all_panels()

	# Determine player-controlled sides
	for i: int in config.side_count:
		var side_cfg: Dictionary = config.side_configs[i] if i < config.side_configs.size() else {}
		if int(side_cfg.get("controller", 0)) == BattleConfig.ControllerType.PLAYER:
			_player_sides.append(i)

	# Check if this is a wild battle (for run button)
	var is_wild: bool = false
	for side: SideState in _battle.sides:
		if side.is_wild:
			is_wild = true
			break
	_action_menu.set_run_visible(is_wild)

	# Start input phase
	_battle_log.add_message("Battle start!")
	_start_input_phase()


func _connect_engine_signals() -> void:
	_engine.battle_message.connect(_on_battle_message)
	_engine.damage_dealt.connect(_on_damage_dealt)
	_engine.energy_spent.connect(_on_energy_spent)
	_engine.hp_restored.connect(_on_hp_restored)
	_engine.digimon_fainted.connect(_on_digimon_fainted)
	_engine.digimon_switched.connect(_on_digimon_switched)
	_engine.status_applied.connect(_on_status_applied)
	_engine.status_removed.connect(_on_status_removed)
	_engine.turn_started.connect(_on_turn_started)
	_engine.turn_ended.connect(_on_turn_ended)
	_engine.battle_ended.connect(_on_battle_ended)


func _connect_ui_signals() -> void:
	_action_menu.action_chosen.connect(_on_action_chosen)
	_technique_menu.technique_chosen.connect(_on_technique_chosen)
	_technique_menu.back_pressed.connect(_on_technique_back)
	_switch_menu.switch_chosen.connect(_on_switch_chosen)
	_switch_menu.back_pressed.connect(_on_switch_back)
	_target_selector.target_chosen.connect(_on_target_chosen)
	_target_selector.back_pressed.connect(_on_target_back)
	_post_battle_screen.continue_pressed.connect(_on_continue_pressed)


func _hide_all_menus() -> void:
	_action_menu.visible = false
	_technique_menu.visible = false
	_switch_menu.visible = false
	_target_selector.visible = false


## --- Phase Management ---


func _start_input_phase() -> void:
	_phase = BattlePhase.INPUT
	_pending_actions.clear()
	_input_queue.clear()

	# Build input queue for player-controlled slots
	for side_idx: int in _player_sides:
		var side: SideState = _battle.sides[side_idx]
		for slot: SlotState in side.slots:
			if slot.digimon != null and not slot.digimon.is_fainted:
				_input_queue.append({"side": side_idx, "slot": slot.slot_index})

	_advance_input()


func _advance_input() -> void:
	if _input_queue.is_empty():
		# All player input collected — get AI actions and execute
		_collect_ai_actions()
		_execute_turn()
		return

	var next: Dictionary = _input_queue.pop_front()
	_current_input_side = int(next["side"])
	_current_input_slot = int(next["slot"])

	var digimon: BattleDigimonState = _battle.get_digimon_at(
		_current_input_side, _current_input_slot
	)
	if digimon == null or digimon.is_fainted:
		_advance_input()
		return

	var name: String = digimon.data.display_name if digimon.data else "???"
	_battle_log.add_message("What will %s do?" % name)

	# Check if switch is possible
	var side: SideState = _battle.sides[_current_input_side]
	_action_menu.set_switch_enabled(side.party.size() > 0)

	_hide_all_menus()
	_action_menu.visible = true


func _collect_ai_actions() -> void:
	for i: int in _battle.config.side_count:
		if i in _player_sides:
			continue
		var side_cfg: Dictionary = _battle.config.side_configs[i] if \
			i < _battle.config.side_configs.size() else {}
		if int(side_cfg.get("controller", 0)) == BattleConfig.ControllerType.AI:
			var ai_actions: Array[BattleAction] = _ai.generate_actions(i)
			_pending_actions.append_array(ai_actions)


func _execute_turn() -> void:
	_phase = BattlePhase.EXECUTING
	_hide_all_menus()

	_engine.execute_turn(_pending_actions)

	# After execution, check state
	if _battle.is_battle_over:
		return  # battle_ended signal handles this

	# Check for forced replacements
	if _needs_forced_switch():
		_phase = BattlePhase.SWITCHING
		_prompt_forced_switch()
	else:
		_start_input_phase()


func _needs_forced_switch() -> bool:
	for side_idx: int in _player_sides:
		var side: SideState = _battle.sides[side_idx]
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted and side.party.size() > 0:
				return true
	return false


func _prompt_forced_switch() -> void:
	# Find first player slot needing replacement
	for side_idx: int in _player_sides:
		var side: SideState = _battle.sides[side_idx]
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted and side.party.size() > 0:
				_current_input_side = side_idx
				_current_input_slot = slot.slot_index
				_battle_log.add_message("Choose a replacement!")
				_switch_menu.populate(side.party)
				_hide_all_menus()
				_switch_menu.visible = true
				return

	# AI forced switches
	for side: SideState in _battle.sides:
		if side.side_index in _player_sides:
			continue
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted and side.party.size() > 0:
				# AI auto-picks first available
				var switch_action := BattleAction.new()
				switch_action.action_type = BattleAction.ActionType.SWITCH
				switch_action.user_side = side.side_index
				switch_action.user_slot = slot.slot_index
				switch_action.switch_to_party_index = 0
				_engine._resolve_switch(switch_action)

	# After all forced switches, return to input
	if not _battle.is_battle_over:
		_start_input_phase()


## --- UI Signal Handlers ---


func _on_action_chosen(action_type: BattleAction.ActionType) -> void:
	if _phase != BattlePhase.INPUT:
		return

	match action_type:
		BattleAction.ActionType.TECHNIQUE:
			var digimon: BattleDigimonState = _battle.get_digimon_at(
				_current_input_side, _current_input_slot
			)
			if digimon:
				_technique_menu.populate(digimon)
				_hide_all_menus()
				_technique_menu.visible = true

		BattleAction.ActionType.SWITCH:
			var side: SideState = _battle.sides[_current_input_side]
			_switch_menu.populate(side.party)
			_hide_all_menus()
			_switch_menu.visible = true

		BattleAction.ActionType.REST:
			var action := BattleAction.new()
			action.action_type = BattleAction.ActionType.REST
			action.user_side = _current_input_side
			action.user_slot = _current_input_slot
			_pending_actions.append(action)
			_advance_input()

		BattleAction.ActionType.RUN:
			var action := BattleAction.new()
			action.action_type = BattleAction.ActionType.RUN
			action.user_side = _current_input_side
			action.user_slot = _current_input_slot
			_pending_actions.append(action)
			_advance_input()

		BattleAction.ActionType.ITEM:
			_battle_log.add_message("Items are not yet available.")


func _on_technique_chosen(technique_key: StringName) -> void:
	_selected_technique_key = technique_key

	var tech: TechniqueData = Atlas.techniques.get(technique_key) as TechniqueData
	if tech == null:
		return

	# Check if we need target selection
	var needs_target: bool = tech.targeting in [
		Registry.Targeting.SINGLE_FOE,
		Registry.Targeting.SINGLE_TARGET,
		Registry.Targeting.SINGLE_OTHER,
		Registry.Targeting.SINGLE_ALLY,
	]

	if needs_target:
		var user: BattleDigimonState = _battle.get_digimon_at(
			_current_input_side, _current_input_slot
		)
		if user:
			_target_selector.populate(user, tech.targeting, _battle)
			_hide_all_menus()
			_target_selector.visible = true
	else:
		# Multi-target or self — no target selection needed
		var action := BattleAction.new()
		action.action_type = BattleAction.ActionType.TECHNIQUE
		action.user_side = _current_input_side
		action.user_slot = _current_input_slot
		action.technique_key = technique_key
		action.target_side = _current_input_side
		action.target_slot = _current_input_slot
		_pending_actions.append(action)
		_advance_input()


func _on_technique_back() -> void:
	_hide_all_menus()
	_action_menu.visible = true


func _on_target_chosen(side_index: int, slot_index: int) -> void:
	var action := BattleAction.new()
	action.action_type = BattleAction.ActionType.TECHNIQUE
	action.user_side = _current_input_side
	action.user_slot = _current_input_slot
	action.technique_key = _selected_technique_key
	action.target_side = side_index
	action.target_slot = slot_index
	_pending_actions.append(action)
	_advance_input()


func _on_target_back() -> void:
	_hide_all_menus()
	_technique_menu.visible = true


func _on_switch_chosen(party_index: int) -> void:
	if _phase == BattlePhase.SWITCHING:
		# Forced switch
		var switch_action := BattleAction.new()
		switch_action.action_type = BattleAction.ActionType.SWITCH
		switch_action.user_side = _current_input_side
		switch_action.user_slot = _current_input_slot
		switch_action.switch_to_party_index = party_index
		_engine._resolve_switch(switch_action)
		_update_all_panels()

		# Check for more forced switches
		if _needs_forced_switch():
			_prompt_forced_switch()
		elif not _battle.is_battle_over:
			_start_input_phase()
	else:
		# Normal switch action
		var action := BattleAction.new()
		action.action_type = BattleAction.ActionType.SWITCH
		action.user_side = _current_input_side
		action.user_slot = _current_input_slot
		action.switch_to_party_index = party_index
		_pending_actions.append(action)
		_advance_input()


func _on_switch_back() -> void:
	if _phase == BattlePhase.SWITCHING:
		return  # Cannot go back during forced switch
	_hide_all_menus()
	_action_menu.visible = true


func _on_continue_pressed() -> void:
	# Return to builder
	Game.battle_config = null
	SceneManager.change_scene(BUILDER_PATH)


## --- Engine Signal Handlers ---


func _on_battle_message(text: String) -> void:
	_battle_log.add_message(text)


func _on_damage_dealt(
	side_index: int,
	slot_index: int,
	_amount: int,
	_effectiveness: StringName,
) -> void:
	_update_panel(side_index, slot_index)


func _on_energy_spent(side_index: int, slot_index: int, _amount: int) -> void:
	_update_panel(side_index, slot_index)


func _on_hp_restored(side_index: int, slot_index: int, _amount: int) -> void:
	_update_panel(side_index, slot_index)


func _on_digimon_fainted(side_index: int, slot_index: int) -> void:
	_update_panel(side_index, slot_index)


func _on_digimon_switched(
	side_index: int,
	slot_index: int,
	_new_digimon: BattleDigimonState,
) -> void:
	_update_panel(side_index, slot_index)
	_update_placeholder(side_index, slot_index)


func _on_status_applied(
	side_index: int,
	slot_index: int,
	_status_key: StringName,
) -> void:
	_update_panel(side_index, slot_index)


func _on_status_removed(
	side_index: int,
	slot_index: int,
	_status_key: StringName,
) -> void:
	_update_panel(side_index, slot_index)


func _on_turn_started(turn_number: int) -> void:
	_turn_label.text = "Turn %d" % turn_number


func _on_turn_ended(_turn_number: int) -> void:
	_update_all_panels()


func _on_battle_ended(result: BattleResult) -> void:
	_phase = BattlePhase.ENDED
	_hide_all_menus()

	# Write back to source states
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			if slot.digimon != null:
				# Restore energy to 100% post-battle
				slot.digimon.current_energy = slot.digimon.max_energy
				slot.digimon.write_back()

	# XP awards
	if _battle.config.xp_enabled and result.outcome == BattleResult.Outcome.WIN:
		result.xp_awards = XPCalculator.calculate_xp_awards(_battle)

	_post_battle_screen.show_results(result)


## --- Panel Management ---


func _setup_digimon_panels() -> void:
	# Clear existing panels
	for child: Node in _ally_panels.get_children():
		child.queue_free()
	for child: Node in _foe_panels.get_children():
		child.queue_free()

	_ally_panel_map.clear()
	_foe_panel_map.clear()

	# Determine which sides are allied to player (team 0)
	for side: SideState in _battle.sides:
		var is_ally: bool = _battle.are_allies(0, side.side_index)
		for slot: SlotState in side.slots:
			var panel: DigimonPanel = DIGIMON_PANEL_SCENE.instantiate() as DigimonPanel
			var key: String = "%d_%d" % [side.side_index, slot.slot_index]

			if is_ally:
				_ally_panels.add_child(panel)
				_ally_panel_map[key] = panel
			else:
				_foe_panels.add_child(panel)
				_foe_panel_map[key] = panel


func _setup_battlefield_placeholders() -> void:
	# Clear existing
	for child: Node in _near_side.get_children():
		child.queue_free()
	for child: Node in _far_side.get_children():
		child.queue_free()

	# Create placeholder sprites for each active Digimon
	for side: SideState in _battle.sides:
		var is_ally: bool = _battle.are_allies(0, side.side_index)
		var container: HBoxContainer = _near_side if is_ally else _far_side

		for slot: SlotState in side.slots:
			var vbox := VBoxContainer.new()
			vbox.custom_minimum_size = Vector2(80, 100)

			var rect := ColorRect.new()
			rect.custom_minimum_size = Vector2(60, 60)
			rect.color = Color(0.3, 0.7, 0.3) if is_ally else Color(0.7, 0.3, 0.3)
			vbox.add_child(rect)

			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if slot.digimon != null and slot.digimon.data != null:
				label.text = slot.digimon.data.display_name
			else:
				label.text = "(Empty)"
			label.name = "NameLabel"
			vbox.add_child(label)

			vbox.name = "Slot_%d_%d" % [side.side_index, slot.slot_index]
			container.add_child(vbox)


func _update_all_panels() -> void:
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			_update_panel(side.side_index, slot.slot_index)


func _update_panel(side_index: int, slot_index: int) -> void:
	var key: String = "%d_%d" % [side_index, slot_index]
	var panel: DigimonPanel = null

	if _ally_panel_map.has(key):
		panel = _ally_panel_map[key] as DigimonPanel
	elif _foe_panel_map.has(key):
		panel = _foe_panel_map[key] as DigimonPanel

	if panel == null:
		return

	var digimon: BattleDigimonState = _battle.get_digimon_at(side_index, slot_index)
	panel.update_from_battle_digimon(digimon)


func _update_placeholder(side_index: int, slot_index: int) -> void:
	var is_ally: bool = _battle.are_allies(0, side_index)
	var container: HBoxContainer = _near_side if is_ally else _far_side
	var node_name: String = "Slot_%d_%d" % [side_index, slot_index]

	var vbox: Node = container.get_node_or_null(node_name)
	if vbox == null:
		return

	var label: Label = vbox.get_node_or_null("NameLabel") as Label
	if label == null:
		return

	var digimon: BattleDigimonState = _battle.get_digimon_at(side_index, slot_index)
	if digimon != null and digimon.data != null:
		label.text = digimon.data.display_name
	else:
		label.text = "(Empty)"
