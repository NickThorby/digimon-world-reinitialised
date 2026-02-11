class_name BattleEventReplay
extends Node
## Manages the event queue, replays engine signals with delays and animations,
## and captures digimon snapshots for deferred panel updates.


@warning_ignore("unused_signal")
signal replay_finished()

var _battle: BattleState = null
var _event_queue: Array[Dictionary] = []


func initialise(battle: BattleState) -> void:
	_battle = battle


## Connect all engine signals to queue capture handlers.
func connect_engine_signals(engine: BattleEngine) -> void:
	engine.battle_message.connect(_on_battle_message)
	engine.technique_animation_requested.connect(_on_technique_animation_requested)
	engine.damage_dealt.connect(_on_damage_dealt)
	engine.energy_spent.connect(_on_energy_spent)
	engine.energy_restored.connect(_on_energy_restored)
	engine.hp_restored.connect(_on_hp_restored)
	engine.digimon_fainted.connect(_on_digimon_fainted)
	engine.digimon_switched.connect(_on_digimon_switched)
	engine.stat_changed.connect(_on_stat_changed)
	engine.status_applied.connect(_on_status_applied)
	engine.status_removed.connect(_on_status_removed)
	engine.hazard_applied.connect(_on_hazard_applied)
	engine.hazard_removed.connect(_on_hazard_removed)
	engine.side_effect_applied.connect(_on_side_effect_applied)
	engine.side_effect_removed.connect(_on_side_effect_removed)
	engine.global_effect_applied.connect(_on_global_effect_applied)
	engine.global_effect_removed.connect(_on_global_effect_removed)
	engine.weather_changed.connect(_on_weather_changed)
	engine.terrain_changed.connect(_on_terrain_changed)
	engine.turn_started.connect(_on_turn_started)
	engine.turn_ended.connect(_on_turn_ended)
	engine.battle_ended.connect(_on_battle_ended)
	engine.action_resolved.connect(_on_action_resolved)


func clear_queue() -> void:
	_event_queue.clear()


func is_queue_empty() -> bool:
	return _event_queue.is_empty()


## Extract the snapshot from a queued digimon_switched event (pre-hazard HP).
func extract_switch_snapshot(
	side_index: int, slot_index: int,
) -> Dictionary:
	for event: Dictionary in _event_queue:
		if event.get("type", &"") == &"digimon_switched" \
				and int(event.get("side_index", -1)) == side_index \
				and int(event.get("slot_index", -1)) == slot_index:
			return event.get("snapshot", {}) as Dictionary
	return {}


## Remove switch-related events from the queue (used when switch is handled inline).
func filter_switch_events() -> void:
	var filtered: Array[Dictionary] = []
	for event: Dictionary in _event_queue:
		var event_type: StringName = event.get("type", &"") as StringName
		if event_type != &"digimon_switched":
			filtered.append(event)
	_event_queue = filtered


## Replay all queued events with delays and animations.
## Requires references to the scene components for display updates.
func replay_events(
	scene: Node,
	message_box: BattleMessageBox,
	display: BattlefieldDisplay,
	turn_label: Label,
	post_battle_screen: PostBattleScreen,
	field_display: FieldStatusDisplay = null,
	ally_side_display: SideStatusDisplay = null,
	foe_side_display: SideStatusDisplay = null,
) -> void:
	for event: Dictionary in _event_queue:
		if not scene.is_inside_tree():
			return
		var event_type: StringName = event.get("type", &"") as StringName

		match event_type:
			&"battle_message":
				await message_box.show_message(event["text"] as String)

			&"technique_animation":
				var duration: float = display.play_attack_animation(
					int(event["user_side"]),
					int(event["user_slot"]),
					event["technique_class"] as Registry.TechniqueClass,
					event.get("element_key", &"") as StringName,
					int(event.get("target_side", -1)),
					int(event.get("target_slot", -1)),
				)
				if duration > 0.0:
					await scene.get_tree().create_timer(duration).timeout

			&"action_resolved":
				pass

			&"damage_dealt":
				var dmg_side: int = int(event["side_index"])
				var dmg_slot: int = int(event["slot_index"])
				var src_label: StringName = event.get(
					"source_label", &"",
				) as StringName
				var hit_dur: float = display.anim_status_hurt(
					dmg_side, dmg_slot, src_label,
				)
				if hit_dur <= 0.0:
					hit_dur = display.anim_hit(dmg_side, dmg_slot)
				display.update_panel_from_snapshot(
					dmg_side, dmg_slot,
					event.get("snapshot", {}) as Dictionary,
				)
				if hit_dur > 0.0:
					await scene.get_tree().create_timer(hit_dur).timeout
				await scene.get_tree().create_timer(0.15).timeout

			&"energy_spent":
				display.update_panel_from_snapshot(
					int(event["side_index"]), int(event["slot_index"]),
					event.get("snapshot", {}) as Dictionary,
				)

			&"energy_restored":
				var er_side: int = int(event["side_index"])
				var er_slot: int = int(event["slot_index"])
				var rest_dur: float = display.anim_rest(er_side, er_slot)
				display.update_panel_from_snapshot(
					er_side, er_slot,
					event.get("snapshot", {}) as Dictionary,
				)
				if rest_dur > 0.0:
					await scene.get_tree().create_timer(rest_dur).timeout
				await scene.get_tree().create_timer(0.15).timeout

			&"hp_restored":
				display.update_panel_from_snapshot(
					int(event["side_index"]), int(event["slot_index"]),
					event.get("snapshot", {}) as Dictionary,
				)
				await scene.get_tree().create_timer(0.3).timeout

			&"stat_changed":
				var sc_side: int = int(event["side_index"])
				var sc_slot: int = int(event["slot_index"])
				var sc_stages: int = int(event["stages"])
				display.update_panel_from_snapshot(
					sc_side, sc_slot,
					event.get("snapshot", {}) as Dictionary,
				)
				if sc_stages > 0:
					var raise_dur: float = display.anim_stat_raise(
						sc_side, sc_slot,
					)
					if raise_dur > 0.0:
						await scene.get_tree().create_timer(raise_dur).timeout
				elif sc_stages < 0:
					var lower_dur: float = display.anim_stat_lower(
						sc_side, sc_slot,
					)
					if lower_dur > 0.0:
						await scene.get_tree().create_timer(lower_dur).timeout

			&"digimon_fainted":
				var faint_side: int = int(event["side_index"])
				var faint_slot: int = int(event["slot_index"])
				display.update_panel_from_snapshot(
					faint_side, faint_slot,
					event.get("snapshot", {}) as Dictionary,
				)
				await scene.get_tree().create_timer(0.5).timeout
				var faint_out_dur: float = display.anim_switch_out(
					faint_side, faint_slot,
				)
				if faint_out_dur > 0.0:
					await scene.get_tree().create_timer(faint_out_dur).timeout
				display.set_panel_visible(faint_side, faint_slot, false)

			&"digimon_switched":
				var side_idx: int = int(event["side_index"])
				var slot_idx: int = int(event["slot_index"])
				display.set_panel_visible(side_idx, slot_idx, false)
				var out_dur: float = display.anim_switch_out(
					side_idx, slot_idx,
				)
				if out_dur > 0.0:
					await scene.get_tree().create_timer(out_dur).timeout
				display.update_panel_from_snapshot(
					side_idx, slot_idx,
					event.get("snapshot", {}) as Dictionary,
				)
				display.update_placeholder(side_idx, slot_idx)
				display.set_panel_visible(side_idx, slot_idx, true)
				var in_dur: float = display.anim_switch_in(
					side_idx, slot_idx,
				)
				if in_dur > 0.0:
					await scene.get_tree().create_timer(in_dur).timeout

			&"status_applied":
				var sa_side: int = int(event["side_index"])
				var sa_slot: int = int(event["slot_index"])
				var sa_key: StringName = event.get(
					"status_key", &"",
				) as StringName
				var sa_dur: float = display.anim_status_afflicted(
					sa_side, sa_slot, sa_key,
				)
				if sa_dur > 0.0:
					await scene.get_tree().create_timer(sa_dur).timeout
				display.update_panel_from_snapshot(
					sa_side, sa_slot,
					event.get("snapshot", {}) as Dictionary,
				)

			&"status_removed":
				display.update_panel_from_snapshot(
					int(event["side_index"]), int(event["slot_index"]),
					event.get("snapshot", {}) as Dictionary,
				)

			&"turn_started":
				turn_label.text = "Turn %d" % int(event["turn_number"])

			&"turn_ended":
				display.update_all_panels()
				if field_display != null:
					field_display.refresh()
				if ally_side_display != null:
					ally_side_display.refresh_from_side(
						_battle.sides[0],
					)
				if foe_side_display != null \
						and _battle.sides.size() > 1:
					foe_side_display.refresh_from_side(
						_battle.sides[1],
					)

			&"weather_changed", &"terrain_changed":
				if field_display != null:
					field_display.refresh()

			&"global_effect_applied", &"global_effect_removed":
				if field_display != null:
					field_display.refresh()

			&"side_effect_applied", &"side_effect_removed", \
			&"hazard_applied", &"hazard_removed":
				if ally_side_display != null:
					ally_side_display.refresh_from_side(
						_battle.sides[0],
					)
				if foe_side_display != null \
						and _battle.sides.size() > 1:
					foe_side_display.refresh_from_side(
						_battle.sides[1],
					)

			&"battle_ended":
				var result: BattleResult = event.get("result") as BattleResult

				# Write back to source states (active slots)
				for side: SideState in _battle.sides:
					for slot: SlotState in side.slots:
						if slot.digimon != null:
							slot.digimon.current_energy = slot.digimon.max_energy
							slot.digimon.write_back()
					# Restore energy for retired Digimon
					for retired: BattleDigimonState in side.retired_battle_digimon:
						if retired.source_state != null:
							retired.current_energy = retired.max_energy
							retired.source_state.current_energy = \
								retired.current_energy

				# XP awards
				if _battle.config.xp_enabled \
						and result.outcome == BattleResult.Outcome.WIN:
					result.xp_awards = XPCalculator.calculate_xp_awards(
						_battle, _battle.config.exp_share_enabled,
					)

				# Populate party_digimon for post-battle display
				if result.winning_team >= 0:
					var seen: Array[DigimonState] = []
					var has_owned: bool = false
					for side: SideState in _battle.sides:
						if side.team_index == result.winning_team \
								and side.is_owned:
							has_owned = true
							break
					for side: SideState in _battle.sides:
						if side.team_index != result.winning_team:
							continue
						if has_owned and not side.is_owned:
							continue
						for slot: SlotState in side.slots:
							if slot.digimon != null \
									and slot.digimon.source_state != null \
									and slot.digimon.source_state \
										not in seen:
								seen.append(slot.digimon.source_state)
						for reserve: DigimonState in side.party:
							if reserve not in seen:
								seen.append(reserve)
					result.party_digimon = seen

				post_battle_screen.show_results(result)

	_event_queue.clear()


## --- Engine Signal Handlers (Queue Events) ---


## Capture a digimon's current values for deferred panel updates.
func _snapshot_digimon(side_index: int, slot_index: int) -> Dictionary:
	var digimon: BattleDigimonState = _battle.get_digimon_at(
		side_index, slot_index,
	)
	if digimon == null:
		return {}
	var digimon_name: String = "???"
	if digimon.source_state != null and digimon.source_state.nickname != "":
		digimon_name = digimon.source_state.nickname
	elif digimon.data != null:
		digimon_name = digimon.data.display_name
	return {
		"name": digimon_name,
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
	user_side: int, user_slot: int, technique_class: Registry.TechniqueClass,
	element_key: StringName, target_side: int, target_slot: int
) -> void:
	_event_queue.append({
		"type": &"technique_animation",
		"user_side": user_side,
		"user_slot": user_slot,
		"technique_class": technique_class,
		"element_key": element_key,
		"target_side": target_side,
		"target_slot": target_slot,
	})


func _on_action_resolved(
	action: BattleAction, results: Array[Dictionary]
) -> void:
	_event_queue.append({
		"type": &"action_resolved",
		"action": action,
		"results": results,
	})


func _on_damage_dealt(
	side_index: int,
	slot_index: int,
	_amount: int,
	source_label: StringName,
) -> void:
	_event_queue.append({
		"type": &"damage_dealt",
		"side_index": side_index,
		"slot_index": slot_index,
		"source_label": source_label,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_energy_spent(
	side_index: int, slot_index: int, _amount: int
) -> void:
	_event_queue.append({
		"type": &"energy_spent",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_energy_restored(
	side_index: int, slot_index: int, _amount: int
) -> void:
	_event_queue.append({
		"type": &"energy_restored",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_hp_restored(
	side_index: int, slot_index: int, _amount: int
) -> void:
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
	side_index: int, slot_index: int, status_key: StringName
) -> void:
	_event_queue.append({
		"type": &"status_applied",
		"side_index": side_index,
		"slot_index": slot_index,
		"status_key": status_key,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_status_removed(
	side_index: int, slot_index: int, _status_key: StringName
) -> void:
	_event_queue.append({
		"type": &"status_removed",
		"side_index": side_index,
		"slot_index": slot_index,
		"snapshot": _snapshot_digimon(side_index, slot_index),
	})


func _on_weather_changed(new_weather: Dictionary) -> void:
	_event_queue.append({
		"type": &"weather_changed", "weather": new_weather,
	})


func _on_terrain_changed(new_terrain: Dictionary) -> void:
	_event_queue.append({
		"type": &"terrain_changed", "terrain": new_terrain,
	})


func _on_hazard_applied(side_index: int, hazard_key: StringName) -> void:
	_event_queue.append({
		"type": &"hazard_applied",
		"side_index": side_index,
		"key": hazard_key,
	})


func _on_hazard_removed(side_index: int, hazard_key: StringName) -> void:
	_event_queue.append({
		"type": &"hazard_removed",
		"side_index": side_index,
		"key": hazard_key,
	})


func _on_side_effect_applied(
	side_index: int, effect_key: StringName,
) -> void:
	_event_queue.append({
		"type": &"side_effect_applied",
		"side_index": side_index,
		"key": effect_key,
	})


func _on_side_effect_removed(
	side_index: int, effect_key: StringName,
) -> void:
	_event_queue.append({
		"type": &"side_effect_removed",
		"side_index": side_index,
		"key": effect_key,
	})


func _on_global_effect_applied(effect_key: StringName) -> void:
	_event_queue.append({
		"type": &"global_effect_applied", "key": effect_key,
	})


func _on_global_effect_removed(effect_key: StringName) -> void:
	_event_queue.append({
		"type": &"global_effect_removed", "key": effect_key,
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
