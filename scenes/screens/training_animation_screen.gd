extends Control
## Training Animation Screen
##
## Purpose: Full-screen training animation with large Digimon sprite and O/X step indicators.
##
## Context inputs (Game.screen_context):
##   digimon_key: StringName — for loading sprite + size_trait
##   stat_key: StringName — which stat was trained
##   is_hyper: bool — hyper or standard
##   result: Dictionary — from TrainingCalculator.run_course/run_hyper_course
##   return_scene: String — path to training screen
##   mode: Registry.GameMode
##   party_index: int — party member index
##   hyper_unlocked: bool — whether hyper training is available
##
## On done, sets Game.screen_context with from_training_animation flag and returns.

const _HEADER := "MarginContainer/VBox/HeaderBar"

@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _sprite_rect: TextureRect = $MarginContainer/VBox/SpriteCenterContainer/SpriteRect
@onready var _step_label_1: Label = $MarginContainer/VBox/StepContainer/StepLabel1
@onready var _step_label_2: Label = $MarginContainer/VBox/StepContainer/StepLabel2
@onready var _step_label_3: Label = $MarginContainer/VBox/StepContainer/StepLabel3
@onready var _result_label: Label = $MarginContainer/VBox/ResultLabel
@onready var _done_button: Button = $MarginContainer/VBox/DoneButton

var _digimon_key: StringName = &""
var _stat_key: StringName = &""
var _is_hyper: bool = false
var _result: Dictionary = {}
var _return_scene: String = ""
var _mode: Registry.GameMode = Registry.GameMode.TEST
var _party_index: int = -1
var _hyper_unlocked: bool = false
var _hop_tween: Tween = null

const SIZE_SCALES: Dictionary = {
	&"tiny": 0.55,
	&"small": 0.7,
	&"medium": 0.85,
	&"large": 1.0,
	&"huge": 1.15,
	&"gargantuan": 1.3,
}


func _ready() -> void:
	var ctx: Dictionary = Game.screen_context
	_digimon_key = StringName(ctx.get("digimon_key", ""))
	_stat_key = StringName(ctx.get("stat_key", ""))
	_is_hyper = ctx.get("is_hyper", false) as bool
	_result = ctx.get("result", {}) as Dictionary
	_return_scene = ctx.get("return_scene", "") as String
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_party_index = ctx.get("party_index", -1) as int
	_hyper_unlocked = ctx.get("hyper_unlocked", false) as bool

	_done_button.pressed.connect(_on_done_pressed)

	# Load Digimon data for sprite and size
	var data: DigimonData = Atlas.digimon.get(_digimon_key) as DigimonData
	if data:
		_sprite_rect.texture = data.sprite_texture
		_sprite_rect.flip_h = true

		var size_scale: float = SIZE_SCALES.get(data.size_trait, 0.85) as float
		var base_size: float = 256.0
		var scaled: float = base_size * size_scale
		_sprite_rect.custom_minimum_size = Vector2(scaled, scaled)

	# Initialise step labels
	_step_label_1.text = "..."
	_step_label_2.text = "..."
	_step_label_3.text = "..."
	_result_label.text = ""
	_done_button.visible = false
	_title_label.text = "Training..."

	_animate_steps()


func _animate_steps() -> void:
	_start_hop()

	var steps: Array = _result.get("steps", [])
	var step_labels: Array[Label] = [_step_label_1, _step_label_2, _step_label_3]

	var tween := create_tween()
	for i: int in mini(steps.size(), 3):
		var passed: bool = steps[i] as bool
		var label: Label = step_labels[i]
		tween.tween_interval(1.0)
		tween.tween_callback(func() -> void:
			if passed:
				label.text = "O"
				label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
			else:
				label.text = "X"
				label.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))
		)

	# Show result after last step
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void:
		_stop_hop()
		_title_label.text = "Training Complete!"
		if _is_hyper:
			var iv_gained: int = _result.get("iv_gained", 0) as int
			_result_label.text = "IV gained: +%d" % iv_gained
		else:
			var tv_gained: int = _result.get("tv_gained", 0) as int
			_result_label.text = "TV gained: +%d" % tv_gained
		_done_button.visible = true
	)


func _on_done_pressed() -> void:
	Game.screen_context = {
		"mode": _mode,
		"party_index": _party_index,
		"hyper_unlocked": _hyper_unlocked,
		"from_training_animation": true,
		"is_hyper": _is_hyper,
	}
	Game.screen_result = {"party_index": _party_index}
	SceneManager.change_scene(_return_scene)


func _start_hop() -> void:
	_stop_hop()
	_hop_tween = create_tween()
	_hop_tween.set_loops()
	_hop_tween.tween_property(
		_sprite_rect, "position:y", _sprite_rect.position.y - 12.0, 0.2,
	)
	_hop_tween.tween_property(
		_sprite_rect, "position:y", _sprite_rect.position.y, 0.2,
	)


func _stop_hop() -> void:
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
		_hop_tween = null
