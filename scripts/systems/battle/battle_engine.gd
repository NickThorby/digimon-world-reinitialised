class_name BattleEngine
extends RefCounted
## Core battle turn loop. Pure logic, signal-driven.
## The battle scene listens to signals and drives visual updates.


signal action_resolved(action: BattleAction, results: Array[Dictionary])
signal digimon_fainted(side_index: int, slot_index: int)
signal digimon_switched(side_index: int, slot_index: int, new_digimon: BattleDigimonState)
signal status_applied(side_index: int, slot_index: int, status_key: StringName)
signal status_removed(side_index: int, slot_index: int, status_key: StringName)
signal stat_changed(side_index: int, slot_index: int, stat_key: StringName, stages: int)
signal weather_changed(new_weather: Dictionary)
signal terrain_changed(new_terrain: Dictionary)
signal damage_dealt(side_index: int, slot_index: int, amount: int, effectiveness: StringName)
signal energy_spent(side_index: int, slot_index: int, amount: int)
signal energy_restored(side_index: int, slot_index: int, amount: int)
signal hp_restored(side_index: int, slot_index: int, amount: int)
signal battle_message(text: String)
signal technique_animation_requested(
	user_side: int, user_slot: int, technique_class: Registry.TechniqueClass,
	element_key: StringName, target_side: int, target_slot: int
)
signal hazard_applied(side_index: int, hazard_key: StringName)
signal hazard_removed(side_index: int, hazard_key: StringName)
signal side_effect_applied(side_index: int, effect_key: StringName)
signal side_effect_removed(side_index: int, effect_key: StringName)
signal global_effect_applied(effect_key: StringName)
signal global_effect_removed(effect_key: StringName)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal battle_ended(result: BattleResult)

var _battle: BattleState = null
var _balance: GameBalance = null


## Initialise the engine with a battle state.
func initialise(battle: BattleState) -> void:
	_battle = battle
	_balance = load("res://data/config/game_balance.tres") as GameBalance


## Execute a full turn with the given actions.
func execute_turn(actions: Array[BattleAction]) -> void:
	if _battle == null or _battle.is_battle_over:
		return

	# Start of turn
	_battle.turn_number += 1
	turn_started.emit(_battle.turn_number)

	# Reset per-turn ability trigger counters and increment turns on field
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		digimon.reset_turn_trigger_count()
		digimon.volatiles["turns_on_field"] = int(
			digimon.volatiles.get("turns_on_field", 0)
		) + 1

	# Fire ON_TURN_START abilities and gear
	_fire_ability_trigger(Registry.AbilityTrigger.ON_TURN_START)
	_fire_gear_trigger(Registry.AbilityTrigger.ON_TURN_START)

	# Sort actions
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)

	# Resolve each action
	for action: BattleAction in sorted:
		if _battle.is_battle_over:
			break
		if action.is_cancelled:
			continue

		# Verify actor is still alive
		var user: BattleDigimonState = _battle.get_digimon_at(
			action.user_side, action.user_slot
		)
		if user == null or user.is_fainted:
			continue

		# Retarget if the chosen target has fainted
		if action.action_type == BattleAction.ActionType.TECHNIQUE:
			_retarget_if_fainted(action, user)

		var results: Array[Dictionary] = _resolve_action(action)
		action_resolved.emit(action, results)

		# Clear fainted slots with no reserve
		_clear_fainted_no_reserve()

		if _battle.check_end_conditions():
			break

	# End of turn
	if not _battle.is_battle_over:
		_end_of_turn()

	turn_ended.emit(_battle.turn_number)

	if _battle.is_battle_over:
		battle_ended.emit(_battle.result)


## Resolve a single action by type.
func _resolve_action(action: BattleAction) -> Array[Dictionary]:
	# Pre-action status checks for technique actions
	if action.action_type == BattleAction.ActionType.TECHNIQUE:
		var user: BattleDigimonState = _battle.get_digimon_at(
			action.user_side, action.user_slot,
		)
		if user != null:
			# Confusion: 50% chance to use a random equipped technique
			if user.has_status(&"confused"):
				battle_message.emit("%s is confused!" % _get_digimon_name(user))
				if _battle.rng.randf() < 0.5 and user.equipped_technique_keys.size() > 0:
					var rand_idx: int = _battle.rng.randi() \
						% user.equipped_technique_keys.size()
					action.technique_key = user.equipped_technique_keys[rand_idx]

			# Encored: force the encored technique
			var encore_key: StringName = user.volatiles.get(
				"encore_technique_key", &"",
			) as StringName
			if encore_key != &"":
				action.technique_key = encore_key

	match action.action_type:
		BattleAction.ActionType.TECHNIQUE:
			return _resolve_technique(action)
		BattleAction.ActionType.SWITCH:
			return _resolve_switch(action)
		BattleAction.ActionType.REST:
			return _resolve_rest(action)
		BattleAction.ActionType.RUN:
			return _resolve_run(action)
		BattleAction.ActionType.ITEM:
			return _resolve_item(action)
	return []


## Resolve a technique action.
func _resolve_technique(action: BattleAction) -> Array[Dictionary]:
	var user: BattleDigimonState = _battle.get_digimon_at(action.user_side, action.user_slot)
	if user == null:
		return []

	var technique: TechniqueData = Atlas.techniques.get(action.technique_key) as TechniqueData
	if technique == null:
		battle_message.emit("%s tried to use an unknown technique!" % _get_digimon_name(user))
		return []

	# Pre-execution checks
	if not _pre_execution_check(user, technique):
		return []

	battle_message.emit("%s used %s!" % [_get_digimon_name(user), technique.display_name])
	technique_animation_requested.emit(
		action.user_side, action.user_slot, technique.technique_class,
		technique.element_key, action.target_side, action.target_slot
	)

	# Bleeding deals self-damage when using a technique
	if user.has_status(&"bleeding"):
		var bleed_dmg: int = maxi(user.max_hp / 8, 1)
		var actual_bleed: int = user.apply_damage(bleed_dmg)
		battle_message.emit("%s is bleeding!" % _get_digimon_name(user))
		damage_dealt.emit(user.side_index, user.slot_index, actual_bleed, &"bleeding")
		if _check_faint_or_threshold(user, null):
			return [{"bleeding_faint": true}]

	# Spend energy — handle overexertion
	var energy_cost: int = technique.energy_cost
	if user.has_status(&"exhausted"):
		energy_cost = ceili(float(energy_cost) * 1.5)
	if user.has_status(&"vitalised"):
		energy_cost = maxi(floori(float(energy_cost) * 0.5), 0)
	var overexertion_damage: int = 0

	if energy_cost > user.current_energy:
		var overexerted: int = energy_cost - user.current_energy
		overexertion_damage = DamageCalculator.calculate_overexertion(
			overexerted, user.source_state.level
		)
		user.spend_energy(energy_cost)
		energy_spent.emit(user.side_index, user.slot_index, energy_cost)

		# Apply overexertion self-damage
		var actual_self_damage: int = user.apply_damage(overexertion_damage)
		battle_message.emit("%s overexerted and took %d damage!" % [
			_get_digimon_name(user), actual_self_damage,
		])
		damage_dealt.emit(user.side_index, user.slot_index, actual_self_damage, &"overexertion")

		if _check_faint_or_threshold(user, null):
			return [{"overexertion_faint": true}]
	else:
		user.spend_energy(energy_cost)
		energy_spent.emit(user.side_index, user.slot_index, energy_cost)

	# Fire ON_BEFORE_TECHNIQUE abilities and gear
	_fire_ability_trigger(Registry.AbilityTrigger.ON_BEFORE_TECHNIQUE, {
		"subject": user, "technique": technique,
	})
	_fire_gear_trigger(Registry.AbilityTrigger.ON_BEFORE_TECHNIQUE, {
		"subject": user, "technique": technique,
	})

	# Resolve targets
	var targets: Array[BattleDigimonState] = _resolve_targets(
		user, technique.targeting, action.target_side, action.target_slot
	)

	# Execute against each target
	var all_results: Array[Dictionary] = []
	for target: BattleDigimonState in targets:
		if target.is_fainted:
			continue

		# Accuracy check (0 = always hits)
		if technique.accuracy > 0:
			var effective_accuracy: float = _calculate_accuracy(
				technique.accuracy, user, target,
			)
			var hit_roll: float = _battle.rng.randf() * 100.0
			if hit_roll > effective_accuracy:
				battle_message.emit("It missed %s!" % _get_digimon_name(target))
				all_results.append({"missed": true})
				continue

		# Execute bricks
		var brick_results: Array[Dictionary] = BrickExecutor.execute_bricks(
			technique.bricks, user, target, technique, _battle,
		)

		# Emit signals for results
		var dealt_damage: bool = false
		for brick_result: Dictionary in brick_results:
			if brick_result.get("damage", 0) > 0:
				var dmg: int = int(brick_result["damage"])
				var eff: StringName = brick_result.get(
					"effectiveness", &"neutral",
				) as StringName
				damage_dealt.emit(target.side_index, target.slot_index, dmg, eff)
				dealt_damage = true

				# Track participation
				if user.source_state != null and target.source_state != null:
					var foe_key: StringName = target.source_state.key
					if foe_key not in user.participated_against:
						user.participated_against.append(foe_key)

				if brick_result.get("was_critical", false):
					battle_message.emit("A critical hit!")

				match eff:
					&"super_effective":
						battle_message.emit("It's super effective!")
					&"not_very_effective":
						battle_message.emit("It's not very effective...")
					&"immune":
						battle_message.emit("It had no effect.")

			if brick_result.get("applied", false):
				var status_key: StringName = brick_result.get(
					"status", &"",
				) as StringName
				if status_key != &"":
					status_applied.emit(
						target.side_index, target.slot_index, status_key,
					)
					battle_message.emit("%s was afflicted with %s!" % [
						_get_digimon_name(target), str(status_key),
					])
					# Fire ON_STATUS_APPLIED for the target
					_fire_ability_trigger(
						Registry.AbilityTrigger.ON_STATUS_APPLIED,
						{"subject": target, "status_key": status_key},
					)

			# Stat modifier results from technique bricks
			var tech_stat_changes: Variant = brick_result.get("stat_changes")
			if tech_stat_changes is Array:
				for change: Dictionary in tech_stat_changes:
					var sc_target: BattleDigimonState = change.get(
						"target",
					) as BattleDigimonState
					if sc_target == null:
						sc_target = target
					var sc_key: StringName = change.get(
						"stat_key", &"",
					) as StringName
					var sc_actual: int = int(change.get("actual", 0))
					stat_changed.emit(
						sc_target.side_index, sc_target.slot_index,
						sc_key, sc_actual,
					)
					_emit_stat_change_message(
						_get_digimon_name(sc_target), sc_key,
						int(change.get("stages", 0)), sc_actual,
					)

			# Field effect results
			_emit_field_effect_signals(brick_result)

		all_results.append_array(brick_results)

		# Fire damage-related ability and gear triggers
		if dealt_damage:
			_fire_ability_trigger(Registry.AbilityTrigger.ON_DEAL_DAMAGE, {
				"subject": user, "target": target, "technique": technique,
			})
			_fire_gear_trigger(Registry.AbilityTrigger.ON_DEAL_DAMAGE, {
				"subject": user, "target": target, "technique": technique,
			})
			_fire_ability_trigger(Registry.AbilityTrigger.ON_TAKE_DAMAGE, {
				"subject": target, "attacker": user, "technique": technique,
			})
			_fire_gear_trigger(Registry.AbilityTrigger.ON_TAKE_DAMAGE, {
				"subject": target, "attacker": user, "technique": technique,
			})
		# Faint check first, then HP threshold (berry) if survived
		_check_faint_or_threshold(target, user)

	# Fire ON_AFTER_TECHNIQUE abilities and gear
	_fire_ability_trigger(Registry.AbilityTrigger.ON_AFTER_TECHNIQUE, {
		"subject": user, "technique": technique,
	})
	_fire_gear_trigger(Registry.AbilityTrigger.ON_AFTER_TECHNIQUE, {
		"subject": user, "technique": technique,
	})

	# Update volatiles
	user.volatiles["last_technique_key"] = action.technique_key

	return all_results


## Resolve a forced switch action (public API for battle_scene.gd).
func resolve_forced_switch(action: BattleAction) -> Array[Dictionary]:
	return _resolve_switch(action)


## Resolve a switch action.
func _resolve_switch(action: BattleAction) -> Array[Dictionary]:
	var side: SideState = _battle.sides[action.user_side]
	var slot: SlotState = side.slots[action.user_slot]

	if action.switch_to_party_index < 0 or action.switch_to_party_index >= side.party.size():
		return []

	var outgoing: BattleDigimonState = slot.digimon

	# Reset volatiles on outgoing
	if outgoing != null:
		outgoing.reset_volatiles()
		# Move outgoing to reserve (as its source state)
		if outgoing.source_state != null:
			# Write back current HP/energy/consumable before moving to reserve
			outgoing.source_state.current_hp = outgoing.current_hp
			outgoing.source_state.current_energy = outgoing.current_energy
			outgoing.source_state.equipped_consumable_key = outgoing.equipped_consumable_key
			side.party.append(outgoing.source_state)
		# Preserve for XP tracking
		side.retired_battle_digimon.append(outgoing)

	# Take new Digimon from reserve
	var new_state: DigimonState = side.party[action.switch_to_party_index]
	side.party.remove_at(action.switch_to_party_index)

	# Create battle Digimon
	var new_battle_mon: BattleDigimonState = BattleFactory.create_battle_digimon(
		new_state, action.user_side, action.user_slot,
	)

	# Carry forward participation data from previous stints
	for retired: BattleDigimonState in side.retired_battle_digimon:
		if retired.source_state == new_state:
			for foe_key: StringName in retired.participated_against:
				if foe_key not in new_battle_mon.participated_against:
					new_battle_mon.participated_against.append(foe_key)
			break

	slot.digimon = new_battle_mon

	var name_out: String = _get_digimon_name(outgoing) if outgoing else "?"
	var name_in: String = _get_digimon_name(new_battle_mon)
	battle_message.emit("%s switched out for %s!" % [name_out, name_in])
	digimon_switched.emit(action.user_side, action.user_slot, new_battle_mon)

	# Apply entry hazards before abilities/gear
	_apply_entry_hazards(new_battle_mon)
	if new_battle_mon.is_fainted:
		return [{"switched": true, "fainted_on_entry": true}]

	# Fire ON_ENTRY abilities and gear for the incoming Digimon
	_fire_ability_trigger(
		Registry.AbilityTrigger.ON_ENTRY, {"subject": new_battle_mon},
	)
	_fire_gear_trigger(
		Registry.AbilityTrigger.ON_ENTRY, {"subject": new_battle_mon},
	)

	return [{"switched": true}]


## Resolve a rest action (restore energy).
func _resolve_rest(action: BattleAction) -> Array[Dictionary]:
	var user: BattleDigimonState = _battle.get_digimon_at(action.user_side, action.user_slot)
	if user == null:
		return []

	var regen_pct: float = _balance.energy_regen_on_rest if _balance else 0.25
	var amount: int = maxi(floori(float(user.max_energy) * regen_pct), 1)
	user.restore_energy(amount)
	energy_restored.emit(user.side_index, user.slot_index, amount)

	# Rest removes bleeding
	if user.has_status(&"bleeding"):
		user.remove_status(&"bleeding")
		status_removed.emit(user.side_index, user.slot_index, &"bleeding")
		battle_message.emit("%s stopped bleeding." % _get_digimon_name(user))

	battle_message.emit("%s rested and recovered %d energy." % [
		_get_digimon_name(user), amount,
	])

	return [{"rested": true, "energy_restored": amount}]


## Resolve a run action.
func _resolve_run(action: BattleAction) -> Array[Dictionary]:
	# Check if any foe side is wild
	var can_run: bool = false
	for side: SideState in _battle.sides:
		if _battle.are_foes(action.user_side, side.side_index) and side.is_wild:
			can_run = true
			break

	if not can_run:
		battle_message.emit("Can't run from this battle!")
		return [{"run_failed": true}]

	battle_message.emit("Got away safely!")
	_battle.is_battle_over = true
	_battle.result = BattleResult.new()
	_battle.result.outcome = BattleResult.Outcome.FLED
	_battle.result.turn_count = _battle.turn_number
	battle_ended.emit(_battle.result)

	return [{"fled": true}]


## Resolve an item action.
func _resolve_item(action: BattleAction) -> Array[Dictionary]:
	var side: SideState = _battle.sides[action.user_side]
	var user: BattleDigimonState = _battle.get_digimon_at(
		action.user_side, action.user_slot,
	)
	if user == null:
		return []

	# Validate item exists in bag
	if side.bag == null or not side.bag.has_item(action.item_key):
		battle_message.emit("No item to use!")
		return [{"handled": false, "reason": "no_item"}]

	var item: ItemData = Atlas.items.get(action.item_key) as ItemData
	if item == null:
		battle_message.emit("Unknown item!")
		return [{"handled": false, "reason": "unknown_item"}]

	# Consume from bag
	side.bag.remove_item(action.item_key)

	# Route by category
	match item.category:
		Registry.ItemCategory.MEDICINE:
			return _resolve_medicine(action, item, side, user)
		Registry.ItemCategory.CAPTURE_SCAN:
			return _resolve_capture_item(action, item)
		_:
			battle_message.emit(
				"%s used %s!" % [_get_digimon_name(user), item.name],
			)
			return [{"handled": true, "item_used": action.item_key}]


## Resolve a medicine item targeting a party member.
func _resolve_medicine(
	action: BattleAction,
	item: ItemData,
	side: SideState,
	user: BattleDigimonState,
) -> Array[Dictionary]:
	battle_message.emit(
		"%s used %s!" % [_get_digimon_name(user), item.name],
	)

	# Build full roster: active slot Digimon + party reserves
	var roster: Array[Dictionary] = _get_full_roster(side)
	var party_idx: int = action.item_target_party_index

	if party_idx < 0 or party_idx >= roster.size():
		battle_message.emit("No valid target!")
		return [{"handled": false, "reason": "invalid_target"}]

	var entry: Dictionary = roster[party_idx]
	var is_active: bool = entry.get("is_active", false) as bool
	var all_results: Array[Dictionary] = []

	if is_active:
		# Target is an active BattleDigimonState
		var target: BattleDigimonState = entry.get(
			"battle_digimon",
		) as BattleDigimonState
		if target == null or (target.is_fainted and not item.is_revive):
			battle_message.emit("It won't have any effect!")
			return [{"handled": false, "reason": "invalid_active_target"}]

		# Handle revive on active fainted Digimon
		if item.is_revive and target.is_fainted:
			target.is_fainted = false
			for brick: Dictionary in item.bricks:
				var result: Dictionary = BrickExecutor.execute_brick(
					brick, target, target, null, _battle,
				)
				_process_item_result(result, target)
				all_results.append(result)
			return all_results

		# Normal medicine on active Digimon
		for brick: Dictionary in item.bricks:
			var result: Dictionary = BrickExecutor.execute_brick(
				brick, target, target, null, _battle,
			)
			_process_item_result(result, target)
			all_results.append(result)
	else:
		# Target is a reserve DigimonState
		var reserve: DigimonState = entry.get("digimon_state") as DigimonState
		if reserve == null:
			return [{"handled": false, "reason": "invalid_reserve_target"}]

		if item.is_revive and reserve.current_hp <= 0:
			# Apply healing bricks directly to reserve DigimonState
			for brick: Dictionary in item.bricks:
				var brick_type: String = brick.get("brick", "")
				if brick_type == "healing":
					var subtype: String = brick.get("type", "fixed")
					var data: DigimonData = Atlas.digimon.get(
						reserve.key,
					) as DigimonData
					var max_hp: int = _estimate_max_hp(reserve, data)
					match subtype:
						"fixed":
							var amount: int = int(brick.get("amount", 0))
							reserve.current_hp = mini(
								reserve.current_hp + amount, max_hp,
							)
						"percentage":
							var percent: float = float(brick.get("percent", 0))
							var amount: int = maxi(
								floori(float(max_hp) * percent / 100.0), 1,
							)
							reserve.current_hp = mini(
								reserve.current_hp + amount, max_hp,
							)
					all_results.append({
						"handled": true,
						"healing": reserve.current_hp,
						"reserve_revive": true,
					})
			hp_restored.emit(
				-1, -1, reserve.current_hp,
			)
			battle_message.emit(
				"%s was revived!" % _get_reserve_name(reserve),
			)
		elif not item.is_revive and reserve.current_hp > 0:
			# Heal a non-fainted reserve
			var data: DigimonData = Atlas.digimon.get(
				reserve.key,
			) as DigimonData
			var max_hp: int = _estimate_max_hp(reserve, data)
			for brick: Dictionary in item.bricks:
				var brick_type: String = brick.get("brick", "")
				if brick_type == "healing":
					var subtype: String = brick.get("type", "fixed")
					match subtype:
						"fixed":
							var amount: int = int(brick.get("amount", 0))
							var actual: int = mini(
								amount, max_hp - reserve.current_hp,
							)
							reserve.current_hp += actual
							all_results.append({
								"handled": true, "healing": actual,
							})
						"percentage":
							var percent: float = float(brick.get("percent", 0))
							var amount: int = maxi(
								floori(float(max_hp) * percent / 100.0), 1,
							)
							var actual: int = mini(
								amount, max_hp - reserve.current_hp,
							)
							reserve.current_hp += actual
							all_results.append({
								"handled": true, "healing": actual,
							})

	return all_results


## Resolve a capture/scan item.
func _resolve_capture_item(
	action: BattleAction, item: ItemData,
) -> Array[Dictionary]:
	battle_message.emit("Used %s! Capture is not yet implemented." % item.name)
	return [{"handled": true, "capture": true, "item_key": action.item_key}]


## Build the full roster for a side: active Digimon first, then reserves.
## Returns [{is_active, battle_digimon?, digimon_state?, name}].
func _get_full_roster(side: SideState) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for slot: SlotState in side.slots:
		if slot.digimon != null:
			roster.append({
				"is_active": true,
				"battle_digimon": slot.digimon,
				"digimon_state": slot.digimon.source_state,
				"name": _get_digimon_name(slot.digimon),
			})
	for reserve: DigimonState in side.party:
		roster.append({
			"is_active": false,
			"digimon_state": reserve,
			"name": _get_reserve_name(reserve),
		})
	return roster


## Process a single item brick result — emit signals for HP/energy/status.
func _process_item_result(
	result: Dictionary, target: BattleDigimonState,
) -> void:
	if result.get("healing", 0) > 0:
		var heal: int = int(result["healing"])
		hp_restored.emit(target.side_index, target.slot_index, heal)
		battle_message.emit(
			"%s restored %d HP!" % [_get_digimon_name(target), heal],
		)

	if result.get("energy_restored", 0) > 0:
		var amount: int = int(result["energy_restored"])
		energy_restored.emit(target.side_index, target.slot_index, amount)
		battle_message.emit(
			"%s restored %d energy!" % [_get_digimon_name(target), amount],
		)

	var cured: Variant = result.get("statuses_cured")
	if cured is Array:
		for status_str: Variant in (cured as Array):
			var status_key: StringName = StringName(str(status_str))
			status_removed.emit(
				target.side_index, target.slot_index, status_key,
			)
			battle_message.emit(
				"%s was cured of %s!" % [
					_get_digimon_name(target), str(status_key),
				],
			)

	var sc_changes: Variant = result.get("stat_changes")
	if sc_changes is Array:
		for change: Dictionary in sc_changes:
			var sc_target: BattleDigimonState = change.get(
				"target",
			) as BattleDigimonState
			if sc_target == null:
				sc_target = target
			var sc_key: StringName = change.get("stat_key", &"") as StringName
			var sc_actual: int = int(change.get("actual", 0))
			stat_changed.emit(
				sc_target.side_index, sc_target.slot_index,
				sc_key, sc_actual,
			)
			_emit_stat_change_message(
				_get_digimon_name(sc_target), sc_key,
				int(change.get("stages", 0)), sc_actual,
			)


## Estimate max HP for a reserve DigimonState (not on field).
func _estimate_max_hp(state: DigimonState, data: DigimonData) -> int:
	if data == null:
		return 100
	var stats: Dictionary = StatCalculator.calculate_all_stats(data, state)
	var personality: PersonalityData = Atlas.personalities.get(
		state.personality_key,
	) as PersonalityData
	var hp: int = stats.get(&"hp", 100)
	hp = StatCalculator.apply_personality(hp, &"hp", personality)
	return hp


## Get display name for a reserve DigimonState.
func _get_reserve_name(state: DigimonState) -> String:
	if state == null:
		return "???"
	if state.nickname != "":
		return state.nickname
	var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
	if data != null:
		return data.display_name
	return "???"


## Fire ON_ENTRY abilities and gear for all starting Digimon.
func start_battle() -> void:
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		_fire_ability_trigger(Registry.AbilityTrigger.ON_ENTRY, {"subject": digimon})
		_fire_gear_trigger(Registry.AbilityTrigger.ON_ENTRY, {"subject": digimon})


## Centralised ability trigger dispatcher. Checks all active Digimon (or just
## context["subject"]) for abilities matching the given trigger, respects stack
## limits and nullified status, then executes the ability's bricks.
func _fire_ability_trigger(
	trigger: Registry.AbilityTrigger, context: Dictionary = {},
) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []
	var subjects: Array[BattleDigimonState] = []

	if context.has("subject"):
		var subject: BattleDigimonState = context["subject"] as BattleDigimonState
		if subject != null:
			subjects.append(subject)
	else:
		subjects = _battle.get_active_digimon()

	for digimon: BattleDigimonState in subjects:
		if digimon.is_fainted or digimon.ability_key == &"":
			continue

		var ability: AbilityData = Atlas.abilities.get(
			digimon.ability_key
		) as AbilityData
		if ability == null:
			continue
		if ability.trigger != trigger:
			continue
		if not digimon.can_trigger_ability(ability.stack_limit):
			continue
		if not _check_trigger_condition(digimon, ability.trigger_condition, context):
			continue

		digimon.record_ability_trigger(ability.stack_limit)
		battle_message.emit(
			"%s's %s!" % [_get_digimon_name(digimon), ability.name]
		)

		for brick: Dictionary in ability.bricks:
			var targets: Array[BattleDigimonState] = _resolve_ability_targets(
				digimon, brick,
			)
			for target: BattleDigimonState in targets:
				if target.is_fainted:
					continue
				var result: Dictionary = BrickExecutor.execute_brick(
					brick, digimon, target, null, _battle,
				)
				_process_ability_result(result, digimon, target)
				all_results.append(result)

	return all_results


## Centralised gear trigger dispatcher. Mirrors _fire_ability_trigger() but
## checks both equipped_gear_key and equipped_consumable_key on each Digimon.
## Consumable gear is cleared after firing.
func _fire_gear_trigger(
	trigger: Registry.AbilityTrigger, context: Dictionary = {},
) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []
	var subjects: Array[BattleDigimonState] = []

	if context.has("subject"):
		var subject: BattleDigimonState = context["subject"] as BattleDigimonState
		if subject != null:
			subjects.append(subject)
	else:
		subjects = _battle.get_active_digimon()

	for digimon: BattleDigimonState in subjects:
		if digimon.is_fainted:
			continue

		# Check suppression: dazed or gear_suppression field effect
		if digimon.has_status(&"dazed"):
			continue
		if _battle.field.has_global_effect(&"gear_suppression"):
			continue

		# Check both gear slots
		var gear_keys: Array[Dictionary] = []
		if digimon.equipped_gear_key != &"":
			gear_keys.append({
				"key": digimon.equipped_gear_key, "is_consumable": false,
			})
		if digimon.equipped_consumable_key != &"":
			gear_keys.append({
				"key": digimon.equipped_consumable_key, "is_consumable": true,
			})

		for gear_entry: Dictionary in gear_keys:
			var gear_key: StringName = gear_entry["key"] as StringName
			var is_consumable: bool = gear_entry.get("is_consumable", false)
			var gear: Variant = Atlas.items.get(gear_key)
			if gear is not GearData:
				continue
			var gear_data: GearData = gear as GearData
			if gear_data.trigger != trigger:
				continue
			if not digimon.can_trigger_gear(gear_data.stack_limit, is_consumable):
				continue
			if not _check_trigger_condition(
				digimon, gear_data.trigger_condition, context,
			):
				continue

			digimon.record_gear_trigger(gear_data.stack_limit, is_consumable)
			battle_message.emit(
				"%s's %s!" % [_get_digimon_name(digimon), gear_data.name],
			)

			for brick: Dictionary in gear_data.bricks:
				var targets: Array[BattleDigimonState] = \
					_resolve_ability_targets(digimon, brick)
				for target: BattleDigimonState in targets:
					if target.is_fainted:
						continue
					var result: Dictionary = BrickExecutor.execute_brick(
						brick, digimon, target, null, _battle,
					)
					_process_ability_result(result, digimon, target)
					all_results.append(result)

			# If consumable gear fired, consume it
			if is_consumable:
				digimon.equipped_consumable_key = &""
				battle_message.emit(
					"%s's %s was consumed!" % [
						_get_digimon_name(digimon), gear_data.name,
					],
				)

	return all_results


## Process a single ability brick result — emit signals for stat changes and
## status effects so the UI event queue picks them up.
func _process_ability_result(
	result: Dictionary,
	_user: BattleDigimonState,
	target: BattleDigimonState,
) -> void:
	var sc_changes: Variant = result.get("stat_changes")
	if sc_changes is Array:
		for change: Dictionary in sc_changes:
			var sc_target: BattleDigimonState = change.get(
				"target"
			) as BattleDigimonState
			if sc_target == null:
				sc_target = target
			var sc_key: StringName = change.get("stat_key", &"") as StringName
			var sc_actual: int = int(change.get("actual", 0))
			stat_changed.emit(
				sc_target.side_index, sc_target.slot_index, sc_key, sc_actual,
			)
			_emit_stat_change_message(
				_get_digimon_name(sc_target), sc_key,
				int(change.get("stages", 0)), sc_actual,
			)

	if result.get("applied", false):
		var status_key: StringName = result.get("status", &"") as StringName
		if status_key != &"":
			status_applied.emit(
				target.side_index, target.slot_index, status_key,
			)
			battle_message.emit("%s was afflicted with %s!" % [
				_get_digimon_name(target), str(status_key),
			])

	if result.get("damage", 0) > 0:
		var dmg: int = int(result["damage"])
		var eff: StringName = result.get("effectiveness", &"neutral") as StringName
		damage_dealt.emit(target.side_index, target.slot_index, dmg, eff)

	if result.get("healing", 0) > 0:
		var heal: int = int(result["healing"])
		hp_restored.emit(target.side_index, target.slot_index, heal)


## Check whether an ability's trigger_condition is met.
## Uses BrickConditionEvaluator for generalised condition string evaluation.
func _check_trigger_condition(
	digimon: BattleDigimonState,
	condition: String,
	context: Dictionary,
) -> bool:
	if condition == "":
		return true
	var eval_context: Dictionary = context.duplicate()
	eval_context["user"] = digimon
	eval_context["battle"] = _battle
	return BrickConditionEvaluator.evaluate(condition, eval_context)


## Resolve ability brick targets from brick-level target field.
func _resolve_ability_targets(
	user: BattleDigimonState, brick: Dictionary
) -> Array[BattleDigimonState]:
	var brick_target: String = brick.get("target", "self")
	var targets: Array[BattleDigimonState] = []

	match brick_target:
		"self":
			targets.append(user)
		"allFoes":
			for side: SideState in _battle.sides:
				if _battle.are_foes(user.side_index, side.side_index):
					for slot: SlotState in side.slots:
						if slot.digimon != null and not slot.digimon.is_fainted:
							targets.append(slot.digimon)
		"allAllies":
			for side: SideState in _battle.sides:
				if _battle.are_allies(user.side_index, side.side_index):
					for slot: SlotState in side.slots:
						if slot.digimon != null and not slot.digimon.is_fainted:
							targets.append(slot.digimon)
		"target":
			# No single target context for abilities; skip
			pass
		_:
			targets.append(user)

	return targets


## Emit a battle message describing a stat change.
func _emit_stat_change_message(
	digimon_name: String, stat_key: StringName, stages: int, actual: int,
) -> void:
	var stat_label: String = str(stat_key).replace("_", " ").capitalize()
	if actual == 0:
		if stages > 0:
			battle_message.emit("%s's %s won't go any higher!" % [digimon_name, stat_label])
		else:
			battle_message.emit("%s's %s won't go any lower!" % [digimon_name, stat_label])
		return

	var change_text: String = ""
	var abs_actual: int = absi(actual)
	if actual > 0:
		match abs_actual:
			1: change_text = "rose!"
			2: change_text = "rose sharply!"
			_: change_text = "rose drastically!"
	else:
		match abs_actual:
			1: change_text = "fell!"
			2: change_text = "fell harshly!"
			_: change_text = "fell severely!"

	battle_message.emit("%s's %s %s" % [digimon_name, stat_label, change_text])


## Pre-execution checks for technique use.
func _pre_execution_check(user: BattleDigimonState, technique: TechniqueData) -> bool:
	# Check sleep
	if user.has_status(&"asleep"):
		# Decrement duration, check if waking up
		for status: Dictionary in user.status_conditions:
			if status.get("key", &"") == &"asleep":
				var duration: int = int(status.get("duration", 0)) - 1
				if duration <= 0:
					user.remove_status(&"asleep")
					status_removed.emit(user.side_index, user.slot_index, &"asleep")
					battle_message.emit("%s woke up!" % _get_digimon_name(user))
				else:
					status["duration"] = duration
					battle_message.emit("%s is fast asleep." % _get_digimon_name(user))
					return false

	# Check frozen
	if user.has_status(&"frozen"):
		# Check for defrost flag
		var has_defrost: bool = false
		if technique.flags.has(Registry.TechniqueFlag.DEFROST):
			has_defrost = true

		if has_defrost:
			user.remove_status(&"frozen")
			status_removed.emit(user.side_index, user.slot_index, &"frozen")
			battle_message.emit("%s thawed out!" % _get_digimon_name(user))
		else:
			for status: Dictionary in user.status_conditions:
				if status.get("key", &"") == &"frozen":
					var duration: int = int(status.get("duration", 0)) - 1
					if duration <= 0:
						user.remove_status(&"frozen")
						status_removed.emit(user.side_index, user.slot_index, &"frozen")
						battle_message.emit("%s thawed out!" % _get_digimon_name(user))
					else:
						status["duration"] = duration
						battle_message.emit("%s is frozen solid!" % _get_digimon_name(user))
						return false

	# Check paralysis (may fail to act)
	if user.has_status(&"paralysed"):
		if _battle.rng.randf() < 0.25:
			battle_message.emit("%s is paralysed and can't move!" % _get_digimon_name(user))
			return false

	# Taunted: block STATUS-class techniques
	if user.has_status(&"taunted"):
		if technique.technique_class == Registry.TechniqueClass.STATUS:
			battle_message.emit(
				"%s can't use %s — it's taunted!" % [
					_get_digimon_name(user), technique.display_name,
				]
			)
			return false

	# Encored: force the encored technique (handled by swapping in _resolve_action)
	# Disabled: block the disabled technique
	var disabled_key: StringName = user.volatiles.get(
		"disabled_technique_key", &"",
	) as StringName
	if disabled_key != &"" and technique.key == disabled_key:
		battle_message.emit(
			"%s can't use %s — it's disabled!" % [
				_get_digimon_name(user), technique.display_name,
			]
		)
		return false

	return true


## Resolve targeting enum to actual BattleDigimonState targets.
func _resolve_targets(
	user: BattleDigimonState,
	targeting: Registry.Targeting,
	target_side: int,
	target_slot: int,
) -> Array[BattleDigimonState]:
	var targets: Array[BattleDigimonState] = []

	match targeting:
		Registry.Targeting.SELF:
			targets.append(user)

		Registry.Targeting.SINGLE_FOE, \
		Registry.Targeting.SINGLE_TARGET, \
		Registry.Targeting.SINGLE_OTHER, \
		Registry.Targeting.SINGLE_ALLY:
			var target: BattleDigimonState = _battle.get_digimon_at(target_side, target_slot)
			if target != null:
				targets.append(target)

		Registry.Targeting.ALL_FOES:
			for side: SideState in _battle.sides:
				if _battle.are_foes(user.side_index, side.side_index):
					for slot: SlotState in side.slots:
						if slot.digimon != null and not slot.digimon.is_fainted:
							targets.append(slot.digimon)

		Registry.Targeting.ALL_ALLIES:
			for side: SideState in _battle.sides:
				if _battle.are_allies(user.side_index, side.side_index):
					for slot: SlotState in side.slots:
						if slot.digimon != null and not slot.digimon.is_fainted:
							targets.append(slot.digimon)

		Registry.Targeting.ALL_OTHER_ALLIES:
			for side: SideState in _battle.sides:
				if _battle.are_allies(user.side_index, side.side_index):
					for slot: SlotState in side.slots:
						if slot.digimon != null and not slot.digimon.is_fainted:
							if slot.digimon != user:
								targets.append(slot.digimon)

		Registry.Targeting.ALL:
			for digimon: BattleDigimonState in _battle.get_active_digimon():
				targets.append(digimon)

		Registry.Targeting.ALL_OTHER:
			for digimon: BattleDigimonState in _battle.get_active_digimon():
				if digimon != user:
					targets.append(digimon)

		Registry.Targeting.FIELD:
			# Field-targeting techniques don't target specific Digimon
			targets.append(user)  # Use self as context

	# Fallback: if single targeting had no valid target, pick a random foe
	if targets.is_empty() and targeting in [
		Registry.Targeting.SINGLE_FOE,
		Registry.Targeting.SINGLE_TARGET,
		Registry.Targeting.SINGLE_OTHER,
	]:
		var foes: Array[BattleDigimonState] = []
		for side: SideState in _battle.sides:
			if _battle.are_foes(user.side_index, side.side_index):
				for slot: SlotState in side.slots:
					if slot.digimon != null and not slot.digimon.is_fainted:
						foes.append(slot.digimon)
		if foes.size() > 0:
			targets.append(foes[_battle.rng.randi() % foes.size()])

	return targets


## End-of-turn processing.
func _end_of_turn() -> void:
	# 1. Status condition ticks (faint/threshold handled inside)
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		_tick_status_conditions(digimon)

	_clear_fainted_no_reserve()

	# 1b. Weather tick damage
	_tick_weather_damage()

	_clear_fainted_no_reserve()

	# 2. Field duration ticks
	var expired: Dictionary = _battle.field.tick_durations()
	if expired.get("weather", false):
		battle_message.emit("The weather returned to normal.")
		weather_changed.emit({})
		_fire_ability_trigger(Registry.AbilityTrigger.ON_WEATHER_CHANGE)
	if expired.get("terrain", false):
		battle_message.emit("The terrain returned to normal.")
		terrain_changed.emit({})
		_fire_ability_trigger(Registry.AbilityTrigger.ON_TERRAIN_CHANGE)

	# 2b. Expired global effects
	var expired_globals: Variant = expired.get("global_effects", [])
	if expired_globals is Array:
		for key: Variant in expired_globals:
			var effect_key: StringName = key as StringName
			battle_message.emit("%s wore off." % str(effect_key))
			global_effect_removed.emit(effect_key)

	# 3. Side effect ticks
	for side: SideState in _battle.sides:
		var expired_effects: Array[StringName] = side.tick_durations()
		for effect_key: StringName in expired_effects:
			battle_message.emit("%s wore off." % str(effect_key))
			side_effect_removed.emit(side.side_index, effect_key)

	# 4. Energy regeneration (5% per turn for all active Digimon)
	var regen_pct: float = _balance.energy_regen_per_turn if _balance else 0.05
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		var amount: int = maxi(floori(float(digimon.max_energy) * regen_pct), 1)
		digimon.restore_energy(amount)
		energy_restored.emit(digimon.side_index, digimon.slot_index, amount)

	# 4b. Energy regeneration for reserve Digimon (same rate, applied to DigimonState)
	for side: SideState in _battle.sides:
		for state: DigimonState in side.party:
			if state.current_hp <= 0:
				continue
			var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
			if data == null:
				continue
			var all_stats: Dictionary = StatCalculator.calculate_all_stats(
				data, state,
			)
			var personality: PersonalityData = Atlas.personalities.get(
				state.personality_key,
			) as PersonalityData
			var max_en: int = StatCalculator.apply_personality(
				all_stats.get(&"energy", 1), &"energy", personality,
			)
			var amt: int = maxi(floori(float(max_en) * regen_pct), 1)
			state.current_energy = mini(state.current_energy + amt, max_en)

	# 5. Fire ON_TURN_END abilities and gear
	_fire_ability_trigger(Registry.AbilityTrigger.ON_TURN_END)
	_fire_gear_trigger(Registry.AbilityTrigger.ON_TURN_END)

	# 6. Check end conditions
	_battle.check_end_conditions()


## Tick status conditions for a single Digimon.
## Returns true if the Digimon fainted during status ticks.
func _tick_status_conditions(digimon: BattleDigimonState) -> bool:
	var to_remove: Array[StringName] = []

	for status: Dictionary in digimon.status_conditions:
		var key: StringName = status.get("key", &"") as StringName
		var key_str: String = str(key).to_lower()

		# Apply DoT effects
		match key_str:
			"burned":
				var dot: int = maxi(digimon.max_hp / 16, 1)
				digimon.apply_damage(dot)
				battle_message.emit("%s is hurt by its burn!" % _get_digimon_name(digimon))
				damage_dealt.emit(digimon.side_index, digimon.slot_index, dot, &"burn")
				if _check_faint_or_threshold(digimon, null):
					return true
			"frostbitten":
				var dot: int = maxi(digimon.max_hp / 16, 1)
				digimon.apply_damage(dot)
				battle_message.emit(
					"%s is hurt by frostbite!" % _get_digimon_name(digimon)
				)
				damage_dealt.emit(digimon.side_index, digimon.slot_index, dot, &"frostbite")
				if _check_faint_or_threshold(digimon, null):
					return true
			"poisoned":
				var dot: int = maxi(digimon.max_hp / 8, 1)
				digimon.apply_damage(dot)
				battle_message.emit(
					"%s is hurt by poison!" % _get_digimon_name(digimon)
				)
				damage_dealt.emit(digimon.side_index, digimon.slot_index, dot, &"poison")
				if _check_faint_or_threshold(digimon, null):
					return true
			"seeded":
				var dot: int = maxi(digimon.max_hp / 8, 1)
				digimon.apply_damage(dot)
				battle_message.emit(
					"%s had its energy drained by the seed!" % _get_digimon_name(digimon)
				)
				damage_dealt.emit(digimon.side_index, digimon.slot_index, dot, &"seeded")
				# Heal the seeder
				var seeder_side: int = int(status.get("seeder_side", -1))
				var seeder_slot: int = int(status.get("seeder_slot", -1))
				if seeder_side >= 0 and seeder_slot >= 0:
					var seeder: BattleDigimonState = _battle.get_digimon_at(
						seeder_side, seeder_slot,
					)
					if seeder != null and not seeder.is_fainted:
						var healed: int = seeder.restore_hp(dot)
						if healed > 0:
							hp_restored.emit(seeder.side_index, seeder.slot_index, healed)
				if _check_faint_or_threshold(digimon, null):
					return true
			"regenerating":
				var heal: int = maxi(digimon.max_hp / 16, 1)
				digimon.restore_hp(heal)
				battle_message.emit(
					"%s regenerated some HP." % _get_digimon_name(digimon)
				)
				hp_restored.emit(digimon.side_index, digimon.slot_index, heal)
			"perishing":
				var countdown: int = int(status.get("countdown", 3)) - 1
				status["countdown"] = countdown
				battle_message.emit(
					"%s's perish count fell to %d!" % [_get_digimon_name(digimon), countdown]
				)
				if countdown <= 0:
					digimon.apply_damage(digimon.current_hp)
					battle_message.emit(
						"%s was taken by the perish count!" % _get_digimon_name(digimon)
					)
					if _check_faint_or_threshold(digimon, null):
						return true

		# Tick duration
		var duration: int = int(status.get("duration", -1))
		if duration > 0:
			status["duration"] = duration - 1
			if duration - 1 <= 0:
				to_remove.append(key)

	# Remove expired statuses
	for key: StringName in to_remove:
		digimon.remove_status(key)
		status_removed.emit(digimon.side_index, digimon.slot_index, key)

	return false


## Handle a Digimon fainting — emit signal, update counters, fire faint triggers.
func _handle_faint(
	fainted: BattleDigimonState, killer: BattleDigimonState,
) -> void:
	battle_message.emit("%s fainted!" % _get_digimon_name(fainted))
	digimon_fainted.emit(fainted.side_index, fainted.slot_index)

	# Update foe/ally faint counters for all active Digimon
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		if digimon == fainted:
			continue
		if _battle.are_foes(digimon.side_index, fainted.side_index):
			digimon.counters["foes_fainted"] = \
				int(digimon.counters.get("foes_fainted", 0)) + 1
		elif _battle.are_allies(digimon.side_index, fainted.side_index):
			digimon.counters["allies_fainted"] = \
				int(digimon.counters.get("allies_fainted", 0)) + 1

	# Track killer's foe faint for XP (also handled by counter above)
	if killer != null and _battle.are_foes(killer.side_index, fainted.side_index):
		# Track participation
		if killer.source_state != null and fainted.source_state != null:
			var foe_key: StringName = fainted.source_state.key
			if foe_key not in killer.participated_against:
				killer.participated_against.append(foe_key)

	# Fire faint ability triggers
	_fire_ability_trigger(
		Registry.AbilityTrigger.ON_FAINT, {"subject": fainted},
	)
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		if digimon == fainted:
			continue
		if _battle.are_foes(digimon.side_index, fainted.side_index):
			_fire_ability_trigger(
				Registry.AbilityTrigger.ON_FOE_FAINT, {"subject": digimon},
			)
		elif _battle.are_allies(digimon.side_index, fainted.side_index):
			_fire_ability_trigger(
				Registry.AbilityTrigger.ON_ALLY_FAINT, {"subject": digimon},
			)


## After damage, check faint. If survived, fire HP threshold triggers (berry etc.).
## Returns true if the Digimon fainted.
func _check_faint_or_threshold(
	digimon: BattleDigimonState, killer: BattleDigimonState = null,
) -> bool:
	if digimon.check_faint():
		_handle_faint(digimon, killer)
		return true
	_fire_ability_trigger(Registry.AbilityTrigger.ON_HP_THRESHOLD, {
		"subject": digimon,
	})
	_fire_gear_trigger(Registry.AbilityTrigger.ON_HP_THRESHOLD, {
		"subject": digimon,
	})
	return false


## Retarget a technique action if the original target has fainted.
## Picks a random valid target based on the technique's targeting type.
func _retarget_if_fainted(
	action: BattleAction, user: BattleDigimonState
) -> void:
	var target: BattleDigimonState = _battle.get_digimon_at(
		action.target_side, action.target_slot
	)
	if target != null and not target.is_fainted:
		return  # Target is still alive

	var technique: TechniqueData = Atlas.techniques.get(
		action.technique_key
	) as TechniqueData
	if technique == null:
		return

	# Only retarget single-target techniques
	if technique.targeting not in [
		Registry.Targeting.SINGLE_FOE,
		Registry.Targeting.SINGLE_TARGET,
		Registry.Targeting.SINGLE_OTHER,
		Registry.Targeting.SINGLE_ALLY,
	]:
		return

	# Gather valid replacement targets
	var candidates: Array[BattleDigimonState] = []
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			if slot.digimon == null or slot.digimon.is_fainted:
				continue
			if slot.digimon == user:
				continue

			match technique.targeting:
				Registry.Targeting.SINGLE_FOE:
					if _battle.are_foes(user.side_index, side.side_index):
						candidates.append(slot.digimon)
				Registry.Targeting.SINGLE_ALLY:
					if _battle.are_allies(
						user.side_index, side.side_index
					):
						candidates.append(slot.digimon)
				Registry.Targeting.SINGLE_OTHER:
					candidates.append(slot.digimon)
				Registry.Targeting.SINGLE_TARGET:
					candidates.append(slot.digimon)

	if candidates.is_empty():
		return  # No valid targets — technique will fizzle

	var new_target: BattleDigimonState = candidates[
		_battle.rng.randi() % candidates.size()
	]
	action.target_side = new_target.side_index
	action.target_slot = new_target.slot_index


## Clear fainted Digimon from slots when no reserves are available.
## This removes them from the field entirely in multi-slot battles.
func _clear_fainted_no_reserve() -> void:
	for side: SideState in _battle.sides:
		if side.slots.size() <= 1:
			continue  # Single-slot sides keep the fainted mon for display
		var has_reserve: bool = false
		for digimon: DigimonState in side.party:
			if digimon.current_hp > 0:
				has_reserve = true
				break
		if has_reserve:
			continue
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.is_fainted:
				slot.digimon = null


## Calculate effective accuracy factoring user accuracy stage, target evasion stage,
## and the blinded status condition.
func _calculate_accuracy(
	base_accuracy: int, user: BattleDigimonState, target: BattleDigimonState,
) -> float:
	var acc_stage: int = user.stat_stages.get(&"accuracy", 0)
	var eva_stage: int = target.stat_stages.get(&"evasion", 0)
	var acc_mult: float = Registry.STAT_STAGE_MULTIPLIERS.get(acc_stage, 1.0)
	var eva_mult: float = Registry.STAT_STAGE_MULTIPLIERS.get(eva_stage, 1.0)
	var effective: float = float(base_accuracy) * acc_mult / eva_mult
	if user.has_status(&"blinded"):
		effective *= 0.5
	return effective


## Apply weather tick damage at end of turn.
func _tick_weather_damage() -> void:
	if not _battle.field.has_weather():
		return

	var weather_key: StringName = _battle.field.weather.get(
		"key", &"",
	) as StringName
	var percent: float = _balance.weather_tick_damage_percent if _balance \
		else 0.0625

	# Determine which weather deals tick damage and which elements are immune
	var immune_elements: Array[StringName] = []
	match str(weather_key):
		"sandstorm":
			immune_elements = [&"earth", &"metal"] as Array[StringName]
		"hail":
			immune_elements = [&"ice"] as Array[StringName]
		_:
			return  # sun/rain don't deal tick damage

	for digimon: BattleDigimonState in _battle.get_active_digimon():
		if digimon.is_fainted:
			continue

		# Check element trait immunity
		var is_immune: bool = false
		if digimon.data != null:
			for elem: StringName in digimon.data.element_traits:
				if elem in immune_elements:
					is_immune = true
					break
		if is_immune:
			continue

		var damage: int = maxi(
			floori(float(digimon.max_hp) * percent), 1,
		)
		var actual: int = digimon.apply_damage(damage)
		battle_message.emit(
			"%s is buffeted by the %s! (%d damage)" % [
				_get_digimon_name(digimon), str(weather_key), actual,
			],
		)
		damage_dealt.emit(
			digimon.side_index, digimon.slot_index,
			actual, &"weather",
		)
		_check_faint_or_threshold(digimon, null)


## Apply entry hazards to a Digimon switching in.
func _apply_entry_hazards(digimon: BattleDigimonState) -> void:
	var side: SideState = _battle.sides[digimon.side_index]
	for hazard: Dictionary in side.hazards:
		if digimon.is_fainted:
			break
		var key: StringName = hazard.get("key", &"") as StringName
		var layers: int = int(hazard.get("layers", 1))

		# Check for grounding field disabling aerial trait
		var has_aerial: bool = false
		if digimon.data != null:
			has_aerial = &"aerial" in digimon.data.element_traits
		if has_aerial and _battle.field.has_global_effect(&"grounding_field"):
			has_aerial = false

		if hazard.has("damagePercent"):
			# Entry damage hazard
			var percent: float = float(hazard["damagePercent"])
			var element: StringName = hazard.get(
				"element", &"",
			) as StringName

			# Element resistance scaling
			var resistance: float = 1.0
			if element != &"" and digimon.data != null:
				resistance = float(
					digimon.data.resistances.get(element, 1.0),
				)

			# Immune (0.0 resistance) = no damage
			if resistance <= 0.0:
				battle_message.emit(
					"%s is immune to the hazard!" \
						% _get_digimon_name(digimon),
				)
				continue

			var damage: int = maxi(
				floori(float(digimon.max_hp) * percent * float(layers) \
					* resistance), 1,
			)
			var actual: int = digimon.apply_damage(damage)
			battle_message.emit(
				"%s was hurt by %s! (%d damage)" % [
					_get_digimon_name(digimon), str(key), actual,
				],
			)
			damage_dealt.emit(
				digimon.side_index, digimon.slot_index,
				actual, &"hazard",
			)
			hazard_applied.emit(digimon.side_index, key)
			if _check_faint_or_threshold(digimon, null):
				return

		elif hazard.has("stat"):
			# Entry stat reduction hazard
			var stat_abbr: String = String(hazard["stat"])
			var stages: int = int(hazard.get("stages", -1))
			var battle_stat: Variant = Registry.BRICK_STAT_MAP.get(
				stat_abbr,
			)
			if battle_stat == null:
				continue
			var stage_key: Variant = Registry.BATTLE_STAT_STAGE_KEYS.get(
				battle_stat,
			)
			if stage_key == null:
				continue
			var stat_key: StringName = stage_key as StringName
			var actual: int = digimon.modify_stat_stage(stat_key, stages)
			stat_changed.emit(
				digimon.side_index, digimon.slot_index,
				stat_key, actual,
			)
			_emit_stat_change_message(
				_get_digimon_name(digimon), stat_key, stages, actual,
			)
			hazard_applied.emit(digimon.side_index, key)


## Emit signals for field effect, side effect, and hazard brick results.
func _emit_field_effect_signals(result: Dictionary) -> void:
	# Weather
	if result.has("weather"):
		var key: StringName = result["weather"] as StringName
		var action: String = result.get("action", "set")
		if action == "set":
			battle_message.emit("The weather changed to %s!" % str(key))
			weather_changed.emit(_battle.field.weather)
			_fire_ability_trigger(Registry.AbilityTrigger.ON_WEATHER_CHANGE)
		else:
			battle_message.emit("The weather cleared.")
			weather_changed.emit({})
			_fire_ability_trigger(Registry.AbilityTrigger.ON_WEATHER_CHANGE)

	# Terrain
	if result.has("terrain"):
		var key: StringName = result["terrain"] as StringName
		var action: String = result.get("action", "set")
		if action == "set":
			battle_message.emit("The terrain changed to %s!" % str(key))
			terrain_changed.emit(_battle.field.terrain)
			_fire_ability_trigger(Registry.AbilityTrigger.ON_TERRAIN_CHANGE)
		else:
			battle_message.emit("The terrain cleared.")
			terrain_changed.emit({})
			_fire_ability_trigger(Registry.AbilityTrigger.ON_TERRAIN_CHANGE)

	# Global effect
	if result.has("global"):
		var key: StringName = result["global"] as StringName
		var action: String = result.get("action", "set")
		if action == "set":
			battle_message.emit("%s is now active!" % str(key))
			global_effect_applied.emit(key)
		else:
			battle_message.emit("%s wore off." % str(key))
			global_effect_removed.emit(key)

	# Side effect
	if result.has("effect"):
		var key: StringName = result["effect"] as StringName
		var action: String = result.get("action", "set")
		if action == "set":
			battle_message.emit("%s was set up!" % str(key))
		else:
			battle_message.emit("%s was removed." % str(key))

	# Hazard
	if result.has("hazard"):
		var key: StringName = result["hazard"] as StringName
		var action: String = result.get("action", "set")
		if action == "set":
			battle_message.emit("Hazard %s was laid!" % str(key))
		elif action == "remove":
			battle_message.emit("Hazard %s was cleared." % str(key))
		elif action == "removeAll":
			battle_message.emit("All hazards were cleared!")


## Get display name for a BattleDigimonState.
func _get_digimon_name(digimon: BattleDigimonState) -> String:
	if digimon == null:
		return "???"
	if digimon.source_state != null and digimon.source_state.nickname != "":
		return digimon.source_state.nickname
	if digimon.data != null:
		return digimon.data.display_name
	return "???"
