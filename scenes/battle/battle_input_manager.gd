class_name BattleInputManager
extends Node
## Manages player input phase: action/technique/switch/target selection,
## forced switch prompts, and input queue progression.


signal turn_ready(actions: Array[BattleAction])

var _battle: BattleState = null
var _engine: BattleEngine = null
var _ai: BattleAI = null
var _display: BattlefieldDisplay = null
var _event_replay: BattleEventReplay = null

# HUD references
var _action_menu: ActionMenu = null
var _technique_menu: TechniqueMenu = null
var _switch_menu: SwitchMenu = null
var _target_selector: TargetSelector = null
var _message_box: BattleMessageBox = null
var _target_back_button: Button = null
var _turn_label: Label = null
var _post_battle_screen: PostBattleScreen = null

# Input state
var _pending_actions: Array[BattleAction] = []
var _current_input_side: int = -1
var _current_input_slot: int = -1
var _player_sides: Array[int] = []
var _input_queue: Array[Dictionary] = []
var _selected_technique_key: StringName = &""

var _phase_ref: Callable = Callable()
var _set_phase: Callable = Callable()
var _hide_all_menus: Callable = Callable()


func initialise(
	battle: BattleState,
	engine: BattleEngine,
	ai: BattleAI,
	display: BattlefieldDisplay,
	event_replay: BattleEventReplay,
	player_sides: Array[int],
	phase_ref: Callable,
	set_phase: Callable,
	hide_all_menus_fn: Callable,
) -> void:
	_battle = battle
	_engine = engine
	_ai = ai
	_display = display
	_event_replay = event_replay
	_player_sides = player_sides
	_phase_ref = phase_ref
	_set_phase = set_phase
	_hide_all_menus = hide_all_menus_fn


func set_hud_refs(
	action_menu: ActionMenu,
	technique_menu: TechniqueMenu,
	switch_menu: SwitchMenu,
	target_selector: TargetSelector,
	message_box: BattleMessageBox,
	target_back_button: Button,
	turn_label: Label,
	post_battle_screen: PostBattleScreen,
) -> void:
	_action_menu = action_menu
	_technique_menu = technique_menu
	_switch_menu = switch_menu
	_target_selector = target_selector
	_message_box = message_box
	_target_back_button = target_back_button
	_turn_label = turn_label
	_post_battle_screen = post_battle_screen


func connect_ui_signals() -> void:
	_action_menu.action_chosen.connect(_on_action_chosen)
	_technique_menu.technique_chosen.connect(_on_technique_chosen)
	_technique_menu.back_pressed.connect(_on_technique_back)
	_switch_menu.switch_chosen.connect(_on_switch_chosen)
	_switch_menu.back_pressed.connect(_on_switch_back)
	_target_selector.target_chosen.connect(_on_target_chosen)
	_target_selector.back_pressed.connect(_on_target_back)
	_target_back_button.pressed.connect(_on_targeting_back)


## --- Phase Management ---


func start_input_phase() -> void:
	_set_phase.call(1)  # INPUT
	_pending_actions.clear()
	_input_queue.clear()

	for side_idx: int in _player_sides:
		var side: SideState = _battle.sides[side_idx]
		for slot: SlotState in side.slots:
			if slot.digimon != null and not slot.digimon.is_fainted:
				_input_queue.append({
					"side": side_idx, "slot": slot.slot_index,
				})

	_advance_input()


func _advance_input() -> void:
	_display.stop_active_bounce()

	if _input_queue.is_empty():
		_collect_ai_actions()
		_execute_turn()
		return

	var next: Dictionary = _input_queue.pop_front()
	_current_input_side = int(next["side"])
	_current_input_slot = int(next["slot"])

	var digimon: BattleDigimonState = _battle.get_digimon_at(
		_current_input_side, _current_input_slot,
	)
	if digimon == null or digimon.is_fainted:
		_advance_input()
		return

	var digimon_name: String = digimon.data.display_name \
		if digimon.data else "???"
	_message_box.show_prompt("What will %s do?" % digimon_name)

	var side: SideState = _battle.sides[_current_input_side]
	_action_menu.set_switch_enabled(side.party.size() > 0)

	_hide_all_menus.call()
	_action_menu.visible = true

	_display.start_active_bounce(_current_input_side, _current_input_slot)


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
	_display.stop_active_bounce()
	_set_phase.call(2)  # EXECUTING
	_hide_all_menus.call()

	_event_replay.clear_queue()
	_engine.execute_turn(_pending_actions)

	await _event_replay.replay_events(
		self, _message_box, _display, _turn_label, _post_battle_screen,
	)

	if _battle.is_battle_over:
		_set_phase.call(4)  # ENDED
		_hide_all_menus.call()
		return

	if _needs_forced_switch():
		_set_phase.call(3)  # SWITCHING
		_prompt_forced_switch()
	else:
		start_input_phase()


func _needs_forced_switch() -> bool:
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted \
					and _has_alive_reserve(side):
				return true
	return false


func _has_alive_reserve(side: SideState) -> bool:
	for digimon: DigimonState in side.party:
		if digimon.current_hp > 0:
			return true
	return false


func _first_alive_reserve_index(side: SideState) -> int:
	for i: int in side.party.size():
		if side.party[i].current_hp > 0:
			return i
	return -1


func _prompt_forced_switch() -> void:
	for side_idx: int in _player_sides:
		var side: SideState = _battle.sides[side_idx]
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted \
					and _has_alive_reserve(side):
				_current_input_side = side_idx
				_current_input_slot = slot.slot_index
				_message_box.show_prompt("Choose a replacement!")
				_switch_menu.populate(side.party)
				_hide_all_menus.call()
				_switch_menu.visible = true
				return

	# AI forced switches
	for side: SideState in _battle.sides:
		if side.side_index in _player_sides:
			continue
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted \
					and _has_alive_reserve(side):
				var out_dur: float = _display.anim_switch_out(
					side.side_index, slot.slot_index,
				)
				if out_dur > 0.0:
					await get_tree().create_timer(out_dur).timeout

				var reserve_idx: int = _first_alive_reserve_index(side)
				_event_replay.clear_queue()
				var switch_action := BattleAction.new()
				switch_action.action_type = BattleAction.ActionType.SWITCH
				switch_action.user_side = side.side_index
				switch_action.user_slot = slot.slot_index
				switch_action.switch_to_party_index = reserve_idx
				_engine.resolve_forced_switch(switch_action)
				_display.update_placeholder(
					side.side_index, slot.slot_index,
				)
				_display.update_panel(side.side_index, slot.slot_index)

				var in_dur: float = _display.anim_switch_in(
					side.side_index, slot.slot_index,
				)
				if in_dur > 0.0:
					await get_tree().create_timer(in_dur).timeout

				_event_replay.filter_switch_events()
				if not _event_replay.is_queue_empty():
					await _event_replay.replay_events(
						self, _message_box, _display,
						_turn_label, _post_battle_screen,
					)

	if not _battle.is_battle_over:
		start_input_phase()


## --- UI Signal Handlers ---


func _on_action_chosen(action_type: BattleAction.ActionType) -> void:
	if not _phase_ref.is_valid() or _phase_ref.call() != 1:  # INPUT
		return

	match action_type:
		BattleAction.ActionType.TECHNIQUE:
			var digimon: BattleDigimonState = _battle.get_digimon_at(
				_current_input_side, _current_input_slot,
			)
			if digimon:
				_technique_menu.populate(digimon)
				_hide_all_menus.call()
				_technique_menu.visible = true

		BattleAction.ActionType.SWITCH:
			var side: SideState = _battle.sides[_current_input_side]
			_switch_menu.populate(side.party)
			_hide_all_menus.call()
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
			_message_box.show_prompt("Items are not yet available.")


func _on_technique_chosen(technique_key: StringName) -> void:
	_selected_technique_key = technique_key

	var tech: TechniqueData = Atlas.techniques.get(
		technique_key,
	) as TechniqueData
	if tech == null:
		return

	var needs_target: bool = tech.targeting in [
		Registry.Targeting.SINGLE_FOE,
		Registry.Targeting.SINGLE_TARGET,
		Registry.Targeting.SINGLE_OTHER,
		Registry.Targeting.SINGLE_ALLY,
	]

	if needs_target:
		var user: BattleDigimonState = _battle.get_digimon_at(
			_current_input_side, _current_input_slot,
		)
		if user == null:
			return

		var valid_targets: Array[Dictionary] = \
			_target_selector.get_valid_targets(user, tech.targeting, _battle)

		if valid_targets.size() == 0:
			_message_box.show_prompt("No valid targets!")
			return

		if valid_targets.size() == 1:
			_on_target_chosen(
				int(valid_targets[0]["side"]),
				int(valid_targets[0]["slot"]),
			)
			return

		_hide_all_menus.call()
		_display.enter_targeting_mode(
			user, valid_targets,
			func(si: int, sli: int) -> void:
				_target_selector.select_target(si, sli),
			_target_back_button,
			_message_box,
		)
	else:
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
	_hide_all_menus.call()
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
	_display.exit_targeting_mode()
	_hide_all_menus.call()
	_technique_menu.visible = true


func _on_targeting_back() -> void:
	_display.exit_targeting_mode()
	_hide_all_menus.call()
	_technique_menu.visible = true


func _on_switch_chosen(party_index: int) -> void:
	if _phase_ref.is_valid() and _phase_ref.call() == 3:  # SWITCHING
		var out_dur: float = _display.anim_switch_out(
			_current_input_side, _current_input_slot,
		)
		if out_dur > 0.0:
			await get_tree().create_timer(out_dur).timeout

		_event_replay.clear_queue()
		var switch_action := BattleAction.new()
		switch_action.action_type = BattleAction.ActionType.SWITCH
		switch_action.user_side = _current_input_side
		switch_action.user_slot = _current_input_slot
		switch_action.switch_to_party_index = party_index
		_engine.resolve_forced_switch(switch_action)
		_display.update_all_panels()
		_display.update_placeholder(
			_current_input_side, _current_input_slot,
		)

		var in_dur: float = _display.anim_switch_in(
			_current_input_side, _current_input_slot,
		)
		if in_dur > 0.0:
			await get_tree().create_timer(in_dur).timeout

		_event_replay.filter_switch_events()
		if not _event_replay.is_queue_empty():
			await _event_replay.replay_events(
				self, _message_box, _display,
				_turn_label, _post_battle_screen,
			)

		if _needs_forced_switch():
			_prompt_forced_switch()
		elif not _battle.is_battle_over:
			start_input_phase()
	else:
		var action := BattleAction.new()
		action.action_type = BattleAction.ActionType.SWITCH
		action.user_side = _current_input_side
		action.user_slot = _current_input_slot
		action.switch_to_party_index = party_index
		_pending_actions.append(action)
		_advance_input()


func _on_switch_back() -> void:
	if _phase_ref.is_valid() and _phase_ref.call() == 3:  # SWITCHING
		return
	_hide_all_menus.call()
	_action_menu.visible = true
