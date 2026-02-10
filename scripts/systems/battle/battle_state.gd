class_name BattleState
extends RefCounted
## Root state for an active battle. Contains field, sides, and turn tracking.


## Configuration used to create this battle.
var config: BattleConfig = null

## Global field state (weather, terrain, effects).
var field: FieldState = FieldState.new()

## All sides in the battle.
var sides: Array[SideState] = []

## Current turn number (starts at 0, incremented at turn start).
var turn_number: int = 0

## Whether the battle has ended.
var is_battle_over: bool = false

## Battle result (populated when battle ends).
var result: BattleResult = null

## Pending delayed effects (delayed attacks, delayed healing).
## Each entry: {type, resolve_turn, user_side, user_slot, technique_key,
## target_side, target_slot, bypasses_protection, percent}
var pending_effects: Array[Dictionary] = []

## Seeded PRNG for deterministic randomness.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Get all active (non-fainted) BattleDigimonState on the field.
func get_active_digimon() -> Array[BattleDigimonState]:
	var active: Array[BattleDigimonState] = []
	for side: SideState in sides:
		for slot: SlotState in side.slots:
			if slot.digimon != null and not slot.digimon.is_fainted:
				active.append(slot.digimon)
	return active


## Check if two sides are foes (different teams).
func are_foes(side_a: int, side_b: int) -> bool:
	if config == null:
		return side_a != side_b
	var team_a: int = config.team_assignments[side_a] if side_a < config.team_assignments.size() else side_a
	var team_b: int = config.team_assignments[side_b] if side_b < config.team_assignments.size() else side_b
	return team_a != team_b


## Check if two sides are allies (same team).
func are_allies(side_a: int, side_b: int) -> bool:
	return not are_foes(side_a, side_b)


## Check end conditions. Returns true if the battle should end.
func check_end_conditions() -> bool:
	if is_battle_over:
		return true

	# Collect which teams still have Digimon
	var alive_teams: Dictionary = {}
	for side: SideState in sides:
		var team_idx: int = side.team_index
		if alive_teams.has(team_idx):
			continue
		if side.get_remaining_count() > 0:
			alive_teams[team_idx] = true

	# If only one team (or zero) remains, battle is over
	if alive_teams.size() <= 1:
		is_battle_over = true
		result = BattleResult.new()
		result.turn_count = turn_number

		if alive_teams.size() == 1:
			var winning_team: int = alive_teams.keys()[0]
			result.winning_team = winning_team
			# Determine outcome relative to team 0 (player)
			var player_team: int = config.team_assignments[0] if config else 0
			if winning_team == player_team:
				result.outcome = BattleResult.Outcome.WIN
			else:
				result.outcome = BattleResult.Outcome.LOSS
		else:
			result.outcome = BattleResult.Outcome.DRAW
			result.winning_team = -1

		return true

	return false


## Get the BattleDigimonState at a specific side and slot.
func get_digimon_at(side_idx: int, slot_idx: int) -> BattleDigimonState:
	if side_idx < 0 or side_idx >= sides.size():
		return null
	var side: SideState = sides[side_idx]
	if slot_idx < 0 or slot_idx >= side.slots.size():
		return null
	return side.slots[slot_idx].digimon
