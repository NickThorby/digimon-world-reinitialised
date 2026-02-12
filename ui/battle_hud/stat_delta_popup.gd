class_name StatDeltaPopup
extends PanelContainer
## Shows stat changes after a level-up: old vs new with coloured deltas.


signal closed

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _stat_grid: GridContainer = $VBox/StatGrid
@onready var _close_button: Button = $VBox/CloseButton

const STAT_LABELS: Dictionary = {
	&"hp": "HP",
	&"energy": "Energy",
	&"attack": "Attack",
	&"defence": "Defence",
	&"special_attack": "Sp. Atk",
	&"special_defence": "Sp. Def",
	&"speed": "Speed",
}


func _ready() -> void:
	_close_button.pressed.connect(func() -> void: closed.emit())


## Show the stat comparison for a levelled-up Digimon.
func show_delta(
	state: DigimonState, old_stats: Dictionary, old_level: int,
) -> void:
	var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
	var display_name: String = data.display_name if data else str(state.key)
	_title_label.text = "%s: Lv. %d -> %d" % [
		display_name, old_level, state.level,
	]

	# Calculate new stats
	var new_stats: Dictionary = {}
	if data != null:
		new_stats = StatCalculator.calculate_all_stats(data, state)
		var personality: PersonalityData = Atlas.personalities.get(
			state.get_effective_personality_key(),
		) as PersonalityData
		for stat_key: StringName in new_stats:
			new_stats[stat_key] = StatCalculator.apply_personality(
				new_stats[stat_key], stat_key, personality,
			)

	# Clear grid
	for child: Node in _stat_grid.get_children():
		child.queue_free()

	# Populate grid: Stat Name | Old -> New | Delta
	var stat_order: Array[StringName] = [
		&"hp", &"energy", &"attack", &"defence",
		&"special_attack", &"special_defence", &"speed",
	]
	for stat_key: StringName in stat_order:
		var old_val: int = int(old_stats.get(stat_key, 0))
		var new_val: int = int(new_stats.get(stat_key, 0))
		var delta: int = new_val - old_val

		var name_label := Label.new()
		name_label.text = STAT_LABELS.get(stat_key, str(stat_key))
		_stat_grid.add_child(name_label)

		var value_label := Label.new()
		value_label.text = "%d -> %d" % [old_val, new_val]
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stat_grid.add_child(value_label)

		var delta_label := Label.new()
		if delta > 0:
			delta_label.text = "+%d" % delta
			delta_label.add_theme_color_override(
				"font_color", Color(0.2, 0.9, 0.3),
			)
		elif delta < 0:
			delta_label.text = "%d" % delta
			delta_label.add_theme_color_override(
				"font_color", Color(0.9, 0.2, 0.2),
			)
		else:
			delta_label.text = "+0"
			delta_label.add_theme_color_override(
				"font_color", Color(0.631, 0.631, 0.667),
			)
		delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stat_grid.add_child(delta_label)

	visible = true
