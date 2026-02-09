class_name SlotState
extends RefCounted
## Represents a single active position on a side of the battlefield.


## Position index within the side (0-based).
var slot_index: int = 0

## Which side this slot belongs to.
var side_index: int = 0

## The Digimon occupying this slot (null if empty).
var digimon: BattleDigimonState = null


## Whether this slot has a non-fainted Digimon.
func is_active() -> bool:
	return digimon != null and not digimon.is_fainted


## Whether this slot has no Digimon.
func is_empty() -> bool:
	return digimon == null
