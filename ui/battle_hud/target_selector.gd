class_name TargetSelector
extends PanelContainer
## Highlights valid targets and emits selection for single-target techniques.


signal target_chosen(side_index: int, slot_index: int)
signal back_pressed

@onready var _target_container: VBoxContainer = %TargetContainer
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## Populate with valid targets based on targeting type and battle state.
func populate(
	user: BattleDigimonState,
	targeting: Registry.Targeting,
	battle: BattleState,
) -> void:
	for child: Node in _target_container.get_children():
		child.queue_free()

	var valid_targets: Array[Dictionary] = _get_valid_targets(user, targeting, battle)

	for target_info: Dictionary in valid_targets:
		var digimon: BattleDigimonState = target_info["digimon"] as BattleDigimonState
		if digimon == null or digimon.data == null:
			continue

		var name: String = digimon.data.display_name
		var side_idx: int = int(target_info["side"])
		var slot_idx: int = int(target_info["slot"])
		var is_foe: bool = battle.are_foes(user.side_index, side_idx)

		var button := Button.new()
		button.text = "%s%s  Lv. %d  HP: %d/%d" % [
			"[Foe] " if is_foe else "[Ally] ",
			name,
			digimon.source_state.level if digimon.source_state else 1,
			digimon.current_hp,
			digimon.max_hp,
		]

		var s: int = side_idx
		var sl: int = slot_idx
		button.pressed.connect(
			func() -> void: target_chosen.emit(s, sl)
		)
		_target_container.add_child(button)


func _get_valid_targets(
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
