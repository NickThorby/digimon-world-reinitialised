class_name SideStatusDisplay
extends HBoxContainer
## Displays active side effects and hazards as coloured tags for one battle side.


func refresh_from_side(side: SideState) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	# Side effects
	for effect: Dictionary in side.side_effects:
		var key: StringName = effect.get("key", &"") as StringName
		var dur: int = int(effect.get("duration", 0))
		_add_tag(
			str(key).replace("_", " ").capitalize(),
			Color(0.3, 0.7, 0.9), dur,
		)

	# Hazards
	for hazard: Dictionary in side.hazards:
		var key: StringName = hazard.get("key", &"") as StringName
		var layers: int = int(hazard.get("layers", 1))
		var label_text: String = hazard.get("source_name", "") as String
		if label_text.is_empty():
			label_text = str(key).replace("_", " ").capitalize()
		if layers > 1:
			label_text += " x%d" % layers
		_add_tag(label_text, Color(0.9, 0.4, 0.3), -1)


func _add_tag(label_text: String, colour: Color, duration: int) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour, 0.4)
	style.border_color = colour
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	if duration > 0:
		label.text = "%s (%d)" % [label_text, duration]
	else:
		label.text = label_text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)

	add_child(panel)
