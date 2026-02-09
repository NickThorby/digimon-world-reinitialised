class_name DamageResult
extends RefCounted
## Result of a damage calculation.


## Damage before clamping to target HP.
var raw_damage: int = 0

## Damage actually dealt (after clamping).
var final_damage: int = 0

## Whether this was a critical hit.
var was_critical: bool = false

## Effectiveness description for UI.
var effectiveness: StringName = &"neutral"

## Individual multipliers applied.
var attribute_multiplier: float = 1.0
var element_multiplier: float = 1.0
var stab_applied: bool = false
var variance: float = 1.0
