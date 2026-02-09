extends Node2D
## Battle scene — integrates engine, AI, and UI for a full battle flow.
## Uses an event queue to replay engine signals with delays and animations.

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
@onready var _message_box: BattleMessageBox = $BattleHUD/BattleMessageBox
@onready var _post_battle_screen: PostBattleScreen = $BattleHUD/PostBattleScreen
@onready var _turn_label: Label = $BattleHUD/TopBar/TurnLabel
@onready var _near_side: HBoxContainer = $BattleField/NearSide
@onready var _far_side: HBoxContainer = $BattleField/FarSide
@onready var _target_back_button: Button = $BattleHUD/TargetBackButton

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

# Event queue for async replay
var _event_queue: Array[Dictionary] = []

# Hover bounce tweens — key "side_slot" -> Tween
var _hover_tweens: Dictionary = {}

# Active digimon bounce
var _active_bounce_tween: Tween = null
var _active_bounce_panel_tween: Tween = null
var _active_bounce_key: String = ""

# Sprite-based targeting
var _target_indicators: Array[TargetIndicator] = []
var _valid_target_map: Dictionary = {}  # "side_slot" -> true
var _is_targeting: bool = false


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

	# Connect engine signals
	_connect_engine_signals()

	# Connect UI signals
	_connect_ui_signals()

	# Setup UI
	_hide_all_menus()
	_setup_digimon_panels()
	_setup_battlefield_placeholders()
	_position_battlefield()
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
	await _message_box.show_message("Battle start!")

	# Fire ON_ENTRY abilities for all starting Digimon
	_event_queue.clear()
	_engine.start_battle()
	if not _event_queue.is_empty():
		await _replay_events()

	_start_input_phase()


func _connect_engine_signals() -> void:
	_engine.battle_message.connect(_on_battle_message)
	_engine.technique_animation_requested.connect(_on_technique_animation_requested)
	_engine.damage_dealt.connect(_on_damage_dealt)
	_engine.energy_spent.connect(_on_energy_spent)
	_engine.energy_restored.connect(_on_energy_restored)
	_engine.hp_restored.connect(_on_hp_restored)
	_engine.digimon_fainted.connect(_on_digimon_fainted)
	_engine.digimon_switched.connect(_on_digimon_switched)
	_engine.stat_changed.connect(_on_stat_changed)
	_engine.status_applied.connect(_on_status_applied)
	_engine.status_removed.connect(_on_status_removed)
	_engine.turn_started.connect(_on_turn_started)
	_engine.turn_ended.connect(_on_turn_ended)
	_engine.battle_ended.connect(_on_battle_ended)
	_engine.action_resolved.connect(_on_action_resolved)


func _connect_ui_signals() -> void:
	_action_menu.action_chosen.connect(_on_action_chosen)
	_technique_menu.technique_chosen.connect(_on_technique_chosen)
	_technique_menu.back_pressed.connect(_on_technique_back)
	_switch_menu.switch_chosen.connect(_on_switch_chosen)
	_switch_menu.back_pressed.connect(_on_switch_back)
	_target_selector.target_chosen.connect(_on_target_chosen)
	_target_selector.back_pressed.connect(_on_target_back)
	_target_back_button.pressed.connect(_on_targeting_back)
	_post_battle_screen.continue_pressed.connect(_on_continue_pressed)


func _hide_all_menus() -> void:
	_action_menu.visible = false
	_technique_menu.visible = false
	_switch_menu.visible = false
	_target_selector.visible = false
	_target_back_button.visible = false
	if _is_targeting:
		_exit_targeting_mode()


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
	_stop_active_bounce()

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

	var digimon_name: String = digimon.data.display_name if digimon.data else "???"
	_message_box.show_prompt("What will %s do?" % digimon_name)

	# Check if switch is possible
	var side: SideState = _battle.sides[_current_input_side]
	_action_menu.set_switch_enabled(side.party.size() > 0)

	_hide_all_menus()
	_action_menu.visible = true

	_start_active_bounce(_current_input_side, _current_input_slot)


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
	_stop_active_bounce()
	_phase = BattlePhase.EXECUTING
	_hide_all_menus()

	_event_queue.clear()
	_engine.execute_turn(_pending_actions)  # Synchronous — populates event queue

	await _replay_events()  # Async — plays with delays

	# After execution, check state
	if _battle.is_battle_over:
		return  # battle_ended event handles this

	# Check for forced replacements
	if _needs_forced_switch():
		_phase = BattlePhase.SWITCHING
		_prompt_forced_switch()
	else:
		_start_input_phase()


func _needs_forced_switch() -> bool:
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted and _has_alive_reserve(side):
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
	# Find first player slot needing replacement
	for side_idx: int in _player_sides:
		var side: SideState = _battle.sides[side_idx]
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted and _has_alive_reserve(side):
				_current_input_side = side_idx
				_current_input_slot = slot.slot_index
				_message_box.show_prompt("Choose a replacement!")
				_switch_menu.populate(side.party)
				_hide_all_menus()
				_switch_menu.visible = true
				return

	# AI forced switches
	for side: SideState in _battle.sides:
		if side.side_index in _player_sides:
			continue
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted and _has_alive_reserve(side):
				var ph: Node = _get_battlefield_placeholder(
					side.side_index, slot.slot_index
				)
				var out_dur: float = _anim_switch_out(ph)
				if out_dur > 0.0:
					await get_tree().create_timer(out_dur).timeout

				var reserve_idx: int = _first_alive_reserve_index(side)
				_event_queue.clear()
				var switch_action := BattleAction.new()
				switch_action.action_type = BattleAction.ActionType.SWITCH
				switch_action.user_side = side.side_index
				switch_action.user_slot = slot.slot_index
				switch_action.switch_to_party_index = reserve_idx
				_engine._resolve_switch(switch_action)
				_update_placeholder(side.side_index, slot.slot_index)
				_update_panel(side.side_index, slot.slot_index)

				ph = _get_battlefield_placeholder(side.side_index, slot.slot_index)
				var in_dur: float = _anim_switch_in(ph)
				if in_dur > 0.0:
					await get_tree().create_timer(in_dur).timeout

				# Replay ON_ENTRY ability events (skip switch events handled above)
				_filter_switch_events()
				if not _event_queue.is_empty():
					await _replay_events()

	# After all forced switches, return to input
	if not _battle.is_battle_over:
		_start_input_phase()


## --- Event Replay ---


func _replay_events() -> void:
	for event: Dictionary in _event_queue:
		if not is_inside_tree():
			return
		var event_type: StringName = event.get("type", &"") as StringName

		match event_type:
			&"battle_message":
				await _message_box.show_message(event["text"] as String)

			&"technique_animation":
				var duration: float = await _play_attack_animation(
					int(event["user_side"]),
					int(event["user_slot"]),
					event["technique_class"] as Registry.TechniqueClass,
				)
				if duration > 0.0:
					await get_tree().create_timer(duration).timeout

			&"action_resolved":
				pass  # Animation moved to technique_animation event

			&"damage_dealt":
				var dmg_side: int = int(event["side_index"])
				var dmg_slot: int = int(event["slot_index"])
				var hit_ph: Node = _get_battlefield_placeholder(dmg_side, dmg_slot)
				var hit_dur: float = _anim_hit(hit_ph)
				_update_panel_from_snapshot(
					dmg_side, dmg_slot,
					event.get("snapshot", {}) as Dictionary,
				)
				if hit_dur > 0.0:
					await get_tree().create_timer(hit_dur).timeout
				await get_tree().create_timer(0.15).timeout

			&"energy_spent":
				_update_panel_from_snapshot(
					int(event["side_index"]), int(event["slot_index"]),
					event.get("snapshot", {}) as Dictionary,
				)

			&"energy_restored":
				_update_panel_from_snapshot(
					int(event["side_index"]), int(event["slot_index"]),
					event.get("snapshot", {}) as Dictionary,
				)
				await get_tree().create_timer(0.3).timeout

			&"hp_restored":
				_update_panel_from_snapshot(
					int(event["side_index"]), int(event["slot_index"]),
					event.get("snapshot", {}) as Dictionary,
				)
				await get_tree().create_timer(0.3).timeout

			&"stat_changed":
				var sc_side: int = int(event["side_index"])
				var sc_slot: int = int(event["slot_index"])
				var sc_stages: int = int(event["stages"])
				_update_panel_from_snapshot(
					sc_side, sc_slot,
					event.get("snapshot", {}) as Dictionary,
				)
				var sc_ph: Node = _get_battlefield_placeholder(sc_side, sc_slot)
				if sc_stages > 0:
					var raise_dur: float = _anim_stat_raise(sc_ph)
					if raise_dur > 0.0:
						await get_tree().create_timer(raise_dur).timeout
				elif sc_stages < 0:
					var lower_dur: float = _anim_stat_lower(sc_ph)
					if lower_dur > 0.0:
						await get_tree().create_timer(lower_dur).timeout

			&"digimon_fainted":
				var faint_side: int = int(event["side_index"])
				var faint_slot: int = int(event["slot_index"])
				_update_panel_from_snapshot(
					faint_side, faint_slot,
					event.get("snapshot", {}) as Dictionary,
				)
				await get_tree().create_timer(0.5).timeout
				var faint_ph: Node = _get_battlefield_placeholder(
					faint_side, faint_slot
				)
				var faint_out_dur: float = _anim_switch_out(faint_ph)
				if faint_out_dur > 0.0:
					await get_tree().create_timer(faint_out_dur).timeout

			&"digimon_switched":
				var side_idx: int = int(event["side_index"])
				var slot_idx: int = int(event["slot_index"])
				var placeholder: Node = _get_battlefield_placeholder(side_idx, slot_idx)
				var out_dur: float = _anim_switch_out(placeholder)
				if out_dur > 0.0:
					await get_tree().create_timer(out_dur).timeout
				_update_panel_from_snapshot(
					side_idx, slot_idx,
					event.get("snapshot", {}) as Dictionary,
				)
				_update_placeholder(side_idx, slot_idx)
				placeholder = _get_battlefield_placeholder(side_idx, slot_idx)
				var in_dur: float = _anim_switch_in(placeholder)
				if in_dur > 0.0:
					await get_tree().create_timer(in_dur).timeout

			&"status_applied", &"status_removed":
				_update_panel_from_snapshot(
					int(event["side_index"]), int(event["slot_index"]),
					event.get("snapshot", {}) as Dictionary,
				)

			&"turn_started":
				_turn_label.text = "Turn %d" % int(event["turn_number"])

			&"turn_ended":
				_update_all_panels()

			&"battle_ended":
				_phase = BattlePhase.ENDED
				_hide_all_menus()
				var result: BattleResult = event.get("result") as BattleResult

				# Write back to source states
				for side: SideState in _battle.sides:
					for slot: SlotState in side.slots:
						if slot.digimon != null:
							slot.digimon.current_energy = slot.digimon.max_energy
							slot.digimon.write_back()

				# XP awards
				if _battle.config.xp_enabled and result.outcome == BattleResult.Outcome.WIN:
					result.xp_awards = XPCalculator.calculate_xp_awards(_battle)

				_post_battle_screen.show_results(result)


## Remove switch-related events from the queue (used when switch is handled inline).
func _filter_switch_events() -> void:
	var filtered: Array[Dictionary] = []
	for event: Dictionary in _event_queue:
		var event_type: StringName = event.get("type", &"") as StringName
		if event_type != &"digimon_switched":
			filtered.append(event)
	_event_queue = filtered


## --- Attack Animations ---


func _play_attack_animation(
	user_side: int,
	user_slot: int,
	technique_class: Registry.TechniqueClass,
) -> float:
	var placeholder: Node = _get_battlefield_placeholder(user_side, user_slot)
	if placeholder == null:
		return 0.0

	match technique_class:
		Registry.TechniqueClass.PHYSICAL:
			return _anim_physical_lunge(placeholder)
		Registry.TechniqueClass.SPECIAL:
			return _anim_special_flash(placeholder)
		Registry.TechniqueClass.STATUS:
			return _anim_status_tint(placeholder)
	return 0.0


## Physical: lunge forward and snap back.
func _anim_physical_lunge(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var original_pos: Vector2 = ctrl.position
	var is_ally: bool = ctrl.get_parent() == _near_side
	var offset: Vector2 = Vector2(0, -20) if is_ally else Vector2(0, 20)

	var tween: Tween = create_tween()
	tween.tween_property(ctrl, "position", original_pos + offset, 0.1)
	tween.tween_property(ctrl, "position", original_pos, 0.2)
	return 0.3


## Special: bright flash/pulse via modulate.
func _anim_special_flash(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control

	var tween: Tween = create_tween()
	tween.tween_property(ctrl, "modulate", Color(2.0, 2.0, 2.0), 0.1)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.3)
	return 0.4


## Status: yellow tint and fade back.
func _anim_status_tint(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control

	var tween: Tween = create_tween()
	tween.tween_property(ctrl, "modulate", Color(1.2, 1.2, 0.4), 0.1)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.2)
	return 0.3


## Hit: shake horizontally and flash red on the target.
func _anim_hit(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = create_tween()
	# Red flash
	tween.tween_property(ctrl, "modulate", Color(1.4, 0.3, 0.3), 0.05)
	# Shake
	tween.tween_property(ctrl, "position", origin + Vector2(6, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(-6, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(4, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(-4, 0), 0.04)
	# Reset
	tween.tween_property(ctrl, "position", origin, 0.04)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.1)
	return 0.3


## Stat raise: green tint flash + slight upward bounce.
func _anim_stat_raise(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = create_tween()
	tween.tween_property(ctrl, "modulate", Color(0.4, 1.4, 0.4), 0.08)
	tween.tween_property(ctrl, "position", origin + Vector2(0, -6), 0.08)
	tween.tween_property(ctrl, "position", origin, 0.12)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.12)
	return 0.35


## Stat lower: red tint flash + slight downward dip.
func _anim_stat_lower(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = create_tween()
	tween.tween_property(ctrl, "modulate", Color(1.4, 0.4, 0.4), 0.08)
	tween.tween_property(ctrl, "position", origin + Vector2(0, 6), 0.08)
	tween.tween_property(ctrl, "position", origin, 0.12)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.12)
	return 0.35


## Switch out: shrink sprite to nothing.
func _anim_switch_out(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	ctrl.pivot_offset = ctrl.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(ctrl, "scale", Vector2.ZERO, 0.25)
	return 0.25


## Switch in: grow sprite from nothing to full size.
func _anim_switch_in(placeholder: Node) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	ctrl.pivot_offset = ctrl.size / 2.0
	ctrl.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(ctrl, "scale", Vector2.ONE, 0.25)
	return 0.25


func _get_battlefield_placeholder(side_index: int, slot_index: int) -> Node:
	var is_ally: bool = _battle.are_allies(0, side_index)
	var container: HBoxContainer = _near_side if is_ally else _far_side
	var node_name: String = "Slot_%d_%d" % [side_index, slot_index]
	return container.get_node_or_null(node_name)


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
			_message_box.show_prompt("Items are not yet available.")


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
		if user == null:
			return

		var valid_targets: Array[Dictionary] = _target_selector.get_valid_targets(
			user, tech.targeting, _battle
		)

		if valid_targets.size() == 0:
			_message_box.show_prompt("No valid targets!")
			return

		if valid_targets.size() == 1:
			_on_target_chosen(
				int(valid_targets[0]["side"]), int(valid_targets[0]["slot"])
			)
			return

		# 2+ targets: enter sprite-based targeting mode
		_enter_targeting_mode(user, valid_targets)
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
	_exit_targeting_mode()
	_hide_all_menus()
	_technique_menu.visible = true


func _on_targeting_back() -> void:
	_exit_targeting_mode()
	_hide_all_menus()
	_technique_menu.visible = true


func _on_switch_chosen(party_index: int) -> void:
	if _phase == BattlePhase.SWITCHING:
		# Forced switch — animate out, swap, animate in
		var ph: Node = _get_battlefield_placeholder(
			_current_input_side, _current_input_slot
		)
		var out_dur: float = _anim_switch_out(ph)
		if out_dur > 0.0:
			await get_tree().create_timer(out_dur).timeout

		_event_queue.clear()
		var switch_action := BattleAction.new()
		switch_action.action_type = BattleAction.ActionType.SWITCH
		switch_action.user_side = _current_input_side
		switch_action.user_slot = _current_input_slot
		switch_action.switch_to_party_index = party_index
		_engine._resolve_switch(switch_action)
		_update_all_panels()
		_update_placeholder(_current_input_side, _current_input_slot)

		ph = _get_battlefield_placeholder(_current_input_side, _current_input_slot)
		var in_dur: float = _anim_switch_in(ph)
		if in_dur > 0.0:
			await get_tree().create_timer(in_dur).timeout

		# Replay ON_ENTRY ability events (skip switch events handled above)
		_filter_switch_events()
		if not _event_queue.is_empty():
			await _replay_events()

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


## --- Engine Signal Handlers (Queue Events) ---


## Capture a digimon's current values for deferred panel updates.
func _snapshot_digimon(side_index: int, slot_index: int) -> Dictionary:
	var digimon: BattleDigimonState = _battle.get_digimon_at(side_index, slot_index)
	if digimon == null:
		return {}
	var name: String = "???"
	if digimon.source_state != null and digimon.source_state.nickname != "":
		name = digimon.source_state.nickname
	elif digimon.data != null:
		name = digimon.data.display_name
	return {
		"name": name,
		"level": digimon.source_state.level if digimon.source_state else 1,
		"current_hp": digimon.current_hp,
		"max_hp": digimon.max_hp,
		"current_energy": digimon.current_energy,
		"max_energy": digimon.max_energy,
		"status_conditions": digimon.status_conditions.duplicate(true),
	}


func _on_battle_message(text: String) -> void:
	_event_queue.append({"type": &"battle_message", "text": text})


func _on_technique_animation_requested(
	user_side: int, user_slot: int, technique_class: Registry.TechniqueClass
) -> void:
	_event_queue.append({
		"type": &"technique_animation",
		"user_side": user_side,
		"user_slot": user_slot,
		"technique_class": technique_class,
	})


func _on_action_resolved(action: BattleAction, results: Array[Dictionary]) -> void:
	_event_queue.append({
		"type": &"action_resolved",
		"action": action,
		"results": results,
	})


func _on_damage_dealt(
	side_index: int,
	slot_index: int,
	_amount: int,
	_effectiveness: StringName,
) -> void:
	_event_queue.append({
		"type": &"damage_dealt",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_energy_spent(side_index: int, slot_index: int, _amount: int) -> void:
	_event_queue.append({
		"type": &"energy_spent",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_energy_restored(side_index: int, slot_index: int, _amount: int) -> void:
	_event_queue.append({
		"type": &"energy_restored",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_hp_restored(side_index: int, slot_index: int, _amount: int) -> void:
	_event_queue.append({
		"type": &"hp_restored",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_stat_changed(
	side_index: int,
	slot_index: int,
	stat_key: StringName,
	stages: int,
) -> void:
	_event_queue.append({
		"type": &"stat_changed",
		"side_index": side_index,
		"slot_index": slot_index,
		"stat_key": stat_key,
		"stages": stages,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_digimon_fainted(side_index: int, slot_index: int) -> void:
	_event_queue.append({
		"type": &"digimon_fainted",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_digimon_switched(
	side_index: int,
	slot_index: int,
	_new_digimon: BattleDigimonState,
) -> void:
	_event_queue.append({
		"type": &"digimon_switched",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_status_applied(
	side_index: int,
	slot_index: int,
	_status_key: StringName,
) -> void:
	_event_queue.append({
		"type": &"status_applied",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_status_removed(
	side_index: int,
	slot_index: int,
	_status_key: StringName,
) -> void:
	_event_queue.append({
		"type": &"status_removed",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_turn_started(turn_number: int) -> void:
	_event_queue.append({
		"type": &"turn_started",
		"turn_number": turn_number,
	})


func _on_turn_ended(_turn_number: int) -> void:
	_event_queue.append({"type": &"turn_ended"})


func _on_battle_ended(result: BattleResult) -> void:
	_event_queue.append({
		"type": &"battle_ended",
		"result": result,
	})


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


func _position_battlefield() -> void:
	var vp_size: Vector2 = get_viewport_rect().size

	# FarSide: enemy sprites — top-right area, below foe panels
	_far_side.position = Vector2(vp_size.x * 0.50, vp_size.y * 0.18)
	_far_side.size = Vector2(vp_size.x * 0.35, vp_size.y * 0.25)

	# NearSide: ally sprites — bottom-left area
	_near_side.position = Vector2(vp_size.x * 0.08, vp_size.y * 0.38)
	_near_side.size = Vector2(vp_size.x * 0.35, vp_size.y * 0.25)


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
		var is_multi: bool = side.slots.size() > 1

		if is_multi:
			container.add_theme_constant_override("separation", 4)

		for slot: SlotState in side.slots:
			var vbox := VBoxContainer.new()
			var min_w: float = 64.0 if is_multi else 80.0
			vbox.custom_minimum_size = Vector2(min_w, 80)
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			# Try sprite first, fall back to ColorRect
			var sprite_added: bool = false
			if slot.digimon != null and slot.digimon.data != null:
				var sprite_tex: Texture2D = null
				if "sprite_texture" in slot.digimon.data:
					sprite_tex = slot.digimon.data.sprite_texture
				if sprite_tex != null:
					var tex_rect := TextureRect.new()
					tex_rect.texture = sprite_tex
					tex_rect.custom_minimum_size = Vector2(64, 64)
					tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
					tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex_rect.flip_h = not is_ally
					tex_rect.name = "SpriteRect"
					vbox.add_child(tex_rect)
					sprite_added = true

			if not sprite_added:
				var rect := ColorRect.new()
				rect.custom_minimum_size = Vector2(64, 64)
				rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
				rect.color = Color(0.3, 0.7, 0.3) if is_ally else Color(0.7, 0.3, 0.3)
				rect.name = "ColorRect"
				vbox.add_child(rect)

			vbox.name = "Slot_%d_%d" % [side.side_index, slot.slot_index]

			# Mouse input for hover bounce and sprite-based targeting
			vbox.mouse_filter = Control.MOUSE_FILTER_STOP
			var si: int = side.side_index
			var sli: int = slot.slot_index
			vbox.mouse_entered.connect(
				_on_sprite_mouse_entered.bind(si, sli)
			)
			vbox.mouse_exited.connect(
				_on_sprite_mouse_exited.bind(si, sli)
			)
			vbox.gui_input.connect(
				_on_sprite_gui_input.bind(si, sli)
			)

			container.add_child(vbox)


func _update_all_panels() -> void:
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			_update_panel(side.side_index, slot.slot_index)


func _update_panel_from_snapshot(
	side_index: int, slot_index: int, snapshot: Dictionary
) -> void:
	var key: String = "%d_%d" % [side_index, slot_index]
	var panel: DigimonPanel = null

	if _ally_panel_map.has(key):
		panel = _ally_panel_map[key] as DigimonPanel
	elif _foe_panel_map.has(key):
		panel = _foe_panel_map[key] as DigimonPanel

	if panel == null:
		return

	if snapshot.is_empty():
		var digimon: BattleDigimonState = _battle.get_digimon_at(side_index, slot_index)
		panel.update_from_battle_digimon(digimon)
	else:
		panel.update_from_snapshot(snapshot)


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
	panel.visible = (digimon != null)
	panel.update_from_battle_digimon(digimon)


func _update_placeholder(side_index: int, slot_index: int) -> void:
	var is_ally: bool = _battle.are_allies(0, side_index)
	var container: HBoxContainer = _near_side if is_ally else _far_side
	var node_name: String = "Slot_%d_%d" % [side_index, slot_index]

	var vbox: Node = container.get_node_or_null(node_name)
	if vbox == null:
		return

	var digimon: BattleDigimonState = _battle.get_digimon_at(side_index, slot_index)
	if digimon == null or digimon.data == null:
		return

	# Update sprite/colour
	var old_sprite: Node = vbox.get_node_or_null("SpriteRect")
	var old_color: Node = vbox.get_node_or_null("ColorRect")

	var sprite_tex: Texture2D = null
	if "sprite_texture" in digimon.data:
		sprite_tex = digimon.data.sprite_texture

	if sprite_tex != null:
		if old_sprite is TextureRect:
			(old_sprite as TextureRect).texture = sprite_tex
			(old_sprite as TextureRect).flip_h = not is_ally
		elif old_color != null:
			old_color.queue_free()
			var tex_rect := TextureRect.new()
			tex_rect.texture = sprite_tex
			tex_rect.custom_minimum_size = Vector2(64, 64)
			tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.flip_h = not is_ally
			tex_rect.name = "SpriteRect"
			vbox.add_child(tex_rect)
			vbox.move_child(tex_rect, 0)


## --- Hover Bounce ---


func _get_sprite_child(vbox: Node) -> Control:
	var sprite: Node = vbox.get_node_or_null("SpriteRect")
	if sprite is Control:
		return sprite as Control
	sprite = vbox.get_node_or_null("ColorRect")
	if sprite is Control:
		return sprite as Control
	return null


func _on_sprite_mouse_entered(side_index: int, slot_index: int) -> void:
	if _phase == BattlePhase.EXECUTING:
		return

	var key: String = "%d_%d" % [side_index, slot_index]

	# Skip if this is the active digimon (already bouncing)
	if key == _active_bounce_key:
		return

	var placeholder: Node = _get_battlefield_placeholder(side_index, slot_index)
	if placeholder == null:
		return

	var sprite: Control = _get_sprite_child(placeholder)
	if sprite == null:
		return

	# Kill existing hover tween for this slot
	if _hover_tweens.has(key) and _hover_tweens[key] is Tween:
		(_hover_tweens[key] as Tween).kill()

	var tween: Tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_hover_tweens[key] = tween


func _on_sprite_mouse_exited(side_index: int, slot_index: int) -> void:
	var key: String = "%d_%d" % [side_index, slot_index]
	if _hover_tweens.has(key) and _hover_tweens[key] is Tween:
		(_hover_tweens[key] as Tween).kill()
		_hover_tweens.erase(key)

	var placeholder: Node = _get_battlefield_placeholder(side_index, slot_index)
	if placeholder == null:
		return

	var sprite: Control = _get_sprite_child(placeholder)
	if sprite != null:
		sprite.position.y = 0.0


func _on_sprite_gui_input(
	event: InputEvent, side_index: int, slot_index: int
) -> void:
	if not _is_targeting:
		return
	if event is not InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var key: String = "%d_%d" % [side_index, slot_index]
	if _valid_target_map.has(key):
		_exit_targeting_mode()
		_target_selector.select_target(side_index, slot_index)


## --- Active Digimon Bounce ---


func _start_active_bounce(side_index: int, slot_index: int) -> void:
	_stop_active_bounce()
	_active_bounce_key = "%d_%d" % [side_index, slot_index]

	# Bounce the sprite child
	var placeholder: Node = _get_battlefield_placeholder(side_index, slot_index)
	if placeholder != null:
		var sprite: Control = _get_sprite_child(placeholder)
		if sprite != null:
			_active_bounce_tween = create_tween().set_loops()
			_active_bounce_tween.tween_property(
				sprite, "position:y", -6.0, 0.2
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			_active_bounce_tween.tween_property(
				sprite, "position:y", 0.0, 0.2
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	# Pulse the DigimonPanel scale
	var panel: DigimonPanel = _get_panel(side_index, slot_index)
	if panel != null:
		panel.pivot_offset = panel.size / 2.0
		_active_bounce_panel_tween = create_tween().set_loops()
		_active_bounce_panel_tween.tween_property(
			panel, "scale", Vector2(1.03, 1.03), 0.3
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_active_bounce_panel_tween.tween_property(
			panel, "scale", Vector2.ONE, 0.3
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_active_bounce() -> void:
	if _active_bounce_tween != null:
		_active_bounce_tween.kill()
		_active_bounce_tween = null

	if _active_bounce_panel_tween != null:
		_active_bounce_panel_tween.kill()
		_active_bounce_panel_tween = null

	if _active_bounce_key != "":
		var parts: PackedStringArray = _active_bounce_key.split("_")
		if parts.size() == 2:
			var si: int = int(parts[0])
			var sli: int = int(parts[1])

			var placeholder: Node = _get_battlefield_placeholder(si, sli)
			if placeholder != null:
				var sprite: Control = _get_sprite_child(placeholder)
				if sprite != null:
					sprite.position.y = 0.0

			var panel: DigimonPanel = _get_panel(si, sli)
			if panel != null:
				panel.scale = Vector2.ONE

		_active_bounce_key = ""


func _get_panel(side_index: int, slot_index: int) -> DigimonPanel:
	var key: String = "%d_%d" % [side_index, slot_index]
	if _ally_panel_map.has(key):
		return _ally_panel_map[key] as DigimonPanel
	if _foe_panel_map.has(key):
		return _foe_panel_map[key] as DigimonPanel
	return null


## --- Sprite-Based Targeting Mode ---


func _enter_targeting_mode(
	user: BattleDigimonState, targets: Array[Dictionary]
) -> void:
	_valid_target_map.clear()

	_hide_all_menus()
	_is_targeting = true
	_message_box.show_prompt("Select a target...")

	for target: Dictionary in targets:
		var si: int = int(target["side"])
		var sli: int = int(target["slot"])
		var key: String = "%d_%d" % [si, sli]
		_valid_target_map[key] = true

		var is_foe: bool = _battle.are_foes(user.side_index, si)
		var indicator_colour: TargetIndicator.IndicatorColour = \
			TargetIndicator.IndicatorColour.FOE if is_foe else \
			TargetIndicator.IndicatorColour.ALLY

		var indicator: TargetIndicator = TargetIndicator.create(indicator_colour)
		var placeholder: Node = _get_battlefield_placeholder(si, sli)
		if placeholder != null:
			var sprite: Control = _get_sprite_child(placeholder)
			if sprite != null:
				sprite.add_child(indicator)
				_target_indicators.append(indicator)

	_target_back_button.visible = true


func _exit_targeting_mode() -> void:
	_is_targeting = false
	_valid_target_map.clear()

	for indicator: TargetIndicator in _target_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	_target_indicators.clear()

	_target_back_button.visible = false
