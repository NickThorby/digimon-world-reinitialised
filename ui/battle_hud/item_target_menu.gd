class_name ItemTargetMenu
extends PanelContainer
## Shows party members eligible for item use. Emits selection by roster index.


signal target_chosen(party_index: int)
signal back_pressed

@onready var _member_container: VBoxContainer = $VBox/ScrollContainer/MemberContainer
@onready var _back_button: Button = $VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## Populate with eligible party members for an item.
## roster: [{is_active, battle_digimon?, digimon_state?, name}]
## is_revive: if true, show only fainted members; if false, show only non-fainted.
func populate(roster: Array[Dictionary], is_revive: bool) -> void:
	for child: Node in _member_container.get_children():
		child.queue_free()

	for i: int in roster.size():
		var entry: Dictionary = roster[i]
		var digimon_name: String = entry.get("name", "???") as String
		var is_active: bool = entry.get("is_active", false) as bool
		var current_hp: int = 0
		var max_hp: int = 1

		if is_active:
			var battle_mon: BattleDigimonState = entry.get(
				"battle_digimon",
			) as BattleDigimonState
			if battle_mon != null:
				current_hp = battle_mon.current_hp
				max_hp = battle_mon.max_hp
		else:
			var state: DigimonState = entry.get(
				"digimon_state",
			) as DigimonState
			if state != null:
				current_hp = state.current_hp
				var data: DigimonData = Atlas.digimon.get(
					state.key,
				) as DigimonData
				if data != null:
					var stats: Dictionary = StatCalculator.calculate_all_stats(
						data, state,
					)
					max_hp = stats.get(&"hp", 100)

		var is_fainted: bool = current_hp <= 0

		# Filter by revive eligibility
		if is_revive and not is_fainted:
			continue
		if not is_revive and is_fainted:
			continue

		var button := Button.new()
		button.text = "%s  HP: %d/%d" % [digimon_name, current_hp, max_hp]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var idx: int = i
		button.pressed.connect(
			func() -> void: target_chosen.emit(idx)
		)
		_member_container.add_child(button)
