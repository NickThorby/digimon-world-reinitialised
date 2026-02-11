class_name ActionSorter
extends RefCounted
## Sorts battle actions by priority, speed, and random tiebreaker.


## Sort actions for a turn. Modifies actions in-place and returns them sorted.
static func sort_actions(
	actions: Array[BattleAction],
	battle: BattleState,
) -> Array[BattleAction]:
	# Calculate speeds and tiebreakers
	for action: BattleAction in actions:
		calculate_action_speed(action, battle)

	# Sort: higher priority first, then higher speed, then random tiebreaker
	actions.sort_custom(_compare_actions)
	return actions


## Calculate and store effective speed and tiebreaker on an action.
static func calculate_action_speed(action: BattleAction, battle: BattleState) -> void:
	# Assign priority based on action type
	match action.action_type:
		BattleAction.ActionType.SWITCH, \
		BattleAction.ActionType.RUN, \
		BattleAction.ActionType.ITEM:
			action.priority = Registry.Priority.MAXIMUM
		BattleAction.ActionType.REST:
			action.priority = Registry.Priority.NORMAL
		BattleAction.ActionType.TECHNIQUE:
			# Get technique priority from data
			var tech: TechniqueData = Atlas.techniques.get(
				action.technique_key,
			) as TechniqueData
			if tech:
				action.priority = tech.priority
				# Check for priorityOverride brick
				var user: BattleDigimonState = battle.get_digimon_at(
					action.user_side, action.user_slot,
				)
				if user != null:
					var target: BattleDigimonState = battle.get_digimon_at(
						action.target_side, action.target_slot,
					)
					var override_priority: int = \
						BrickExecutor.evaluate_priority_override(
							user, target, tech, battle,
						)
					if override_priority >= 0:
						action.priority = override_priority
			else:
				action.priority = Registry.Priority.NORMAL

	# Calculate effective speed from the acting Digimon
	var digimon: BattleDigimonState = battle.get_digimon_at(action.user_side, action.user_slot)
	if digimon:
		action.effective_speed = digimon.get_effective_speed(
			action.priority as Registry.Priority
		)

		# Speed boost side effect
		if digimon.side_index < battle.sides.size() \
				and battle.sides[digimon.side_index].has_side_effect(
					&"speed_boost",
				):
			var side_config: Dictionary = Registry.SIDE_EFFECT_CONFIG.get(
				&"speed_boost", {},
			)
			var mult_key: String = side_config.get(
				"speed_multiplier_key", "",
			)
			if mult_key != "":
				var balance: GameBalance = load(
					"res://data/config/game_balance.tres",
				) as GameBalance
				var mult: float = balance.get(mult_key) if balance else 1.5
				action.effective_speed *= mult

		# Speed inversion global effect
		if battle.field.has_global_effect(&"speed_inversion"):
			action.effective_speed = -action.effective_speed
	else:
		action.effective_speed = 0.0

	# Random tiebreaker
	action.speed_tiebreaker = battle.rng.randf()


## Comparison function for sorting. Returns true if a should go before b.
static func _compare_actions(a: BattleAction, b: BattleAction) -> bool:
	# Higher priority value goes first
	if a.priority != b.priority:
		return a.priority > b.priority

	# For MAXIMUM/INSTANT/NEGATIVE/MINIMUM tiers, use speed directly
	# For speed-multiplied tiers, effective_speed already incorporates the multiplier
	if not is_equal_approx(a.effective_speed, b.effective_speed):
		return a.effective_speed > b.effective_speed

	# Tiebreaker
	return a.speed_tiebreaker > b.speed_tiebreaker
