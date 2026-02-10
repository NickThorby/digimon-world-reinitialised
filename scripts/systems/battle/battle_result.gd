class_name BattleResult
extends RefCounted
## Outcome of a completed battle.


enum Outcome {
	WIN,
	LOSS,
	DRAW,
	FLED,
}

## How the battle ended.
var outcome: Outcome = Outcome.WIN

## Team index of the winning team (-1 for draw/fled).
var winning_team: int = -1

## Total turns the battle lasted.
var turn_count: int = 0

## XP awards per Digimon. Each: { "digimon_state": DigimonState, "xp": int,
##   "old_level": int, "old_experience": int, "old_stats": Dictionary,
##   "levels_gained": int, "new_techniques": Array[StringName],
##   "participated": bool }
var xp_awards: Array[Dictionary] = []

## All party DigimonState on the winning side, for post-battle display.
var party_digimon: Array[DigimonState] = []
