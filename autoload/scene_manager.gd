extends Node
## Manages scene transitions with optional fade effects.


signal transition_started
signal transition_finished

@onready var _fade_layer: CanvasLayer = CanvasLayer.new()
@onready var _fade_rect: ColorRect = ColorRect.new()

var _is_transitioning: bool = false


func _ready() -> void:
	_setup_fade_layer()


func _setup_fade_layer() -> void:
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0
	_fade_layer.add_child(_fade_rect)


## Change scene with optional fade transition.
## fade_duration: Time in seconds for fade out + fade in (0 = instant).
func change_scene(path: String, fade_duration: float = 0.3) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	transition_started.emit()

	if fade_duration > 0:
		await _fade_out(fade_duration / 2.0)

	get_tree().change_scene_to_file(path)

	if fade_duration > 0:
		await _fade_in(fade_duration / 2.0)

	_is_transitioning = false
	transition_finished.emit()


## Instant scene change (no fade).
func change_scene_instant(path: String) -> void:
	change_scene(path, 0.0)


func _fade_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, duration)
	await tween.finished
