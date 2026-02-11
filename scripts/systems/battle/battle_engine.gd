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
	_battle.last_technique_used_key = &""
	turn_started.emit(_battle.turn_number)

	# Reset per-turn state for all active Digimon
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		digimon.reset_turn_trigger_count()
		digimon.volatiles["turns_on_field"] = int(
			digimon.volatiles.get("turns_on_field", 0)
		) + 1
		# Clear previous turn's protection; reset streak if not used last turn
		digimon.volatiles.erase("protection")
		if not digimon.volatiles.get("used_protection_this_turn", false):
			digimon.volatiles["consecutive_protection_uses"] = 0
		digimon.volatiles.erase("used_protection_this_turn")

	# Fire ON_TURN_START abilities and gear
	_fire_ability_trigger(Registry.AbilityTrigger.ON_TURN_START)
	_fire_gear_trigger(Registry.AbilityTrigger.ON_TURN_START)

	# Sort actions
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)

	# Resolve each action (mutable queue for turn order manipulation)
	var action_queue: Array[BattleAction] = sorted.duplicate()
	var action_idx: int = 0
	while action_idx < action_queue.size():
		if _battle.is_battle_over:
			break
		var action: BattleAction = action_queue[action_idx]
		if action.is_cancelled:
			action_idx += 1
			continue

		# Verify actor is still alive
		var user: BattleDigimonState = _battle.get_digimon_at(
			action.user_side, action.user_slot
		)
		if user == null or user.is_fainted:
			action_idx += 1
			continue

		# Pre-action state checks (recharging, multi-turn lock, charging)
		var pre_action: Dictionary = _check_pre_action_state(user, action)
		if pre_action.get("skip_action", false):
			action_idx += 1
			continue
		if pre_action.get("override_technique", &"") != &"":
			action.technique_key = pre_action["override_technique"] as StringName

		# Retarget if the chosen target has fainted
		if action.action_type == BattleAction.ActionType.TECHNIQUE:
			_retarget_if_fainted(action, user)

		var results: Array[Dictionary] = _resolve_action(action)
		action_resolved.emit(action, results)

		# Process turn order manipulation from brick results
		_process_turn_order(action_queue, action_idx, results)

		# Clear fainted slots with no reserve
		_clear_fainted_no_reserve()

		if _battle.check_end_conditions():
			break
		action_idx += 1

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


## Resolve a technique action (orchestrator).
func _resolve_technique(action: BattleAction) -> Array[Dictionary]:
	var user: BattleDigimonState = _battle.get_digimon_at(
		action.user_side, action.user_slot,
	)
	if user == null:
		return []

	var technique: TechniqueData = Atlas.techniques.get(
		action.technique_key,
	) as TechniqueData
	if technique == null:
		battle_message.emit(
			"%s tried to use an unknown technique!" \
				% _get_digimon_name(user),
		)
		return []

	if not _pre_execution_check(user, technique):
		return []

	var req_check: Dictionary = BrickExecutor.check_requirements(
		user, null, technique, _battle,
	)
	if req_check.get("failed", false):
		var fail_msg: String = req_check.get("fail_message", "")
		if fail_msg != "":
			battle_message.emit(fail_msg)
		else:
			battle_message.emit(
				"%s can't use %s!" % [
					_get_digimon_name(user), technique.display_name,
				],
			)
		return [{"requirement_failed": true}]

	battle_message.emit(
		"%s used %s!" % [_get_digimon_name(user), technique.display_name],
	)
	technique_animation_requested.emit(
		action.user_side, action.user_slot, technique.technique_class,
		technique.element_key, action.target_side, action.target_slot,
	)

	# Apply costs (bleeding, energy, overexertion)
	var cost_result: Dictionary = _apply_technique_costs(user, technique)
	if cost_result.get("aborted", false):
		var abort_results: Array[Dictionary] = []
		abort_results.assign(cost_result.get("results", []))
		return abort_results

	# Handle turn economy initialisation (charge, multi-turn first turn)
	var econ: Dictionary = _handle_turn_economy_init(
		user, technique, action,
	)
	if econ.get("aborted", false):
		var abort_results: Array[Dictionary] = []
		abort_results.assign(econ.get("results", []))
		return abort_results

	# Setup technique context (triggers, redirect, targets, flags, hit count)
	var ctx: Dictionary = _setup_technique_context(
		user, technique, action, econ,
	)
	technique = ctx["technique"] as TechniqueData

	# Execute against each target
	var all_results: Array[Dictionary] = _execute_against_targets(
		user, technique, action, ctx,
	)

	# Post-execution finalisation
	_finalise_technique(user, technique, action, econ, all_results)

	return all_results


## Apply pre-execution costs: bleeding self-damage, energy cost with
## exhausted/vitalised modifiers, and overexertion damage.
## Returns {aborted: bool, results?: Array[Dictionary]}.
func _apply_technique_costs(
	user: BattleDigimonState, technique: TechniqueData,
) -> Dictionary:
	# Bleeding deals self-damage when using a technique
	if user.has_status(&"bleeding"):
		var bleed_dmg: int = maxi(user.max_hp / 8, 1)
		battle_message.emit("%s is bleeding!" % _get_digimon_name(user))
		var bleed_result: Dictionary = _apply_damage_and_emit(
			user, bleed_dmg, &"bleeding",
		)
		if bleed_result["fainted"]:
			return {"aborted": true, "results": [{"bleeding_faint": true}]}

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
			overexerted, user.source_state.level,
		)
		user.spend_energy(energy_cost)
		energy_spent.emit(user.side_index, user.slot_index, energy_cost)

		# Apply overexertion self-damage
		var overexert_result: Dictionary = _apply_damage_and_emit(
			user, overexertion_damage, &"overexertion",
		)
		battle_message.emit("%s overexerted and took %d damage!" % [
			_get_digimon_name(user), int(overexert_result["actual"]),
		])
		if overexert_result["fainted"]:
			return {
				"aborted": true,
				"results": [{"overexertion_faint": true}],
			}
	else:
		user.spend_energy(energy_cost)
		energy_spent.emit(user.side_index, user.slot_index, energy_cost)

	return {"aborted": false}


## Handle turn economy initialisation: charge requirements and multi-turn
## semi-invulnerable first turn. Returns economy data and whether to abort.
func _handle_turn_economy_init(
	user: BattleDigimonState, technique: TechniqueData,
	action: BattleAction,
) -> Dictionary:
	var turn_econ: Dictionary = BrickExecutor.evaluate_turn_economy(technique)

	# Skip turn economy initialisation if pre-action already handled it
	var skip_init: bool = user.volatiles.get(
		"skip_turn_economy_init", false,
	)
	user.volatiles.erase("skip_turn_economy_init")

	# First-turn charge: if charge_requirement present and NOT already charging
	var charge_req: Variant = turn_econ.get("charge_requirement")
	if charge_req is Dictionary and not skip_init:
		var cr: Dictionary = charge_req as Dictionary
		var already_charging: Variant = user.volatiles.get("charging")
		var not_charging: bool = not (already_charging is Dictionary) \
			or (already_charging as Dictionary).is_empty()
		if not_charging:
			# Check weather/terrain skip
			var skip_weather: String = cr.get("skip_in_weather", "")
			var skip_terrain: String = cr.get("skip_in_terrain", "")
			var weather_skip: bool = skip_weather != "" \
				and _battle.field.has_weather(StringName(skip_weather))
			var terrain_skip: bool = skip_terrain != "" \
				and _battle.field.has_terrain(StringName(skip_terrain))
			if not weather_skip and not terrain_skip:
				# Begin charging — no bricks execute this turn
				user.volatiles["charging"] = {
					"technique_key": action.technique_key,
					"turns_remaining": int(
						cr.get("turns_to_charge", 1),
					),
					"skip_in_weather": skip_weather,
					"skip_in_terrain": skip_terrain,
				}
				var semi_inv: String = cr.get("semi_invulnerable", "")
				if semi_inv != "":
					user.volatiles["semi_invulnerable"] = \
						StringName(semi_inv)
				battle_message.emit(
					"%s began charging!" % _get_digimon_name(user),
				)
				return {
					"aborted": true,
					"results": [{"charging_started": true}],
				}

	# First-turn multi-turn with semi-invulnerable (Fly pattern)
	var multi_turn: Variant = turn_econ.get("multi_turn")
	var semi_inv_key: String = turn_econ.get("semi_invulnerable", "")
	if multi_turn is Dictionary and not skip_init:
		var mt: Dictionary = multi_turn as Dictionary
		var already_locked: Variant = user.volatiles.get(
			"multi_turn_lock",
		)
		var not_locked: bool = not (already_locked is Dictionary) \
			or (already_locked as Dictionary).is_empty()
		if not_locked:
			var min_hits: int = int(mt.get("min_hits", 2))
			var max_hits: int = int(mt.get("max_hits", 2))
			var duration: int = _battle.rng.randi_range(
				min_hits, max_hits,
			)
			var locked_in: bool = mt.get("locked_in", false)

			if semi_inv_key != "":
				# Fly pattern: preparation turn (no damage)
				user.volatiles["multi_turn_lock"] = {
					"technique_key": action.technique_key,
					"remaining": duration - 1,
					"locked_in": locked_in,
					"semi_invulnerable": semi_inv_key,
				}
				user.volatiles["semi_invulnerable"] = \
					StringName(semi_inv_key)
				battle_message.emit(
					"%s flew up high!" % _get_digimon_name(user),
				)
				return {
					"aborted": true,
					"results": [{"multi_turn_preparation": true}],
				}
			# Outrage pattern: execute normally, then set lock
			# (lock is set after execution in _finalise_technique)

	return {
		"aborted": false,
		"turn_econ": turn_econ,
		"skip_init": skip_init,
		"multi_turn": multi_turn,
		"semi_inv_key": semi_inv_key,
	}


## Setup technique context: fire ON_BEFORE_TECHNIQUE triggers, handle random
## redirect, resolve targets, scan flags and conditional bonuses, determine
## hit count. Returns context dictionary. May update technique via redirect.
func _setup_technique_context(
	user: BattleDigimonState, technique: TechniqueData,
	action: BattleAction, econ: Dictionary,
) -> Dictionary:
	# Fire ON_BEFORE_TECHNIQUE abilities and gear
	_fire_ability_trigger(Registry.AbilityTrigger.ON_BEFORE_TECHNIQUE, {
		"subject": user, "technique": technique,
	})
	_fire_gear_trigger(Registry.AbilityTrigger.ON_BEFORE_TECHNIQUE, {
		"subject": user, "technique": technique,
	})

	# Pre-scan for useRandomTechnique redirect
	for b: Dictionary in technique.bricks:
		if b.get("brick", "") == "useRandomTechnique":
			var redirect_ctx: Dictionary = {}
			BrickExecutor.execute_brick(
				b, user, user, technique, _battle, redirect_ctx,
			)
			if redirect_ctx.has("redirect_technique"):
				var new_key: StringName = \
					redirect_ctx["redirect_technique"] as StringName
				var new_tech: TechniqueData = \
					Atlas.techniques.get(new_key) as TechniqueData
				if new_tech != null:
					battle_message.emit(
						"%s used %s!" % [
							_get_digimon_name(user),
							new_tech.display_name,
						],
					)
					technique = new_tech
					action.technique_key = new_key
			break

	# Resolve targets
	var targets: Array[BattleDigimonState] = _resolve_targets(
		user, technique.targeting, action.target_side, action.target_slot,
	)

	# Pre-scan damageModifier flags for accuracy/protection overrides
	var technique_flags: Dictionary = BrickExecutor.get_technique_flags(
		user, targets[0] if targets.size() > 0 else null,
		technique, _battle,
	)
	var ignore_evasion: bool = technique_flags.get(
		"ignore_evasion", false,
	)
	var bypass_protection: bool = technique_flags.get(
		"bypass_protection", false,
	)

	# Pre-scan conditional bonuses for accuracy overrides
	var cond_bonuses: Dictionary = \
		BrickExecutor.evaluate_conditional_bonuses(
			user, targets[0] if targets.size() > 0 else null,
			technique, _battle,
		)
	var bonus_accuracy: int = int(cond_bonuses.get("bonus_accuracy", 0))
	var always_hits: bool = cond_bonuses.get("always_hits", false)

	# Determine if technique is multi-target (for "wide" protection)
	var is_multi_target: bool = technique.targeting in [
		Registry.Targeting.ALL_FOES, Registry.Targeting.ALL,
		Registry.Targeting.ALL_OTHER, Registry.Targeting.ALL_ALLIES,
		Registry.Targeting.ALL_OTHER_ALLIES,
	]

	# Determine multi-hit count from turn economy
	var turn_econ: Dictionary = econ.get("turn_econ", {})
	var multi_hit: Variant = turn_econ.get("multi_hit")
	var hit_count: int = 1
	if multi_hit is Dictionary:
		var mh: Dictionary = multi_hit as Dictionary
		var fixed: int = int(mh.get("fixed_hits", 0))
		if fixed > 0:
			hit_count = fixed
		else:
			hit_count = _battle.rng.randi_range(
				int(mh.get("min_hits", 2)),
				int(mh.get("max_hits", 5)),
			)

	return {
		"technique": technique,
		"targets": targets,
		"ignore_evasion": ignore_evasion,
		"bypass_protection": bypass_protection,
		"bonus_accuracy": bonus_accuracy,
		"always_hits": always_hits,
		"is_multi_target": is_multi_target,
		"hit_count": hit_count,
	}


## Execute technique bricks against each target. Handles semi-invulnerability,
## accuracy, protection, multi-hit, and result signal emission.
func _execute_against_targets(
	user: BattleDigimonState, technique: TechniqueData,
	action: BattleAction, ctx: Dictionary,
) -> Array[Dictionary]:
	var targets: Array[BattleDigimonState] = []
	var raw_targets: Variant = ctx.get("targets", [])
	if raw_targets is Array:
		for t: Variant in (raw_targets as Array):
			if t is BattleDigimonState:
				targets.append(t as BattleDigimonState)
	var ignore_evasion: bool = ctx.get("ignore_evasion", false)
	var bypass_protection: bool = ctx.get("bypass_protection", false)
	var bonus_accuracy: int = int(ctx.get("bonus_accuracy", 0))
	var always_hits: bool = ctx.get("always_hits", false)
	var is_multi_target: bool = ctx.get("is_multi_target", false)
	var hit_count: int = int(ctx.get("hit_count", 1))

	# Execute against each target
	var all_results: Array[Dictionary] = []
	for target: BattleDigimonState in targets:
		if target.is_fainted:
			continue

		# Semi-invulnerability check: target in sky/underground dodges
		var target_semi_inv: StringName = target.volatiles.get(
			"semi_invulnerable", &"",
		) as StringName
		if target_semi_inv != &"":
			battle_message.emit(
				"%s avoided the attack!" % _get_digimon_name(target),
			)
			all_results.append(
				{"missed": true, "semi_invulnerable": true},
			)
			continue

		# Accuracy check (0 or alwaysHits = always hits)
		if technique.accuracy > 0 and not always_hits:
			var acc_base: int = technique.accuracy + bonus_accuracy
			var effective_accuracy: float = _calculate_accuracy(
				acc_base, user, target, ignore_evasion,
			)
			var hit_roll: float = _battle.rng.randf() * 100.0
			if hit_roll > effective_accuracy:
				battle_message.emit(
					"It missed %s!" % _get_digimon_name(target),
				)
				# Execute crash recoil bricks on miss
				_execute_crash_recoil(user, target, technique)
				all_results.append({"missed": true})
				continue

		# Protection check
		if not bypass_protection:
			var prot_result: Dictionary = _check_protection(
				target, user, technique, is_multi_target,
			)
			if prot_result.get("fully_blocked", false):
				battle_message.emit(
					"%s protected itself!" \
						% _get_digimon_name(target),
				)
				# Counter damage to attacker on blocked contact moves
				var counter_pct: float = float(
					prot_result.get("counter_damage", 0),
				)
				if counter_pct > 0.0 \
						and _is_contact_technique(technique):
					var counter_dmg: int = maxi(
						roundi(
							float(user.max_hp) * counter_pct,
						), 1,
					)
					_apply_damage_and_emit(
						user, counter_dmg, &"protection_counter",
					)
					battle_message.emit(
						"%s took damage from the protection!" \
							% _get_digimon_name(user),
					)
				all_results.append({"protected": true})
				continue

		# Fire ON_BEFORE_HIT abilities and gear for the target
		_fire_ability_trigger(
			Registry.AbilityTrigger.ON_BEFORE_HIT, {
				"subject": target, "attacker": user,
				"technique": technique,
			},
		)
		_fire_gear_trigger(
			Registry.AbilityTrigger.ON_BEFORE_HIT, {
				"subject": target, "attacker": user,
				"technique": technique,
			},
		)

		# Execute bricks (multi-hit wrapper)
		var brick_results: Array[Dictionary] = []
		var actual_hits: int = 0
		for _hit_idx: int in range(hit_count):
			if target.is_fainted:
				break
			var hit_results: Array[Dictionary] = \
				BrickExecutor.execute_bricks(
					technique.bricks, user, target,
					technique, _battle,
				)
			brick_results.append_array(hit_results)
			actual_hits += 1
		if hit_count > 1:
			battle_message.emit("Hit %d time(s)!" % actual_hits)

		# Emit signals for results
		var dealt_damage: bool = false
		for brick_result: Dictionary in brick_results:
			if brick_result.get("damage", 0) > 0:
				var dmg: int = int(brick_result["damage"])
				var eff: StringName = brick_result.get(
					"effectiveness", &"neutral",
				) as StringName
				damage_dealt.emit(
					target.side_index, target.slot_index, dmg, eff,
				)
				dealt_damage = true

				# Track participation
				if user.source_state != null \
						and target.source_state != null:
					var foe_key: StringName = target.source_state.key
					if foe_key not in user.participated_against:
						user.participated_against.append(foe_key)

				if brick_result.get("was_critical", false):
					battle_message.emit("A critical hit!")

				match eff:
					&"super_effective":
						battle_message.emit(
							"It's super effective!",
						)
					&"not_very_effective":
						battle_message.emit(
							"It's not very effective...",
						)
					&"immune":
						battle_message.emit("It had no effect.")

			if brick_result.get("applied", false):
				var status_key: StringName = brick_result.get(
					"status", &"",
				) as StringName
				if status_key != &"":
					status_applied.emit(
						target.side_index, target.slot_index,
						status_key,
					)
					battle_message.emit(
						"%s was afflicted with %s!" % [
							_get_digimon_name(target),
							str(status_key),
						],
					)
					# Fire ON_STATUS_APPLIED for the target
					_fire_ability_trigger(
						Registry.AbilityTrigger.ON_STATUS_APPLIED,
						{
							"subject": target,
							"status_key": status_key,
						},
					)
					# Fire ON_STATUS_INFLICTED for the user
					if _battle.are_foes(
						user.side_index, target.side_index,
					):
						_fire_ability_trigger(
							Registry.AbilityTrigger \
								.ON_STATUS_INFLICTED, {
								"subject": user,
								"target": target,
								"status_key": status_key,
							},
						)
						_fire_gear_trigger(
							Registry.AbilityTrigger \
								.ON_STATUS_INFLICTED, {
								"subject": user,
								"target": target,
								"status_key": status_key,
							},
						)

			# Stat modifier results from technique bricks
			var tech_stat_changes: Variant = brick_result.get(
				"stat_changes",
			)
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
					var sc_actual: int = int(
						change.get("actual", 0),
					)
					stat_changed.emit(
						sc_target.side_index,
						sc_target.slot_index,
						sc_key, sc_actual,
					)
					_emit_stat_change_message(
						_get_digimon_name(sc_target), sc_key,
						int(change.get("stages", 0)), sc_actual,
					)
					# Fire ON_STAT_CHANGE
					if sc_actual != 0:
						_fire_ability_trigger(
							Registry.AbilityTrigger \
								.ON_STAT_CHANGE, {
								"subject": sc_target,
								"stat_key": sc_key,
								"stages": sc_actual,
							},
						)
						_fire_gear_trigger(
							Registry.AbilityTrigger \
								.ON_STAT_CHANGE, {
								"subject": sc_target,
								"stat_key": sc_key,
								"stages": sc_actual,
							},
						)

			# Protection activation
			if brick_result.get("protected", false):
				battle_message.emit(
					"%s braced itself!" \
						% _get_digimon_name(user),
				)
			if brick_result.get("protection_failed", false):
				battle_message.emit(
					"%s couldn't protect itself!" \
						% _get_digimon_name(user),
				)

			# Field effect results
			_emit_field_effect_signals(brick_result)

			# Recoil results (damage already applied by BrickExecutor)
			if brick_result.get("recoil", 0) > 0:
				var recoil_dmg: int = int(brick_result["recoil"])
				damage_dealt.emit(
					user.side_index, user.slot_index,
					recoil_dmg, &"recoil",
				)
				battle_message.emit(
					"%s took %d recoil damage!" % [
						_get_digimon_name(user), recoil_dmg,
					],
				)
				_check_faint_or_threshold(user, null)

			# Drain healing results
			if brick_result.get("drain_target_side", -1) >= 0:
				var drain_heal: int = int(
					brick_result.get("healing", 0),
				)
				if drain_heal > 0:
					hp_restored.emit(
						user.side_index, user.slot_index,
						drain_heal,
					)

			# Conditional nested results (stat changes from applyBricks)
			var nested: Variant = brick_result.get("nested_results")
			if nested is Array:
				for nested_r: Variant in (nested as Array):
					if not (nested_r is Dictionary):
						continue
					var nr: Dictionary = nested_r as Dictionary
					var nsc: Variant = nr.get("stat_changes")
					if nsc is Array:
						for change: Dictionary in (nsc as Array):
							var sc_target: BattleDigimonState = \
								change.get(
									"target",
								) as BattleDigimonState
							if sc_target == null:
								sc_target = target
							var sc_key: StringName = change.get(
								"stat_key", &"",
							) as StringName
							var sc_actual: int = int(
								change.get("actual", 0),
							)
							stat_changed.emit(
								sc_target.side_index,
								sc_target.slot_index,
								sc_key, sc_actual,
							)
							_emit_stat_change_message(
								_get_digimon_name(
									sc_target,
								),
								sc_key,
								int(
									change.get(
										"stages", 0,
									),
								),
								sc_actual,
							)

			# Transform / copy / ability / turnOrder messages
			if brick_result.get("transformed", false):
				var appearance: StringName = user.volatiles.get(
					"transform_appearance_key", &"",
				) as StringName
				if appearance != &"":
					battle_message.emit(
						"%s transformed into %s!" % [
							_get_digimon_name(user),
							str(appearance),
						],
					)
				else:
					battle_message.emit(
						"%s transformed!" \
							% _get_digimon_name(user),
					)
			if brick_result.get("technique_copied", "") != "":
				var copied_key: StringName = StringName(
					brick_result["technique_copied"],
				)
				var copied_tech: TechniqueData = \
					Atlas.techniques.get(
						copied_key,
					) as TechniqueData
				var copy_name: String = str(copied_key)
				if copied_tech != null:
					copy_name = copied_tech.display_name
				battle_message.emit(
					"%s copied %s!" % [
						_get_digimon_name(user), copy_name,
					],
				)
			if brick_result.has("ability_action"):
				var ab_action: String = brick_result.get(
					"ability_action", "",
				)
				match ab_action:
					"copy":
						battle_message.emit(
							"%s copied the foe's ability!" \
								% _get_digimon_name(user),
						)
					"swap":
						battle_message.emit(
							"%s swapped abilities!" \
								% _get_digimon_name(user),
						)
					"suppress", "nullify":
						battle_message.emit(
							"%s's ability was suppressed!" \
								% _get_digimon_name(target),
						)
					"replace":
						battle_message.emit(
							"%s's ability was changed!" \
								% _get_digimon_name(target),
						)
					"give":
						battle_message.emit(
							"%s gave its ability!" \
								% _get_digimon_name(user),
						)
			if brick_result.has("turn_order_action"):
				var to_action: String = brick_result.get(
					"turn_order_action", "",
				)
				match to_action:
					"moveNext":
						battle_message.emit(
							"%s was urged to move next!" \
								% _get_digimon_name(target),
						)
					"moveLast":
						battle_message.emit(
							"%s was forced to move last!" \
								% _get_digimon_name(target),
						)
					"repeat":
						battle_message.emit(
							"%s will repeat its move!" \
								% _get_digimon_name(target),
						)

		all_results.append_array(brick_results)

		# Fire ON_AFTER_HIT abilities and gear for the target
		_fire_ability_trigger(Registry.AbilityTrigger.ON_AFTER_HIT, {
			"subject": target, "attacker": user,
			"technique": technique,
		})
		_fire_gear_trigger(Registry.AbilityTrigger.ON_AFTER_HIT, {
			"subject": target, "attacker": user,
			"technique": technique,
		})

		# Fire damage-related ability and gear triggers
		if dealt_damage:
			_fire_ability_trigger(
				Registry.AbilityTrigger.ON_DEAL_DAMAGE, {
					"subject": user, "target": target,
					"technique": technique,
				},
			)
			_fire_gear_trigger(
				Registry.AbilityTrigger.ON_DEAL_DAMAGE, {
					"subject": user, "target": target,
					"technique": technique,
				},
			)
			_fire_ability_trigger(
				Registry.AbilityTrigger.ON_TAKE_DAMAGE, {
					"subject": target, "attacker": user,
					"technique": technique,
				},
			)
			_fire_gear_trigger(
				Registry.AbilityTrigger.ON_TAKE_DAMAGE, {
					"subject": target, "attacker": user,
					"technique": technique,
				},
			)
		# Faint check first, then HP threshold (berry) if survived
		_check_faint_or_threshold(target, user)

	return all_results


## Post-execution technique finalisation: ON_AFTER_TECHNIQUE triggers, volatile
## updates, recharge, multi-turn lock, delayed effects, position control.
func _finalise_technique(
	user: BattleDigimonState, technique: TechniqueData,
	action: BattleAction, econ: Dictionary,
	all_results: Array[Dictionary],
) -> void:
	# Fire ON_AFTER_TECHNIQUE abilities and gear
	_fire_ability_trigger(Registry.AbilityTrigger.ON_AFTER_TECHNIQUE, {
		"subject": user, "technique": technique,
	})
	_fire_gear_trigger(Registry.AbilityTrigger.ON_AFTER_TECHNIQUE, {
		"subject": user, "technique": technique,
	})

	# Update volatiles
	user.volatiles["last_technique_key"] = action.technique_key
	_battle.last_technique_used_key = action.technique_key

	var turn_econ: Dictionary = econ.get("turn_econ", {})
	var multi_turn: Variant = econ.get("multi_turn")
	var semi_inv_key: String = econ.get("semi_inv_key", "")
	var skip_init: bool = econ.get("skip_init", false)

	# Post-execution turn economy effects
	if not user.is_fainted:
		# Recharge: user must skip next turn
		if turn_econ.get("recharge", false):
			user.volatiles["recharging"] = true

		# Multi-turn lock (Outrage pattern — no semi-invulnerable)
		if multi_turn is Dictionary and semi_inv_key == "" \
				and not skip_init:
			var mt: Dictionary = multi_turn as Dictionary
			var already_locked: Variant = user.volatiles.get(
				"multi_turn_lock",
			)
			var not_locked: bool = not (already_locked is Dictionary) \
				or (already_locked as Dictionary).is_empty()
			if not_locked:
				var min_hits: int = int(mt.get("min_hits", 2))
				var max_hits: int = int(mt.get("max_hits", 2))
				var duration: int = _battle.rng.randi_range(
					min_hits, max_hits,
				)
				var locked_in: bool = mt.get("locked_in", false)
				if duration > 1:
					user.volatiles["multi_turn_lock"] = {
						"technique_key": action.technique_key,
						"remaining": duration - 1,
						"locked_in": locked_in,
					}

		# Delayed attack
		if turn_econ.has("delayed_attack"):
			var da: Dictionary = \
				turn_econ["delayed_attack"] as Dictionary
			_battle.pending_effects.append({
				"type": "delayed_attack",
				"resolve_turn": _battle.turn_number + int(
					da.get("delay", 2),
				),
				"user_side": action.user_side,
				"user_slot": action.user_slot,
				"technique_key": action.technique_key,
				"target_side": action.target_side,
				"target_slot": action.target_slot,
				"bypasses_protection": da.get(
					"bypass_protection", false,
				),
			})

		# Delayed healing
		if turn_econ.has("delayed_healing"):
			var dh: Dictionary = \
				turn_econ["delayed_healing"] as Dictionary
			var heal_side: int = action.user_side
			var heal_slot: int = action.user_slot
			if dh.get("target", "self") == "target":
				heal_side = action.target_side
				heal_slot = action.target_slot
			_battle.pending_effects.append({
				"type": "delayed_healing",
				"resolve_turn": _battle.turn_number + int(
					dh.get("delay", 1),
				),
				"target_side": heal_side,
				"target_slot": heal_slot,
				"percent": float(dh.get("percent", 50)),
			})

	# Process position control results
	_process_position_control(all_results, action)


## Process positionControl results from brick execution.
func _process_position_control(
	all_results: Array[Dictionary], action: BattleAction,
) -> void:
	for result: Dictionary in all_results:
		if result.get("force_switch", false):
			var target_side_idx: int = int(result["target_side"])
			var side: SideState = _battle.sides[target_side_idx]
			# Pick a random healthy reserve
			var valid_reserves: Array[int] = []
			for i: int in range(side.party.size()):
				if side.party[i].current_hp > 0:
					valid_reserves.append(i)
			if valid_reserves.is_empty():
				continue
			var reserve_idx: int = valid_reserves[
				_battle.rng.randi() % valid_reserves.size()
			]
			var switch_action: BattleAction = _make_switch_action(
					target_side_idx, int(result["target_slot"]),
					reserve_idx,
				)
			_resolve_switch(switch_action)

		elif result.get("switch_out", false):
			var switch_side: int = int(result["switch_side"])
			var side: SideState = _battle.sides[switch_side]
			# Pick the first healthy reserve
			var reserve_idx: int = -1
			for i: int in range(side.party.size()):
				if side.party[i].current_hp > 0:
					reserve_idx = i
					break
			if reserve_idx < 0:
				continue
			var switch_action: BattleAction = \
				_make_switch_action(
					switch_side, int(result["switch_slot"]),
					reserve_idx,
				)
			_resolve_switch(switch_action)

		elif result.get("switch_out_pass_stats", false):
			var switch_side: int = int(result["switch_side"])
			var side: SideState = _battle.sides[switch_side]
			var reserve_idx: int = -1
			for i: int in range(side.party.size()):
				if side.party[i].current_hp > 0:
					reserve_idx = i
					break
			if reserve_idx < 0:
				continue
			var saved_stages: Dictionary = result.get(
				"stat_stages", {},
			) as Dictionary
			var saved_modifiers: Dictionary = result.get(
				"volatile_stat_modifiers", {},
			) as Dictionary
			var switch_action: BattleAction = \
				_make_switch_action(
					switch_side, int(result["switch_slot"]),
					reserve_idx,
				)
			_resolve_switch(switch_action)
			# Copy stat stages and volatile modifiers to replacement
			var replacement: BattleDigimonState = _battle.get_digimon_at(
				switch_side, int(result["switch_slot"]),
			)
			if replacement != null:
				for key: StringName in saved_stages:
					replacement.stat_stages[key] = int(saved_stages[key])
				replacement.volatile_stat_modifiers = \
					saved_modifiers.duplicate(true)

		elif result.get("swap_positions", false):
			var side_idx: int = int(result["side"])
			var side: SideState = _battle.sides[side_idx]
			var slot_a: int = int(result["slot_a"])
			var slot_b: int = int(result["slot_b"])
			if slot_a < side.slots.size() and slot_b < side.slots.size():
				var temp: BattleDigimonState = side.slots[slot_a].digimon
				side.slots[slot_a].digimon = side.slots[slot_b].digimon
				side.slots[slot_b].digimon = temp
				# Update slot indices
				if side.slots[slot_a].digimon != null:
					side.slots[slot_a].digimon.slot_index = slot_a
				if side.slots[slot_b].digimon != null:
					side.slots[slot_b].digimon.slot_index = slot_b


## Process turn order manipulation from brick results.
func _process_turn_order(
	queue: Array[BattleAction],
	current_idx: int,
	results: Array[Dictionary],
) -> void:
	for result: Dictionary in results:
		if result.get("turn_order_action", "") == "moveNext":
			var target_side: int = int(result.get("target_side", -1))
			var target_slot: int = int(result.get("target_slot", -1))
			_reorder_action(
				queue, current_idx, target_side, target_slot, true,
			)
		elif result.get("turn_order_action", "") == "moveLast":
			var target_side: int = int(result.get("target_side", -1))
			var target_slot: int = int(result.get("target_slot", -1))
			_reorder_action(
				queue, current_idx, target_side, target_slot, false,
			)
		elif result.get("turn_order_action", "") == "repeat":
			var target_side: int = int(result.get("target_side", -1))
			var target_slot: int = int(result.get("target_slot", -1))
			var tech_key: StringName = StringName(
				result.get("technique_key", ""),
			)
			if tech_key != &"":
				var repeat_action := BattleAction.new()
				repeat_action.action_type = BattleAction.ActionType.TECHNIQUE
				repeat_action.user_side = target_side
				repeat_action.user_slot = target_slot
				repeat_action.technique_key = tech_key
				# Target the opponent by default
				if _battle.sides.size() > 1:
					repeat_action.target_side = 1 - target_side
					repeat_action.target_slot = 0
				queue.insert(current_idx + 1, repeat_action)


## Reorder a pending action in the queue. If move_next is true, move it right
## after current_idx. If false, move it to the end of the queue.
func _reorder_action(
	queue: Array[BattleAction],
	current_idx: int,
	target_side: int,
	target_slot: int,
	move_next: bool,
) -> void:
	# Find the target's pending action (after current position)
	var found_idx: int = -1
	for i: int in range(current_idx + 1, queue.size()):
		var a: BattleAction = queue[i]
		if a.user_side == target_side and a.user_slot == target_slot \
				and not a.is_cancelled:
			found_idx = i
			break

	if found_idx < 0:
		return

	var moved_action: BattleAction = queue[found_idx]
	queue.remove_at(found_idx)

	if move_next:
		queue.insert(current_idx + 1, moved_action)
	else:
		queue.append(moved_action)


## Create a switch BattleAction (avoids dependency on test factory).
func _make_switch_action(
	side: int, slot: int, party_index: int,
) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = BattleAction.ActionType.SWITCH
	action.user_side = side
	action.user_slot = slot
	action.switch_to_party_index = party_index
	return action


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

	# Fire ON_EXIT abilities and gear before resetting volatiles
	if outgoing != null and not outgoing.is_fainted:
		_fire_ability_trigger(
			Registry.AbilityTrigger.ON_EXIT, {"subject": outgoing},
		)
		_fire_gear_trigger(
			Registry.AbilityTrigger.ON_EXIT, {"subject": outgoing},
		)

	# Reset volatiles and escalation counters on outgoing
	if outgoing != null:
		outgoing.reset_status_counters()
		outgoing.reset_volatiles()
		# Move outgoing to reserve (as its source state)
		if outgoing.source_state != null:
			# Write back current HP/energy/consumable before moving to reserve
			outgoing.source_state.current_hp = outgoing.current_hp
			outgoing.source_state.current_energy = outgoing.current_energy
			outgoing.source_state.equipped_consumable_key = outgoing.equipped_consumable_key
			# Write back status conditions for persistence through switch
			outgoing.source_state.status_conditions.clear()
			for status: Dictionary in outgoing.status_conditions:
				outgoing.source_state.status_conditions.append(
					status.duplicate(),
				)
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
			# Fire ON_STAT_CHANGE for item stat modifications
			if sc_actual != 0:
				_fire_ability_trigger(
					Registry.AbilityTrigger.ON_STAT_CHANGE, {
						"subject": sc_target,
						"stat_key": sc_key,
						"stages": sc_actual,
					},
				)
				_fire_gear_trigger(
					Registry.AbilityTrigger.ON_STAT_CHANGE, {
						"subject": sc_target,
						"stat_key": sc_key,
						"stages": sc_actual,
					},
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


## Resolve trigger subjects from context. If context has "subject", returns
## just that Digimon; otherwise returns all active Digimon.
func _resolve_trigger_subjects(
	context: Dictionary,
) -> Array[BattleDigimonState]:
	if context.has("subject"):
		var subject: BattleDigimonState = \
			context["subject"] as BattleDigimonState
		if subject != null:
			return [subject] as Array[BattleDigimonState]
		return [] as Array[BattleDigimonState]
	return _battle.get_active_digimon()


## Execute bricks for an effect source (ability or gear) on a Digimon.
## Shared core loop used by both _fire_ability_trigger and _fire_gear_trigger.
func _execute_effect_bricks(
	digimon: BattleDigimonState,
	bricks: Array,
	effect_name: String,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	battle_message.emit(
		"%s's %s!" % [_get_digimon_name(digimon), effect_name],
	)
	for brick: Dictionary in bricks:
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
			results.append(result)
	return results


## Centralised ability trigger dispatcher. Checks all active Digimon (or just
## context["subject"]) for abilities matching the given trigger, respects stack
## limits and nullified status, then executes the ability's bricks.
func _fire_ability_trigger(
	trigger: Registry.AbilityTrigger, context: Dictionary = {},
) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []
	for digimon: BattleDigimonState in _resolve_trigger_subjects(context):
		if digimon.is_fainted or digimon.ability_key == &"":
			continue
		var ability: AbilityData = Atlas.abilities.get(
			digimon.ability_key,
		) as AbilityData
		if ability == null or ability.trigger != trigger:
			continue
		if not digimon.can_trigger_ability(ability.stack_limit):
			continue
		if not _check_trigger_condition(
			digimon, ability.trigger_condition, context,
		):
			continue
		digimon.record_ability_trigger(ability.stack_limit)
		all_results.append_array(
			_execute_effect_bricks(digimon, ability.bricks, ability.name),
		)
	return all_results


## Centralised gear trigger dispatcher. Checks both equipped_gear_key and
## equipped_consumable_key on each Digimon. Consumable gear is cleared after
## firing.
func _fire_gear_trigger(
	trigger: Registry.AbilityTrigger, context: Dictionary = {},
) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []
	for digimon: BattleDigimonState in _resolve_trigger_subjects(context):
		if digimon.is_fainted:
			continue
		if digimon.has_status(&"dazed"):
			continue
		if _battle.field.has_global_effect(&"gear_suppression"):
			continue

		var gear_keys: Array[Dictionary] = []
		if digimon.equipped_gear_key != &"":
			gear_keys.append({
				"key": digimon.equipped_gear_key, "is_consumable": false,
			})
		if digimon.equipped_consumable_key != &"":
			gear_keys.append({
				"key": digimon.equipped_consumable_key,
				"is_consumable": true,
			})

		for gear_entry: Dictionary in gear_keys:
			var gear_key: StringName = gear_entry["key"] as StringName
			var is_consumable: bool = gear_entry.get(
				"is_consumable", false,
			)
			var gear: Variant = Atlas.items.get(gear_key)
			if gear is not GearData:
				continue
			var gear_data: GearData = gear as GearData
			if gear_data.trigger != trigger:
				continue
			if not digimon.can_trigger_gear(
				gear_data.stack_limit, is_consumable,
			):
				continue
			if not _check_trigger_condition(
				digimon, gear_data.trigger_condition, context,
			):
				continue
			digimon.record_gear_trigger(
				gear_data.stack_limit, is_consumable,
			)
			all_results.append_array(
				_execute_effect_bricks(
					digimon, gear_data.bricks, gear_data.name,
				),
			)
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
			# Fire ON_STAT_CHANGE for ability/gear stat modifications
			if sc_actual != 0:
				_fire_ability_trigger(
					Registry.AbilityTrigger.ON_STAT_CHANGE, {
						"subject": sc_target,
						"stat_key": sc_key,
						"stages": sc_actual,
					},
				)
				_fire_gear_trigger(
					Registry.AbilityTrigger.ON_STAT_CHANGE, {
						"subject": sc_target,
						"stat_key": sc_key,
						"stages": sc_actual,
					},
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
		var eff: StringName = result.get(
			"effectiveness", &"neutral",
		) as StringName
		# Damage already applied by BrickExecutor; just emit the signal
		damage_dealt.emit(target.side_index, target.slot_index, dmg, eff)

	if result.get("healing", 0) > 0:
		var heal: int = int(result["healing"])
		# Healing already applied by BrickExecutor; just emit the signal
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


## Check pre-action state: recharging, multi-turn lock, charging.
## Returns {skip_action: bool, override_technique: StringName}.
func _check_pre_action_state(
	user: BattleDigimonState, action: BattleAction,
) -> Dictionary:
	var result: Dictionary = {"skip_action": false, "override_technique": &""}

	# 1. Recharging: must skip next turn (switching cancels recharge)
	if user.volatiles.get("recharging", false):
		if action.action_type == BattleAction.ActionType.SWITCH:
			user.volatiles["recharging"] = false
		else:
			user.volatiles["recharging"] = false
			battle_message.emit(
				"%s must recharge!" % _get_digimon_name(user),
			)
			result["skip_action"] = true
			return result

	# 2. Multi-turn lock: force locked technique, block switching
	var mtl: Variant = user.volatiles.get("multi_turn_lock")
	if mtl is Dictionary and not (mtl as Dictionary).is_empty():
		var lock: Dictionary = mtl as Dictionary
		if action.action_type == BattleAction.ActionType.SWITCH:
			battle_message.emit(
				"%s can't switch while locked in!" \
					% _get_digimon_name(user),
			)
			result["skip_action"] = true
			return result
		# Force the locked technique
		var locked_key: StringName = lock.get(
			"technique_key", &"",
		) as StringName
		if locked_key != &"":
			result["override_technique"] = locked_key
		# Decrement remaining
		var remaining: int = int(lock.get("remaining", 0)) - 1
		if remaining <= 0:
			# Clear lock and semi-invulnerable on final turn
			user.volatiles["multi_turn_lock"] = {}
			user.volatiles["semi_invulnerable"] = &""
			# Flag so _resolve_technique skips re-initialisation
			user.volatiles["skip_turn_economy_init"] = true
		else:
			lock["remaining"] = remaining
		return result

	# 3. Charging: must wait until charge completes
	var charge: Variant = user.volatiles.get("charging")
	if charge is Dictionary and not (charge as Dictionary).is_empty():
		var charge_data: Dictionary = charge as Dictionary
		if action.action_type == BattleAction.ActionType.SWITCH:
			battle_message.emit(
				"%s can't switch while charging!" \
					% _get_digimon_name(user),
			)
			result["skip_action"] = true
			return result
		# Check weather/terrain skip
		var skip_weather: String = charge_data.get(
			"skip_in_weather", "",
		)
		var skip_terrain: String = charge_data.get(
			"skip_in_terrain", "",
		)
		var weather_skip: bool = skip_weather != "" \
			and _battle.field.has_weather(StringName(skip_weather))
		var terrain_skip: bool = skip_terrain != "" \
			and _battle.field.has_terrain(StringName(skip_terrain))
		if weather_skip or terrain_skip:
			user.volatiles["charging"] = {}
			user.volatiles["semi_invulnerable"] = &""
			user.volatiles["skip_turn_economy_init"] = true
			# Proceed with the technique
			var tech_key: StringName = charge_data.get(
				"technique_key", &"",
			) as StringName
			if tech_key != &"":
				result["override_technique"] = tech_key
			return result

		var turns_remaining: int = int(
			charge_data.get("turns_remaining", 0),
		) - 1
		if turns_remaining <= 0:
			# Charge complete — fire the technique
			user.volatiles["charging"] = {}
			user.volatiles["semi_invulnerable"] = &""
			user.volatiles["skip_turn_economy_init"] = true
			var tech_key: StringName = charge_data.get(
				"technique_key", &"",
			) as StringName
			if tech_key != &"":
				result["override_technique"] = tech_key
			return result
		else:
			charge_data["turns_remaining"] = turns_remaining
			battle_message.emit(
				"%s is charging up..." % _get_digimon_name(user),
			)
			result["skip_action"] = true
			return result

	return result


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
	# 0. Resolve pending delayed effects (Future Sight, Wish)
	_resolve_pending_effects()

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

	# 3b. Stat protection duration ticks
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		_tick_stat_protections(digimon)

	# 3c. Transform / copy / ability duration ticks
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		_tick_transform_duration(digimon)
		_tick_copy_technique_duration(digimon)
		_tick_ability_manipulation_duration(digimon)

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


## Resolve pending delayed effects (delayed attacks, delayed healing).
func _resolve_pending_effects() -> void:
	var i: int = _battle.pending_effects.size() - 1
	while i >= 0:
		var effect: Dictionary = _battle.pending_effects[i]
		if int(effect.get("resolve_turn", 0)) <= _battle.turn_number:
			var effect_type: String = effect.get("type", "")
			match effect_type:
				"delayed_attack":
					var target: BattleDigimonState = _battle.get_digimon_at(
						int(effect.get("target_side", 0)),
						int(effect.get("target_slot", 0)),
					)
					if target != null and not target.is_fainted:
						var tech_key: StringName = effect.get(
							"technique_key", &"",
						) as StringName
						var tech: TechniqueData = Atlas.techniques.get(
							tech_key,
						) as TechniqueData
						if tech != null:
							battle_message.emit(
								"The delayed %s hit!" \
									% tech.display_name,
							)
							# Execute damage bricks only
							var user: BattleDigimonState = \
								_battle.get_digimon_at(
									int(effect.get("user_side", 0)),
									int(effect.get("user_slot", 0)),
								)
							if user == null or user.is_fainted:
								# Use a fallback — damage still lands
								user = target
							var results: Array[Dictionary] = \
								BrickExecutor.execute_bricks(
									tech.bricks, user, target,
									tech, _battle,
								)
							for r: Dictionary in results:
								if r.get("damage", 0) > 0:
									damage_dealt.emit(
										target.side_index,
										target.slot_index,
										int(r["damage"]),
										r.get(
											"effectiveness",
											&"neutral",
										) as StringName,
									)
							_check_faint_or_threshold(target, user)
				"delayed_healing":
					var target: BattleDigimonState = _battle.get_digimon_at(
						int(effect.get("target_side", 0)),
						int(effect.get("target_slot", 0)),
					)
					if target != null and not target.is_fainted:
						var percent: float = float(
							effect.get("percent", 50),
						)
						var amount: int = maxi(
							floori(
								float(target.max_hp) * percent / 100.0,
							), 1,
						)
						_apply_healing_and_emit(
							target, amount, &"delayed_healing",
						)
						battle_message.emit(
							"%s's wish came true!" \
								% _get_digimon_name(target),
						)
			_battle.pending_effects.remove_at(i)
		i -= 1


## Tick status conditions for a single Digimon using STATUS_TICK_CONFIG.
## Returns true if the Digimon fainted during status ticks.
func _tick_status_conditions(digimon: BattleDigimonState) -> bool:
	var to_remove: Array[StringName] = []
	var name: String = _get_digimon_name(digimon)

	for status: Dictionary in digimon.status_conditions:
		var key: StringName = status.get("key", &"") as StringName
		var config: Variant = Registry.STATUS_TICK_CONFIG.get(key)
		if config == null or not (config is Dictionary):
			# Non-tick status (paralysed, confused, etc.) — skip
			pass
		else:
			var cfg: Dictionary = config as Dictionary

			if cfg.has("countdown"):
				# Perishing: decrement countdown, KO at zero
				var countdown: int = int(
					status.get("countdown", 3),
				) - 1
				status["countdown"] = countdown
				battle_message.emit(
					"%s's perish count fell to %d!" % [
						name, countdown,
					],
				)
				if countdown <= 0:
					battle_message.emit(
						"%s was taken by the perish count!" \
							% name,
					)
					var perish_result: Dictionary = \
						_apply_damage_and_emit(
							digimon, digimon.current_hp,
							&"perishing",
						)
					if perish_result["fainted"]:
						return true

			elif cfg.has("heal_fraction"):
				# Regenerating: heal a fraction of max HP
				var frac: float = float(cfg["heal_fraction"])
				var heal: int = maxi(
					floori(float(digimon.max_hp) * frac), 1,
				)
				battle_message.emit(
					"%s regenerated some HP." % name,
				)
				_apply_healing_and_emit(
					digimon, heal, &"regenerating",
				)

			elif cfg.get("escalating", false):
				# Escalating DoT (badly_burned / badly_poisoned)
				var turn_idx: int = int(
					status.get("escalation_turn", 0),
				)
				var fractions: Array[float] = \
					Registry.ESCALATION_FRACTIONS
				var frac: float = fractions[
					mini(turn_idx, fractions.size() - 1)
				]
				var dot: int = maxi(
					floori(float(digimon.max_hp) * frac), 1,
				)
				var label: String = cfg.get("message", "")
				battle_message.emit(
					"%s is hurt by severe %s!" % [name, label],
				)
				var dot_result: Dictionary = \
					_apply_damage_and_emit(
						digimon, dot, StringName(label),
					)
				status["escalation_turn"] = turn_idx + 1
				if dot_result["fainted"]:
					return true

			elif cfg.has("damage_fraction"):
				# Flat-fraction DoT (burned, frostbitten, poisoned,
				# seeded)
				var frac: float = float(cfg["damage_fraction"])
				var dot: int = maxi(
					floori(float(digimon.max_hp) * frac), 1,
				)
				var label: String = cfg.get("message", str(key))
				battle_message.emit(
					"%s is hurt by %s!" % [name, label],
				)
				var dot_result: Dictionary = \
					_apply_damage_and_emit(
						digimon, dot, StringName(label),
					)
				# Drain: heal the seeder
				if cfg.get("drain", false):
					var seeder_side: int = int(
						status.get("seeder_side", -1),
					)
					var seeder_slot: int = int(
						status.get("seeder_slot", -1),
					)
					if seeder_side >= 0 and seeder_slot >= 0:
						var seeder: BattleDigimonState = \
							_battle.get_digimon_at(
								seeder_side, seeder_slot,
							)
						if seeder != null \
								and not seeder.is_fainted:
							_apply_healing_and_emit(
								seeder, dot, &"seeded",
							)
				if dot_result["fainted"]:
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


## Tick stat protection durations and remove expired entries.
func _tick_stat_protections(digimon: BattleDigimonState) -> void:
	var protections: Variant = digimon.volatiles.get("stat_protections")
	if protections == null or not (protections is Array):
		return
	var arr: Array = protections as Array
	var i: int = arr.size() - 1
	while i >= 0:
		var entry: Dictionary = arr[i]
		var remaining: int = int(entry.get("remaining_turns", -1))
		if remaining == -1:
			i -= 1
			continue  # No expiry (while on field)
		remaining -= 1
		if remaining <= 0:
			arr.remove_at(i)
		else:
			entry["remaining_turns"] = remaining
		i -= 1


## Tick transform duration. When expired, restore from backup.
func _tick_transform_duration(digimon: BattleDigimonState) -> void:
	var duration: int = int(digimon.volatiles.get("transform_duration", -1))
	if duration == -1:
		return  # Until switch — no tick
	var backup: Variant = digimon.volatiles.get("transform_backup", {})
	if not (backup is Dictionary) or (backup as Dictionary).is_empty():
		return  # Not actually transformed
	duration -= 1
	if duration <= 0:
		digimon.restore_transform()
		battle_message.emit(
			"%s reverted to its original form!" \
				% _get_digimon_name(digimon),
		)
	else:
		digimon.volatiles["transform_duration"] = duration


## Tick copied technique durations. When expired, restore original key.
func _tick_copy_technique_duration(digimon: BattleDigimonState) -> void:
	var slots: Variant = digimon.volatiles.get("copied_technique_slots", [])
	if not (slots is Array):
		return
	var arr: Array = slots as Array
	var i: int = arr.size() - 1
	while i >= 0:
		var entry: Variant = arr[i]
		if not (entry is Dictionary):
			i -= 1
			continue
		var e: Dictionary = entry as Dictionary
		var dur: int = int(e.get("duration", -1))
		if dur == -1:
			i -= 1
			continue  # Until switch — no tick
		dur -= 1
		if dur <= 0:
			var slot: int = int(e.get("slot", -1))
			var original: StringName = e.get(
				"original_key", &"",
			) as StringName
			if slot >= 0 \
					and slot < digimon.equipped_technique_keys.size():
				digimon.equipped_technique_keys[slot] = original
			arr.remove_at(i)
		else:
			e["duration"] = dur
		i -= 1


## Tick ability manipulation duration. When expired, restore original.
func _tick_ability_manipulation_duration(
	digimon: BattleDigimonState,
) -> void:
	var duration: int = int(
		digimon.volatiles.get("ability_manipulation_duration", -1),
	)
	if duration == -1:
		return  # Until switch — no tick
	var backup: StringName = digimon.volatiles.get(
		"ability_backup", &"",
	) as StringName
	if backup == &"":
		return  # Not actually manipulated
	duration -= 1
	if duration <= 0:
		digimon.restore_ability()
		battle_message.emit(
			"%s's ability was restored!" % _get_digimon_name(digimon),
		)
	else:
		digimon.volatiles["ability_manipulation_duration"] = duration


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


## Execute crash-type recoil bricks when a technique misses.
## Scans technique bricks for recoil with type "crash" and applies the damage.
func _execute_crash_recoil(
	user: BattleDigimonState,
	_target: BattleDigimonState,
	technique: TechniqueData,
) -> void:
	for brick: Dictionary in technique.bricks:
		if brick.get("brick") != "recoil":
			continue
		if brick.get("type") != "crash":
			continue
		var percent: float = float(brick.get("percent", 50))
		var amount: int = maxi(roundi(float(user.max_hp) * percent / 100.0), 1)
		_apply_damage_and_emit(user, amount, &"crash_recoil")
		battle_message.emit(
			"%s kept going and crashed!" % _get_digimon_name(user),
		)
		return  # Only one crash recoil brick per technique


## Check if a target's protection blocks the incoming technique.
## Returns {fully_blocked: bool, counter_damage: float}.
func _check_protection(
	target: BattleDigimonState,
	_attacker: BattleDigimonState,
	technique: TechniqueData,
	is_multi_target: bool,
) -> Dictionary:
	var protection: Variant = target.volatiles.get("protection")
	if protection == null or not (protection is Dictionary):
		return {"fully_blocked": false}

	var prot_type: String = (protection as Dictionary).get("type", "all")
	var blocked: bool = false

	match prot_type:
		"all":
			blocked = true
		"wide":
			blocked = is_multi_target
		"priority":
			blocked = technique.priority > Registry.Priority.NORMAL

	if not blocked:
		return {"fully_blocked": false}

	return {
		"fully_blocked": true,
		"counter_damage": float(
			(protection as Dictionary).get("counter_damage", 0),
		),
		"reflect_status": (protection as Dictionary).get(
			"reflect_status", false,
		),
	}


## Check if a technique makes physical contact (has CONTACT flag).
func _is_contact_technique(technique: TechniqueData) -> bool:
	return Registry.TechniqueFlag.CONTACT in technique.flags


## Unified damage application: apply damage, emit signal, check faint/threshold.
## Returns {actual: int, fainted: bool}.
func _apply_damage_and_emit(
	target: BattleDigimonState,
	amount: int,
	source_label: StringName,
	attacker: BattleDigimonState = null,
	fire_triggers: bool = false,
	technique: TechniqueData = null,
) -> Dictionary:
	var actual: int = target.apply_damage(amount)
	damage_dealt.emit(target.side_index, target.slot_index, actual, source_label)
	if fire_triggers and actual > 0:
		_fire_ability_trigger(Registry.AbilityTrigger.ON_TAKE_DAMAGE, {
			"subject": target, "attacker": attacker, "technique": technique,
		})
		_fire_gear_trigger(Registry.AbilityTrigger.ON_TAKE_DAMAGE, {
			"subject": target, "attacker": attacker, "technique": technique,
		})
		if attacker != null:
			_fire_ability_trigger(Registry.AbilityTrigger.ON_DEAL_DAMAGE, {
				"subject": attacker, "target": target, "technique": technique,
			})
			_fire_gear_trigger(Registry.AbilityTrigger.ON_DEAL_DAMAGE, {
				"subject": attacker, "target": target, "technique": technique,
			})
	var fainted: bool = _check_faint_or_threshold(target, attacker)
	return {"actual": actual, "fainted": fainted}


## Unified healing application: restore HP, emit signal.
## Returns the actual amount healed.
func _apply_healing_and_emit(
	target: BattleDigimonState,
	amount: int,
	source_label: StringName,
) -> int:
	var actual: int = target.restore_hp(amount)
	if actual > 0:
		hp_restored.emit(target.side_index, target.slot_index, actual)
	return actual


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
	base_accuracy: int,
	user: BattleDigimonState,
	target: BattleDigimonState,
	ignore_evasion: bool = false,
) -> float:
	var acc_stage: int = user.stat_stages.get(&"accuracy", 0)
	var acc_mult: float = Registry.STAT_STAGE_MULTIPLIERS.get(acc_stage, 1.0)
	var eva_mult: float = 1.0
	if not ignore_evasion:
		var eva_stage: int = target.stat_stages.get(&"evasion", 0)
		eva_mult = Registry.STAT_STAGE_MULTIPLIERS.get(eva_stage, 1.0)
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
	var config: Dictionary = Registry.WEATHER_CONFIG.get(weather_key, {})
	if not config.get("tick_damage", false):
		return

	var percent: float = _balance.weather_tick_damage_percent if _balance \
		else 0.0625
	var immune_elements: Array = config.get("immune_elements", [])

	for digimon: BattleDigimonState in _battle.get_active_digimon():
		if digimon.is_fainted:
			continue

		# Check element trait immunity
		var is_immune: bool = false
		if digimon.data != null:
			for elem: StringName in digimon.get_effective_element_traits():
				if elem in immune_elements:
					is_immune = true
					break
		if is_immune:
			continue

		var damage: int = maxi(
			floori(float(digimon.max_hp) * percent), 1,
		)
		var weather_result: Dictionary = _apply_damage_and_emit(
			digimon, damage, &"weather",
		)
		battle_message.emit(
			"%s is buffeted by the %s! (%d damage)" % [
				_get_digimon_name(digimon), str(weather_key),
				int(weather_result["actual"]),
			],
		)


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
			has_aerial = &"aerial" in digimon.get_effective_element_traits()
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
				resistance = digimon.get_effective_resistance(element)

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
			var hazard_result: Dictionary = _apply_damage_and_emit(
				digimon, damage, &"hazard",
			)
			battle_message.emit(
				"%s was hurt by %s! (%d damage)" % [
					_get_digimon_name(digimon), str(key),
					int(hazard_result["actual"]),
				],
			)
			hazard_applied.emit(digimon.side_index, key)
			if hazard_result["fainted"]:
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
