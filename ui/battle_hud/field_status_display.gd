class_name FieldStatusDisplay
extends HBoxContainer
## Displays active weather, terrain, and global field effects as coloured tags.


var _battle: BattleState = null


func initialise(battle: BattleState) -> void:
	_battle = battle


func refresh() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _battle == null:
		return

	# Weather tag
	if not _battle.field.weather.is_empty():
		var key: StringName = _battle.field.weather.get(
			"key", &"",
		) as StringName
		var dur: int = int(_battle.field.weather.get("duration", 0))
		_add_tag(
			str(key).replace("_", " ").capitalize(),
			_weather_colour(key), dur,
		)

	# Terrain tag
	if not _battle.field.terrain.is_empty():
		var key: StringName = _battle.field.terrain.get(
			"key", &"",
		) as StringName
		var dur: int = int(_battle.field.terrain.get("duration", 0))
		_add_tag(
			"%s Terrain" % str(key).replace("_", " ").capitalize(),
			_terrain_colour(key), dur,
		)

	# Global effects
	for effect: Dictionary in _battle.field.global_effects:
		var key: StringName = effect.get("key", &"") as StringName
		var dur: int = int(effect.get("duration", 0))
		_add_tag(
			str(key).replace("_", " ").capitalize(),
			Color(0.7, 0.5, 0.9), dur,
		)



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


func _weather_colour(key: StringName) -> Color:
	match key:
		&"sun", &"harsh_sun":
			return Color(1.0, 0.84, 0.0)
		&"rain", &"heavy_rain":
			return Color(0.3, 0.5, 1.0)
		&"sandstorm":
			return Color(0.82, 0.71, 0.55)
		&"hail", &"snow":
			return Color(0.85, 0.92, 1.0)
		&"fog":
			return Color(0.7, 0.7, 0.7)
		&"strong_winds":
			return Color(0.0, 0.8, 0.8)
	return Color(0.8, 0.8, 0.8)


func _terrain_colour(key: StringName) -> Color:
	match key:
		&"fiery":
			return Color(0.9, 0.3, 0.1)
		&"flooded":
			return Color(0.2, 0.5, 0.9)
		&"blooming":
			return Color(0.2, 0.8, 0.3)
		&"electric":
			return Color(1.0, 0.9, 0.2)
		&"misty":
			return Color(0.8, 0.6, 0.9)
	return Color(0.6, 0.8, 0.6)
