extends Node
## Player display and battle preferences. Persists to user://settings.cfg.

enum DisplayPreference {
	JAPANESE,
	DUB,
}

enum TextSpeed {
	SLOW,
	MEDIUM,
	FAST,
	INSTANT,
}

enum AdvanceMode {
	MANUAL,
	AUTO,
}

enum WindowScale {
	SCALE_1X,
	SCALE_1_25X,
	SCALE_1_5X,
	SCALE_2X,
}

signal display_preference_changed(preference: DisplayPreference)
signal use_game_names_changed(enabled: bool)
signal text_speed_changed(speed: TextSpeed)
signal advance_mode_changed(mode: AdvanceMode)
signal window_scale_changed(scale: WindowScale)

const _SAVE_PATH: String = "user://settings.cfg"
const _DISPLAY_SECTION: String = "display"
const _BATTLE_SECTION: String = "battle"

const TEXT_SPEED_CPS: Dictionary = {
	TextSpeed.SLOW: 20,
	TextSpeed.MEDIUM: 40,
	TextSpeed.FAST: 80,
	TextSpeed.INSTANT: 0,
}
const AUTO_ADVANCE_DELAY: float = 1.2

const _BASE_RESOLUTION := Vector2i(1920, 1080)

const WINDOW_SCALE_VALUES: Dictionary = {
	WindowScale.SCALE_1X: 1.0,
	WindowScale.SCALE_1_25X: 1.25,
	WindowScale.SCALE_1_5X: 1.5,
	WindowScale.SCALE_2X: 2.0,
}

const WINDOW_SCALE_LABELS: Dictionary = {
	WindowScale.SCALE_1X: "1x (1920×1080)",
	WindowScale.SCALE_1_25X: "1.25x (2400×1350)",
	WindowScale.SCALE_1_5X: "1.5x (2880×1620)",
	WindowScale.SCALE_2X: "2x (3840×2160)",
}

var display_preference: DisplayPreference = DisplayPreference.DUB:
	set(value):
		if display_preference == value:
			return
		display_preference = value
		display_preference_changed.emit(value)
		_save()

var use_game_names: bool = true:
	set(value):
		if use_game_names == value:
			return
		use_game_names = value
		use_game_names_changed.emit(value)
		_save()

var text_speed: TextSpeed = TextSpeed.MEDIUM:
	set(value):
		if text_speed == value:
			return
		text_speed = value
		text_speed_changed.emit(value)
		_save()

var advance_mode: AdvanceMode = AdvanceMode.MANUAL:
	set(value):
		if advance_mode == value:
			return
		advance_mode = value
		advance_mode_changed.emit(value)
		_save()

var window_scale: WindowScale = WindowScale.SCALE_1X:
	set(value):
		if window_scale == value:
			return
		window_scale = value
		window_scale_changed.emit(value)
		_apply_window_scale()
		_save()


func _ready() -> void:
	_load()
	_apply_window_scale()


func _apply_window_scale() -> void:
	if OS.has_feature("editor"):
		return
	var factor: float = WINDOW_SCALE_VALUES.get(window_scale, 1.0)
	var new_size := Vector2i(
		roundi(_BASE_RESOLUTION.x * factor),
		roundi(_BASE_RESOLUTION.y * factor)
	)
	DisplayServer.window_set_size(new_size)
	var screen_size := DisplayServer.screen_get_size()
	@warning_ignore("integer_division")
	var position := Vector2i(
		maxi((screen_size.x - new_size.x) / 2, 0),
		maxi((screen_size.y - new_size.y) / 2, 0)
	)
	DisplayServer.window_set_position(position)


func _load() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load(_SAVE_PATH)
	if error != OK:
		_save()
		return
	display_preference = config.get_value(
		_DISPLAY_SECTION, "display_preference", DisplayPreference.DUB
	) as DisplayPreference
	use_game_names = config.get_value(
		_DISPLAY_SECTION, "use_game_names", true
	) as bool
	window_scale = config.get_value(
		_DISPLAY_SECTION, "window_scale", WindowScale.SCALE_1X
	) as WindowScale
	text_speed = config.get_value(
		_BATTLE_SECTION, "text_speed", TextSpeed.MEDIUM
	) as TextSpeed
	advance_mode = config.get_value(
		_BATTLE_SECTION, "advance_mode", AdvanceMode.MANUAL
	) as AdvanceMode


func get_evolving_word() -> String:
	if display_preference == DisplayPreference.DUB:
		return "Digivolving"
	return "Evolving"


func get_evolved_word() -> String:
	if display_preference == DisplayPreference.DUB:
		return "digivolved"
	return "evolved"


func get_evolution_noun() -> String:
	if display_preference == DisplayPreference.DUB:
		return "Digivolution"
	return "Evolution"


func get_evolve_imperative() -> String:
	if display_preference == DisplayPreference.DUB:
		return "Digivolve!"
	return "Evolve!"


func get_evolutions_plural() -> String:
	if display_preference == DisplayPreference.DUB:
		return "Digivolutions"
	return "Evolutions"


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(_DISPLAY_SECTION, "display_preference", display_preference)
	config.set_value(_DISPLAY_SECTION, "use_game_names", use_game_names)
	config.set_value(_DISPLAY_SECTION, "window_scale", window_scale)
	config.set_value(_BATTLE_SECTION, "text_speed", text_speed)
	config.set_value(_BATTLE_SECTION, "advance_mode", advance_mode)
	config.save(_SAVE_PATH)
