extends Control
## Training Screen
##
## Purpose: Train a Digimon's TVs (standard) or hyper-train IVs.
##
## Flow: Mode Screen → Party Select → Training Screen (type choice → stat rows).
##
## Context inputs (Game.screen_context):
##   mode: Registry.GameMode — TEST or STORY
##   hyper_unlocked: bool — whether Hyper Training button is visible (default false)
##   from_training_animation: bool — true when returning from animation screen
##   is_hyper: bool — training type (when returning from animation)
##   party_index: int — party member index
##
## Screen result inputs (Game.screen_result):
##   party_index: int — index of party member to train (from party selector)
##
## Context outputs (Game.screen_result):
##   None

const MODE_SCREEN_PATH := "res://scenes/screens/mode_screen.tscn"
const TRAINING_ANIMATION_PATH := "res://scenes/screens/training_animation_screen.tscn"

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _DIGI := "MarginContainer/VBox/DigimonHeader"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _tp_label: Label = get_node(_HEADER + "/TPLabel")
@onready var _sprite_rect: TextureRect = get_node(_DIGI + "/SpriteRect")
@onready var _name_label: Label = get_node(_DIGI + "/DigimonInfoVBox/DigimonNameLabel")
@onready var _level_label: Label = get_node(_DIGI + "/DigimonInfoVBox/DigimonLevelLabel")
@onready var _type_select_center: CenterContainer = $MarginContainer/VBox/TypeSelectCenter
@onready var _standard_button: Button = $MarginContainer/VBox/TypeSelectCenter/TypeSelectVBox/StandardButton
@onready var _hyper_button: Button = $MarginContainer/VBox/TypeSelectCenter/TypeSelectVBox/HyperButton
@onready var _total_tv_label: Label = $MarginContainer/VBox/TotalTVLabel
@onready var _scroll_container: ScrollContainer = $MarginContainer/VBox/ScrollContainer
@onready var _stat_rows: VBoxContainer = $MarginContainer/VBox/ScrollContainer/StatRows

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _party_index: int = -1
var _hyper_unlocked: bool = false
var _is_hyper: bool = false
var _type_selected: bool = false
var _digimon: DigimonState = null
var _rng := RandomNumberGenerator.new()

const STAT_KEYS: Array[StringName] = [
	&"hp", &"energy", &"attack", &"defence",
	&"special_attack", &"special_defence", &"speed",
]

const STAT_DISPLAY_NAMES: Dictionary = {
	&"hp": "HP",
	&"energy": "Energy",
	&"attack": "Attack",
	&"defence": "Defence",
	&"special_attack": "Sp. Attack",
	&"special_defence": "Sp. Defence",
	&"speed": "Speed",
}

const DIFFICULTIES: Array[String] = ["basic", "intermediate", "advanced"]


func _ready() -> void:
	_read_context()

	# Always connect back button so the user is never stuck
	_back_button.pressed.connect(_on_back_pressed)

	if Game.state == null or Game.state.party.members.is_empty():
		return

	if _party_index < 0 or _party_index >= Game.state.party.members.size():
		# Invalid selection — go back to mode screen
		Game.screen_context = {"mode": _mode}
		SceneManager.change_scene(MODE_SCREEN_PATH)
		return

	_digimon = Game.state.party.members[_party_index]
	_rng.randomize()

	_update_digimon_info()
	_show_type_selection()
	_connect_signals()

	# When returning from animation screen, skip type selection
	if _type_selected:
		_type_select_center.visible = false
		_scroll_container.visible = true
		_title_label.text = "Hyper Training" if _is_hyper else "Standard Training"
		_update_header()
		_build_stat_rows()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	var default_hyper: bool = _mode == Registry.GameMode.TEST
	_hyper_unlocked = ctx.get("hyper_unlocked", default_hyper)
	_party_index = ctx.get("party_index", -1) as int

	# Returning from animation screen — skip party selector, go straight to stat rows
	if ctx.get("from_training_animation", false):
		_is_hyper = ctx.get("is_hyper", false) as bool
		_type_selected = true
		Game.screen_result = null
		return

	# Read party_index from screen_result (set by party selector)
	if Game.screen_result is Dictionary:
		var result: Dictionary = Game.screen_result as Dictionary
		_party_index = result.get("party_index", -1)
		Game.screen_result = null


func _show_type_selection() -> void:
	_type_selected = false
	_title_label.text = "Training"
	_tp_label.text = "TP: %d" % _digimon.training_points
	_type_select_center.visible = true
	_total_tv_label.visible = false
	_scroll_container.visible = false
	_hyper_button.visible = _hyper_unlocked


func _on_type_selected(hyper: bool) -> void:
	_is_hyper = hyper
	_type_selected = true
	_type_select_center.visible = false
	_scroll_container.visible = true
	_title_label.text = "Hyper Training" if _is_hyper else "Standard Training"
	_update_header()
	_build_stat_rows()


func _update_header() -> void:
	_tp_label.text = "TP: %d" % _digimon.training_points
	_update_total_tv_label()


func _update_total_tv_label() -> void:
	if _is_hyper:
		_total_tv_label.visible = false
	else:
		_total_tv_label.visible = true
		var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance
		var max_total: int = balance.max_total_tvs if balance else 1000
		_total_tv_label.text = "Total TVs: %d / %d" % [_digimon.get_total_tvs(), max_total]


func _update_digimon_info() -> void:
	var data: DigimonData = Atlas.digimon.get(_digimon.key) as DigimonData
	if data:
		_name_label.text = data.display_name
		_sprite_rect.texture = data.sprite_texture
		_sprite_rect.flip_h = true
	else:
		_name_label.text = str(_digimon.key)
	_level_label.text = "Lv. %d" % _digimon.level


func _connect_signals() -> void:
	_standard_button.pressed.connect(_on_type_selected.bind(false))
	_hyper_button.pressed.connect(_on_type_selected.bind(true))


func _on_back_pressed() -> void:
	if _type_selected:
		_show_type_selection()
		return
	Game.screen_context = {"mode": _mode}
	SceneManager.change_scene(MODE_SCREEN_PATH)



func _build_stat_rows() -> void:
	for child: Node in _stat_rows.get_children():
		child.queue_free()

	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance

	for stat_key: StringName in STAT_KEYS:
		var row := _create_stat_row(stat_key, balance)
		_stat_rows.add_child(row)


func _create_stat_row(stat_key: StringName, balance: GameBalance) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Stat name
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.text = STAT_DISPLAY_NAMES.get(stat_key, str(stat_key))
	name_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_label)

	if _is_hyper:
		_add_hyper_stat_display(hbox, stat_key, balance)
	else:
		_add_standard_stat_display(hbox, stat_key, balance)

	# Difficulty buttons
	for difficulty: String in DIFFICULTIES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 32)
		btn.add_theme_font_size_override("font_size", 13)

		if _is_hyper:
			var tp_cost: int = TrainingCalculator.get_hyper_tp_cost(difficulty)
			btn.text = "%s %dTP" % [difficulty.capitalize(), tp_cost]
			btn.disabled = _is_hyper_button_disabled(stat_key, tp_cost, balance)
		else:
			var tp_cost: int = TrainingCalculator.get_tp_cost(difficulty)
			btn.text = "%s %dTP" % [difficulty.capitalize(), tp_cost]
			btn.disabled = _is_standard_button_disabled(stat_key, tp_cost, balance)

		btn.pressed.connect(_on_train_pressed.bind(stat_key, difficulty))
		hbox.add_child(btn)

	return hbox


func _add_standard_stat_display(
	hbox: HBoxContainer, stat_key: StringName, balance: GameBalance,
) -> void:
	var max_tv: int = balance.max_tv if balance else 500
	var current_tv: int = _digimon.tvs.get(stat_key, 0) as int

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(current_tv)
	value_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(value_label)

	var bar := ProgressBar.new()
	bar.max_value = float(max_tv)
	bar.value = float(current_tv)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	hbox.add_child(bar)


func _add_hyper_stat_display(
	hbox: HBoxContainer, stat_key: StringName, balance: GameBalance,
) -> void:
	var max_iv: int = balance.max_iv if balance else 50
	var final_iv: int = _digimon.get_final_iv(stat_key)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(final_iv)
	value_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(value_label)

	var bar := ProgressBar.new()
	bar.max_value = float(max_iv)
	bar.value = float(final_iv)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	hbox.add_child(bar)


func _is_standard_button_disabled(
	stat_key: StringName, tp_cost: int, balance: GameBalance,
) -> bool:
	if _digimon.training_points < tp_cost:
		return true
	var max_tv: int = balance.max_tv if balance else 500
	if _digimon.tvs.get(stat_key, 0) as int >= max_tv:
		return true
	var max_total: int = balance.max_total_tvs if balance else 1000
	if _digimon.get_total_tvs() >= max_total:
		return true
	return false


func _is_hyper_button_disabled(
	stat_key: StringName, tp_cost: int, balance: GameBalance,
) -> bool:
	if _digimon.training_points < tp_cost:
		return true
	var max_iv: int = balance.max_iv if balance else 50
	if _digimon.get_final_iv(stat_key) >= max_iv:
		return true
	return false


func _on_train_pressed(stat_key: StringName, difficulty: String) -> void:
	if _digimon == null:
		return

	var tp_cost: int
	if _is_hyper:
		tp_cost = TrainingCalculator.get_hyper_tp_cost(difficulty)
	else:
		tp_cost = TrainingCalculator.get_tp_cost(difficulty)

	if _digimon.training_points < tp_cost:
		return

	# Deduct TP
	_digimon.training_points -= tp_cost

	# Run course
	var result: Dictionary
	if _is_hyper:
		result = TrainingCalculator.run_hyper_course(difficulty, _rng)
	else:
		result = TrainingCalculator.run_course(difficulty, _rng)

	# Apply result immediately (animation screen is purely visual)
	_apply_training_result(stat_key, result)

	# Navigate to animation screen
	Game.screen_context = {
		"digimon_key": _digimon.key,
		"stat_key": stat_key,
		"is_hyper": _is_hyper,
		"result": result,
		"return_scene": "res://scenes/screens/training_screen.tscn",
		"mode": _mode,
		"party_index": _party_index,
		"hyper_unlocked": _hyper_unlocked,
	}
	SceneManager.change_scene(TRAINING_ANIMATION_PATH)


func _apply_training_result(stat_key: StringName, result: Dictionary) -> void:
	var balance: GameBalance = load("res://data/config/game_balance.tres") as GameBalance

	if _is_hyper:
		var iv_gained: int = result.get("iv_gained", 0)
		var max_iv: int = balance.max_iv if balance else 50
		var current_hyper: int = _digimon.hyper_trained_ivs.get(stat_key, 0) as int
		var base_iv: int = _digimon.ivs.get(stat_key, 0) as int
		var headroom: int = maxi(max_iv - base_iv - current_hyper, 0)
		_digimon.hyper_trained_ivs[stat_key] = current_hyper + mini(iv_gained, headroom)
	else:
		var tv_gained: int = result.get("tv_gained", 0)
		var max_tv: int = balance.max_tv if balance else 500
		var max_total: int = balance.max_total_tvs if balance else 1000
		var current_tv: int = _digimon.tvs.get(stat_key, 0) as int
		var current_total: int = _digimon.get_total_tvs()
		var per_stat_headroom: int = maxi(max_tv - current_tv, 0)
		var global_headroom: int = maxi(max_total - current_total, 0)
		var actual_gain: int = mini(tv_gained, mini(per_stat_headroom, global_headroom))
		_digimon.tvs[stat_key] = current_tv + actual_gain
