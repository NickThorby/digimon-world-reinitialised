class_name PostBattleScreen
extends Control
## Displays battle outcome, XP breakdown, level-ups, and new techniques.


signal continue_pressed

@onready var _outcome_label: Label = $Panel/VBox/OutcomeLabel
@onready var _turn_count_label: Label = $Panel/VBox/TurnCountLabel
@onready var _xp_container: VBoxContainer = $Panel/VBox/ScrollContainer/XPContainer
@onready var _continue_button: Button = $Panel/VBox/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	visible = false


## Show the post-battle results.
func show_results(result: BattleResult) -> void:
	# Outcome
	match result.outcome:
		BattleResult.Outcome.WIN:
			_outcome_label.text = "Victory!"
		BattleResult.Outcome.LOSS:
			_outcome_label.text = "Defeat..."
		BattleResult.Outcome.DRAW:
			_outcome_label.text = "Draw"
		BattleResult.Outcome.FLED:
			_outcome_label.text = "Escaped!"

	# Turn count
	_turn_count_label.text = "Turns: %d" % result.turn_count

	# XP awards
	for child: Node in _xp_container.get_children():
		child.queue_free()

	for award: Dictionary in result.xp_awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state == null:
			continue

		var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
		var name: String = data.display_name if data else str(state.key)
		var xp: int = int(award.get("xp", 0))
		var levels: int = int(award.get("levels_gained", 0))
		var new_techs: Array = award.get("new_techniques", []) as Array

		var label := Label.new()
		var text: String = "%s gained %d XP" % [name, xp]
		if levels > 0:
			text += " — Levelled up to %d!" % state.level
		label.text = text
		_xp_container.add_child(label)

		# New techniques
		for tech_key: Variant in new_techs:
			var tech: TechniqueData = Atlas.techniques.get(
				tech_key as StringName
			) as TechniqueData
			var tech_label := Label.new()
			tech_label.text = "  Learned %s!" % (
				tech.display_name if tech else str(tech_key)
			)
			_xp_container.add_child(tech_label)

	visible = true
