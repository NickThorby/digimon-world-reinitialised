extends Control
## Training Screen
##
## Purpose: Train a Digimon's TVs (standard) or hyper-train IVs.
##
## Context inputs (Game.screen_context):
##   mode: Registry.GameMode — TEST or STORY
##   party_index: int — index of party member to train (-1 = show selector)
##   return_scene: String — scene to navigate back to
##   hyper_unlocked: bool — whether Hyper Training tab is visible (default false)
##
## Context outputs (Game.screen_result):
##   None

const PARTY_SCREEN_PATH := "res://scenes/screens/party_screen.tscn"
const TRAINING_SCREEN_PATH := "res://scenes/screens/training_screen.tscn"

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _DIGI := "MarginContainer/VBox/DigimonHeader"
const _ANIM := "MarginContainer/VBox/AnimationOverlay/AnimationVBox"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _tp_label: Label = get_node(_HEADER + "/TPLabel")
@onready var _sprite_rect: TextureRect = get_node(_DIGI + "/SpriteRect")
@onready var _name_label: Label = get_node(_DIGI + "/DigimonInfoVBox/DigimonNameLabel")
@onready var _level_label: Label = get_node(_DIGI + "/DigimonInfoVBox/DigimonLevelLabel")
@onready var _tab_row: HBoxContainer = $MarginContainer/VBox/TabRow
@onready var _standard_tab: Button = $MarginContainer/VBox/TabRow/StandardTab
@onready var _hyper_tab: Button = $MarginContainer/VBox/TabRow/HyperTab
@onready var _total_tv_label: Label = $MarginContainer/VBox/TotalTVLabel
@onready var _stat_rows: VBoxContainer = $MarginContainer/VBox/ScrollContainer/StatRows
@onready var _animation_overlay: PanelContainer = $MarginContainer/VBox/AnimationOverlay
@onready var _step_label_1: Label = get_node(_ANIM + "/StepLabel1")
@onready var _step_label_2: Label = get_node(_ANIM + "/StepLabel2")
@onready var _step_label_3: Label = get_node(_ANIM + "/StepLabel3")
@onready var _result_label: Label = get_node(_ANIM + "/ResultLabel")
@onready var _done_button: Button = get_node(_ANIM + "/DoneButton")

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _party_index: int = -1
var _return_scene: String = ""
var _hyper_unlocked: bool = false
var _is_hyper: bool = false
var _digimon: DigimonState = null
var _rng := RandomNumberGenerator.new()
var _hop_tween: Tween = null

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
		# Wait for any in-progress scene transition before redirecting,
		# otherwise SceneManager silently drops the change_scene call.
		if SceneManager._is_transitioning:
			await SceneManager.transition_finished
		_navigate_to_party_selector()
		return

	_digimon = Game.state.party.members[_party_index]
	_rng.randomize()

	_update_header()
	_update_digimon_info()
	_configure_tabs()
	_build_stat_rows()
	_connect_signals()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_party_index = ctx.get("party_index", -1)
	_hyper_unlocked = ctx.get("hyper_unlocked", false)

	# Prefer original_return_scene (preserved through party selector redirect)
	_return_scene = ctx.get("original_return_scene",
		ctx.get("return_scene", ""))

	# Check if we got a result from party selector
	if _party_index < 0 and Game.screen_result is Dictionary:
		var result: Dictionary = Game.screen_result as Dictionary
		_party_index = result.get("party_index", -1)
		Game.screen_result = null


func _navigate_to_party_selector() -> void:
	Game.screen_context = {
		"mode": _mode,
		"select_mode": true,
		"select_prompt": "Select Digimon to train",
		"return_scene": TRAINING_SCREEN_PATH,
		"original_return_scene": _return_scene,
		"hyper_unlocked": _hyper_unlocked,
	}
	SceneManager.change_scene(PARTY_SCREEN_PATH)


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


func _configure_tabs() -> void:
	if _hyper_unlocked:
		_tab_row.visible = true
		_title_label.text = "Standard Training"
	else:
		_tab_row.visible = false
		_title_label.text = "Training"
	_hyper_tab.visible = _hyper_unlocked
	_is_hyper = false
	_standard_tab.button_pressed = true
	_hyper_tab.button_pressed = false


func _connect_signals() -> void:
	_standard_tab.pressed.connect(_on_standard_tab)
	_hyper_tab.pressed.connect(_on_hyper_tab)
	_done_button.pressed.connect(_on_done_pressed)


func _on_back_pressed() -> void:
	var target: String = _return_scene if _return_scene != "" \
		else "res://scenes/screens/mode_screen.tscn"
	Game.screen_context = {"mode": _mode}
	SceneManager.change_scene(target)


func _on_standard_tab() -> void:
	_is_hyper = false
	_standard_tab.button_pressed = true
	_hyper_tab.button_pressed = false
	_title_label.text = "Standard Training"
	_build_stat_rows()
	_update_total_tv_label()


func _on_hyper_tab() -> void:
	_is_hyper = true
	_standard_tab.button_pressed = false
	_hyper_tab.button_pressed = true
	_title_label.text = "Hyper Training"
	_build_stat_rows()
	_update_total_tv_label()


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
	var base_iv: int = _digimon.ivs.get(stat_key, 0) as int
	var hyper_iv: int = _digimon.hyper_trained_ivs.get(stat_key, 0) as int
	var final_iv: int = _digimon.get_final_iv(stat_key)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(90, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d + %d = %d" % [base_iv, hyper_iv, final_iv]
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
	_tp_label.text = "TP: %d" % _digimon.training_points

	# Run course
	var result: Dictionary
	if _is_hyper:
		result = TrainingCalculator.run_hyper_course(difficulty, _rng)
	else:
		result = TrainingCalculator.run_course(difficulty, _rng)

	# Show animation
	_play_training_animation(stat_key, result)


func _play_training_animation(stat_key: StringName, result: Dictionary) -> void:
	_animation_overlay.visible = true
	_done_button.visible = false
	_result_label.text = ""

	var steps: Array = result.get("steps", [])
	var step_labels: Array[Label] = [_step_label_1, _step_label_2, _step_label_3]

	for i: int in step_labels.size():
		step_labels[i].text = "Step %d: ..." % (i + 1)

	# Start hop animation
	_start_hop()

	# Animate steps sequentially
	var tween := create_tween()
	for i: int in mini(steps.size(), 3):
		var passed: bool = steps[i] as bool
		var label: Label = step_labels[i]
		tween.tween_interval(0.3)
		tween.tween_callback(func() -> void:
			if passed:
				label.text = "Step %d: Pass!" % (i + 1)
				label.add_theme_color_override(
					"font_color", Color(0.3, 0.85, 0.3, 1),
				)
			else:
				label.text = "Step %d: Fail" % (i + 1)
				label.add_theme_color_override(
					"font_color", Color(0.85, 0.3, 0.3, 1),
				)
		)

	# Show result
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		_stop_hop()
		_apply_training_result(stat_key, result)
		if _is_hyper:
			var iv_gained: int = result.get("iv_gained", 0)
			_result_label.text = "IV gained: +%d" % iv_gained
		else:
			var tv_gained: int = result.get("tv_gained", 0)
			_result_label.text = "TV gained: +%d" % tv_gained
		_done_button.visible = true
	)


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


func _on_done_pressed() -> void:
	_animation_overlay.visible = false
	_build_stat_rows()
	_update_header()


func _start_hop() -> void:
	_stop_hop()
	_hop_tween = create_tween()
	_hop_tween.set_loops()
	_hop_tween.tween_property(_sprite_rect, "position:y",
		_sprite_rect.position.y - 8.0, 0.15)
	_hop_tween.tween_property(_sprite_rect, "position:y",
		_sprite_rect.position.y, 0.15)


func _stop_hop() -> void:
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
		_hop_tween = null
