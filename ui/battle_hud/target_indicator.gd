class_name TargetIndicator
extends Control
## Draws a rotating dashed circle around a battlefield sprite to indicate a valid target.
## Added as a child of the sprite's VBox during targeting mode. Mouse-transparent.


enum IndicatorColour {
	FOE,
	ALLY,
}

const DASH_COUNT: int = 12
const DASH_ARC: float = TAU / DASH_COUNT * 0.6
const GAP_ARC: float = TAU / DASH_COUNT * 0.4
const LINE_WIDTH: float = 2.0
const ROTATION_SPEED: float = 1.5  ## Radians per second

var indicator_colour: IndicatorColour = IndicatorColour.FOE

var _angle_offset: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_angle_offset += ROTATION_SPEED * delta
	if _angle_offset > TAU:
		_angle_offset -= TAU
	queue_redraw()


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) / 2.0 - LINE_WIDTH
	if radius <= 0.0:
		return

	var colour: Color = Color(0.9, 0.2, 0.2, 0.8) if \
		indicator_colour == IndicatorColour.FOE else Color(0.2, 0.9, 0.3, 0.8)

	var step: float = TAU / DASH_COUNT
	for i: int in DASH_COUNT:
		var start_angle: float = _angle_offset + step * i
		draw_arc(centre, radius, start_angle, start_angle + DASH_ARC, 16, colour, LINE_WIDTH)


## Factory method to create a configured indicator.
static func create(colour: IndicatorColour) -> TargetIndicator:
	var indicator := TargetIndicator.new()
	indicator.indicator_colour = colour
	return indicator
