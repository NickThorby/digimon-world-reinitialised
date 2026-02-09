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

signal display_preference_changed(preference: DisplayPreference)
signal use_game_names_changed(enabled: bool)
signal text_speed_changed(speed: TextSpeed)
signal advance_mode_changed(mode: AdvanceMode)

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


func _ready() -> void:
	_load()


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
	text_speed = config.get_value(
		_BATTLE_SECTION, "text_speed", TextSpeed.MEDIUM
	) as TextSpeed
	advance_mode = config.get_value(
		_BATTLE_SECTION, "advance_mode", AdvanceMode.MANUAL
	) as AdvanceMode


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(_DISPLAY_SECTION, "display_preference", display_preference)
	config.set_value(_DISPLAY_SECTION, "use_game_names", use_game_names)
	config.set_value(_BATTLE_SECTION, "text_speed", text_speed)
	config.set_value(_BATTLE_SECTION, "advance_mode", advance_mode)
	config.save(_SAVE_PATH)
