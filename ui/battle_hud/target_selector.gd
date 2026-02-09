class_name TargetSelector
extends Control
## Non-visual coordinator for target selection.
## Exposes valid-target logic; the battle scene handles sprite-based UI.


signal target_chosen(side_index: int, slot_index: int)
signal back_pressed


## Return the list of valid targets for a given user, targeting mode, and battle.
func get_valid_targets(
	user: BattleDigimonState,
	targeting: Registry.Targeting,
	battle: BattleState,
) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []

	for side: SideState in battle.sides:
		for slot: SlotState in side.slots:
			if slot.digimon == null or slot.digimon.is_fainted:
				continue

			var is_valid: bool = false
			match targeting:
				Registry.Targeting.SINGLE_FOE:
					is_valid = battle.are_foes(user.side_index, side.side_index)
				Registry.Targeting.SINGLE_ALLY:
					is_valid = battle.are_allies(user.side_index, side.side_index) and \
						slot.digimon != user
				Registry.Targeting.SINGLE_OTHER:
					is_valid = slot.digimon != user
				Registry.Targeting.SINGLE_TARGET:
					is_valid = true

			if is_valid:
				targets.append({
					"side": side.side_index,
					"slot": slot.slot_index,
					"digimon": slot.digimon,
				})

	return targets


## Called by the battle scene when a sprite target is clicked.
func select_target(side_index: int, slot_index: int) -> void:
	target_chosen.emit(side_index, slot_index)
