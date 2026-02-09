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
signal hp_restored(side_index: int, slot_index: int, amount: int)
signal battle_message(text: String)
signal technique_animation_requested(
	user_side: int, user_slot: int, technique_class: Registry.TechniqueClass
)
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

	# Increment turns on field for all active Digimon
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		digimon.volatiles["turns_on_field"] = int(
			digimon.volatiles.get("turns_on_field", 0)
		) + 1

	# Sort actions
	var sorted: Array[BattleAction] = ActionSorter.sort_actions(actions, _battle)

	# Resolve each action
	for action: BattleAction in sorted:
		if _battle.is_battle_over:
			break
		if action.is_cancelled:
			continue

		# Verify actor is still alive
		var user: BattleDigimonState = _battle.get_digimon_at(action.user_side, action.user_slot)
		if user == null or user.is_fainted:
			continue

		var results: Array[Dictionary] = _resolve_action(action)
		action_resolved.emit(action, results)

		# Check for faints after each action
		_check_faints()

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
		action.user_side, action.user_slot, technique.technique_class
	)

	# Spend energy — handle overexertion
	var energy_cost: int = technique.energy_cost
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

		if user.is_fainted:
			digimon_fainted.emit(user.side_index, user.slot_index)
			return [{"overexertion_faint": true}]
	else:
		user.spend_energy(energy_cost)
		energy_spent.emit(user.side_index, user.slot_index, energy_cost)

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
			var hit_roll: float = _battle.rng.randf() * 100.0
			if hit_roll > float(technique.accuracy):
				battle_message.emit("It missed %s!" % _get_digimon_name(target))
				all_results.append({"missed": true})
				continue

		# Execute bricks
		var brick_results: Array[Dictionary] = BrickExecutor.execute_bricks(
			technique.bricks, user, target, technique, _battle,
		)

		# Emit signals for results
		for brick_result: Dictionary in brick_results:
			if brick_result.get("damage", 0) > 0:
				var dmg: int = int(brick_result["damage"])
				var eff: StringName = brick_result.get("effectiveness", &"neutral") as StringName
				damage_dealt.emit(target.side_index, target.slot_index, dmg, eff)

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
				var status_key: StringName = brick_result.get("status", &"") as StringName
				if status_key != &"":
					status_applied.emit(
						target.side_index, target.slot_index, status_key
					)
					battle_message.emit("%s was afflicted with %s!" % [
						_get_digimon_name(target), str(status_key),
					])

		all_results.append_array(brick_results)

		# Check target faint
		if target.check_faint():
			battle_message.emit("%s fainted!" % _get_digimon_name(target))
			digimon_fainted.emit(target.side_index, target.slot_index)

			# Track foe fainted counter
			if _battle.are_foes(user.side_index, target.side_index):
				user.counters["foes_fainted"] = int(user.counters.get("foes_fainted", 0)) + 1

	# Update volatiles
	user.volatiles["last_technique_key"] = action.technique_key

	return all_results


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
			# Write back current HP/energy before moving to reserve
			outgoing.source_state.current_hp = outgoing.current_hp
			outgoing.source_state.current_energy = outgoing.current_energy
			side.party.append(outgoing.source_state)

	# Take new Digimon from reserve
	var new_state: DigimonState = side.party[action.switch_to_party_index]
	side.party.remove_at(action.switch_to_party_index)

	# Create battle Digimon
	var new_battle_mon: BattleDigimonState = BattleFactory.create_battle_digimon(
		new_state, action.user_side, action.user_slot,
	)
	slot.digimon = new_battle_mon

	var name_out: String = _get_digimon_name(outgoing) if outgoing else "?"
	var name_in: String = _get_digimon_name(new_battle_mon)
	battle_message.emit("%s switched out for %s!" % [name_out, name_in])
	digimon_switched.emit(action.user_side, action.user_slot, new_battle_mon)

	return [{"switched": true}]


## Resolve a rest action (restore energy).
func _resolve_rest(action: BattleAction) -> Array[Dictionary]:
	var user: BattleDigimonState = _battle.get_digimon_at(action.user_side, action.user_slot)
	if user == null:
		return []

	var regen_pct: float = _balance.energy_regen_on_rest if _balance else 0.25
	var amount: int = maxi(floori(float(user.max_energy) * regen_pct), 1)
	user.restore_energy(amount)

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


## Resolve an item action (placeholder for future).
func _resolve_item(_action: BattleAction) -> Array[Dictionary]:
	battle_message.emit("Items are not yet implemented.")
	return [{"handled": false}]


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

	# Check confusion (use random technique instead)
	if user.has_status(&"confused"):
		battle_message.emit("%s is confused!" % _get_digimon_name(user))
		# 33% chance to hurt itself
		if _battle.rng.randf() < 0.33:
			var self_damage: int = maxi(user.get_effective_stat(&"attack") / 8, 1)
			user.apply_damage(self_damage)
			battle_message.emit("%s hurt itself in confusion!" % _get_digimon_name(user))
			damage_dealt.emit(user.side_index, user.slot_index, self_damage, &"confusion")
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
	# 1. Status condition ticks
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		_tick_status_conditions(digimon)
		if digimon.check_faint():
			battle_message.emit("%s fainted!" % _get_digimon_name(digimon))
			digimon_fainted.emit(digimon.side_index, digimon.slot_index)

	# 2. Field duration ticks
	var expired: Dictionary = _battle.field.tick_durations()
	if expired.get("weather", false):
		battle_message.emit("The weather returned to normal.")
		weather_changed.emit({})
	if expired.get("terrain", false):
		battle_message.emit("The terrain returned to normal.")
		terrain_changed.emit({})

	# 3. Side effect ticks
	for side: SideState in _battle.sides:
		side.tick_durations()

	# 4. Energy regeneration (5% per turn for all active Digimon)
	var regen_pct: float = _balance.energy_regen_per_turn if _balance else 0.05
	for digimon: BattleDigimonState in _battle.get_active_digimon():
		var amount: int = maxi(floori(float(digimon.max_energy) * regen_pct), 1)
		digimon.restore_energy(amount)

	# 5. Check end conditions
	_battle.check_end_conditions()


## Tick status conditions for a single Digimon.
func _tick_status_conditions(digimon: BattleDigimonState) -> void:
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
			"frostbitten":
				var dot: int = maxi(digimon.max_hp / 16, 1)
				digimon.apply_damage(dot)
				battle_message.emit(
					"%s is hurt by frostbite!" % _get_digimon_name(digimon)
				)
				damage_dealt.emit(digimon.side_index, digimon.slot_index, dot, &"frostbite")
			"poisoned":
				var dot: int = maxi(digimon.max_hp / 8, 1)
				digimon.apply_damage(dot)
				battle_message.emit(
					"%s is hurt by poison!" % _get_digimon_name(digimon)
				)
				damage_dealt.emit(digimon.side_index, digimon.slot_index, dot, &"poison")
			"seeded":
				var dot: int = maxi(digimon.max_hp / 8, 1)
				digimon.apply_damage(dot)
				battle_message.emit(
					"%s had its energy drained by the seed!" % _get_digimon_name(digimon)
				)
				damage_dealt.emit(digimon.side_index, digimon.slot_index, dot, &"seeded")
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


## Check all slots for faints.
func _check_faints() -> void:
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			if slot.digimon != null and slot.digimon.check_faint():
				# Faint already handled by individual action resolution
				pass


## Get display name for a BattleDigimonState.
func _get_digimon_name(digimon: BattleDigimonState) -> String:
	if digimon == null:
		return "???"
	if digimon.source_state != null and digimon.source_state.nickname != "":
		return digimon.source_state.nickname
	if digimon.data != null:
		return digimon.data.display_name
	return "???"
