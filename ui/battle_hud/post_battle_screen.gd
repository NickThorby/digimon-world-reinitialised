class_name PostBattleScreen
extends Control
## Displays battle outcome, XP bars with animations, stat deltas, and technique
## swap prompts for each Digimon on the winning side.


signal continue_pressed

const XP_AWARD_ROW_SCENE := preload("res://ui/battle_hud/xp_award_row.tscn")
const STAT_DELTA_POPUP_SCENE := preload("res://ui/battle_hud/stat_delta_popup.tscn")
const TECHNIQUE_SWAP_POPUP_SCENE := preload(
	"res://ui/battle_hud/technique_swap_popup.tscn"
)

@onready var _outcome_label: Label = $Panel/VBox/OutcomeLabel
@onready var _turn_count_label: Label = $Panel/VBox/TurnCountLabel
@onready var _xp_container: VBoxContainer = $Panel/VBox/ScrollContainer/XPContainer
@onready var _popup_layer: Control = $PopupLayer
@onready var _continue_button: Button = $Panel/VBox/ContinueButton

var _xp_rows: Array[XPAwardRow] = []
var _technique_swap_queue: Array[Dictionary] = []
var _balance: GameBalance = null


func _ready() -> void:
	_continue_button.pressed.connect(
		func() -> void: continue_pressed.emit()
	)
	_continue_button.disabled = true
	visible = false
	_balance = load("res://data/config/game_balance.tres") as GameBalance


## Show the post-battle results.
func show_results(result: BattleResult) -> void:
	# Outcome text
	match result.outcome:
		BattleResult.Outcome.WIN:
			_outcome_label.text = "Victory!"
		BattleResult.Outcome.LOSS:
			_outcome_label.text = "Defeat..."
		BattleResult.Outcome.DRAW:
			_outcome_label.text = "Draw"
		BattleResult.Outcome.FLED:
			_outcome_label.text = "Escaped!"

	_turn_count_label.text = "Turns: %d" % result.turn_count

	# Clear previous rows
	for child: Node in _xp_container.get_children():
		child.queue_free()
	_xp_rows.clear()
	_technique_swap_queue.clear()

	# Build award lookup
	var award_map: Dictionary = {}  # DigimonState -> award dict
	for award: Dictionary in result.xp_awards:
		var state: DigimonState = award.get("digimon_state") as DigimonState
		if state != null:
			award_map[state] = award

	# Build rows for each party Digimon
	var max_equipped: int = _balance.max_equipped_techniques if _balance else 4
	for state: DigimonState in result.party_digimon:
		var row: XPAwardRow = XP_AWARD_ROW_SCENE.instantiate() as XPAwardRow
		_xp_container.add_child(row)

		if award_map.has(state):
			var award: Dictionary = award_map[state]
			row.setup(state, award)
			row.row_clicked.connect(_on_row_clicked.bind(award))

			# Auto-equip new techniques if there's room
			var new_techs: Array = award.get("new_techniques", []) as Array
			for tech_key: Variant in new_techs:
				var key: StringName = tech_key as StringName
				if state.equipped_technique_keys.size() < max_equipped:
					if key not in state.equipped_technique_keys:
						state.equipped_technique_keys.append(key)
				else:
					# Queue technique swap
					_technique_swap_queue.append({
						"state": state,
						"technique_key": key,
					})
		else:
			row.setup_no_xp(state)

		_xp_rows.append(row)

	visible = true

	# Animate XP bars, then process technique swaps
	_run_post_battle_sequence()


## Sequentially animate XP bars and process technique swaps.
func _run_post_battle_sequence() -> void:
	# Wait a frame for layout
	await get_tree().process_frame

	# Animate all XP bars
	for row: XPAwardRow in _xp_rows:
		if row.is_inside_tree():
			await row.animate_xp_bar()

	# Process technique swap queue one at a time
	for swap: Dictionary in _technique_swap_queue:
		if not is_inside_tree():
			break
		var state: DigimonState = swap["state"] as DigimonState
		var tech_key: StringName = swap["technique_key"] as StringName
		await _show_technique_swap(state, tech_key)

	# Enable continue button
	_continue_button.disabled = false
	_continue_button.grab_focus()


## Show a technique swap popup and wait for the player's choice.
func _show_technique_swap(
	state: DigimonState, new_technique_key: StringName,
) -> void:
	var popup: TechniqueSwapPopup = TECHNIQUE_SWAP_POPUP_SCENE.instantiate() \
		as TechniqueSwapPopup
	_popup_layer.add_child(popup)
	popup.setup(state, new_technique_key)

	var done: Array[bool] = [false]
	popup.technique_chosen.connect(
		func(forgotten_key: StringName) -> void:
			# Replace forgotten technique with new one
			var idx: int = state.equipped_technique_keys.find(forgotten_key)
			if idx >= 0:
				state.equipped_technique_keys[idx] = new_technique_key
			done[0] = true
	)
	popup.kept_current.connect(
		func() -> void:
			# Player chose not to learn — technique stays in known_technique_keys
			done[0] = true
	)

	while not done[0]:
		await get_tree().process_frame

	popup.queue_free()


## Handle clicking a levelled-up row — show stat delta popup.
func _on_row_clicked(state: DigimonState, award: Dictionary) -> void:
	var old_stats: Dictionary = award.get("old_stats", {}) as Dictionary
	var old_level: int = int(award.get("old_level", state.level))

	if int(award.get("levels_gained", 0)) <= 0:
		return

	# Remove existing popup if any
	for child: Node in _popup_layer.get_children():
		child.queue_free()

	var popup: StatDeltaPopup = STAT_DELTA_POPUP_SCENE.instantiate() \
		as StatDeltaPopup
	_popup_layer.add_child(popup)
	popup.show_delta(state, old_stats, old_level)
	popup.closed.connect(func() -> void: popup.queue_free())
