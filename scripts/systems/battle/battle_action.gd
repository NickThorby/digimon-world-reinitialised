class_name BattleAction
extends RefCounted
## Represents a single action queued for execution in a battle turn.


enum ActionType {
	TECHNIQUE,
	SWITCH,
	REST,
	RUN,
	ITEM,
}

## What kind of action this is.
var action_type: ActionType = ActionType.TECHNIQUE

## Side and slot of the actor.
var user_side: int = 0
var user_slot: int = 0

## For TECHNIQUE actions.
var technique_key: StringName = &""
var target_side: int = -1
var target_slot: int = -1

## For SWITCH actions — index into the side's reserve party.
var switch_to_party_index: int = -1

## For ITEM actions.
var item_key: StringName = &""
var item_target_side: int = -1
var item_target_slot: int = -1

## Resolved priority tier (derived from technique or action type).
var priority: int = Registry.Priority.NORMAL

## Calculated effective speed for ordering within a priority tier.
var effective_speed: float = 0.0

## Random tiebreaker for speed ties (set at queue time).
var speed_tiebreaker: float = 0.0

## Whether this action was cancelled before resolution. Set when the actor cannot
## act (e.g., fainted before their turn) or by ability interactions (e.g., flinch,
## Fake Out). The engine skips cancelled actions in execute_turn().
var is_cancelled: bool = false
