class_name TargetIndicator
extends Control
## Pulses the parent sprite's opacity to indicate a valid target.
## Added as a child of the sprite during targeting mode. Mouse-transparent.


enum IndicatorColour {
	FOE,
	ALLY,
}

var indicator_colour: IndicatorColour = IndicatorColour.FOE

var _original_modulate: Color = Color.WHITE
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var parent_ctrl: Control = get_parent() as Control
	if parent_ctrl == null:
		return

	_original_modulate = parent_ctrl.modulate

	# Apply a subtle colour tint based on foe/ally
	var tint: Color = Color(1.15, 0.9, 0.9) if \
		indicator_colour == IndicatorColour.FOE else Color(0.9, 1.15, 0.9)
	parent_ctrl.modulate = _original_modulate * tint

	# Start a looping opacity pulse
	_tween = get_tree().create_tween().set_loops()
	_tween.tween_property(parent_ctrl, "modulate:a", 0.5, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(parent_ctrl, "modulate:a", 1.0, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

	var parent_ctrl: Control = get_parent() as Control
	if parent_ctrl != null:
		parent_ctrl.modulate = _original_modulate


## Factory method to create a configured indicator.
static func create(colour: IndicatorColour) -> TargetIndicator:
	var indicator := TargetIndicator.new()
	indicator.indicator_colour = colour
	return indicator
