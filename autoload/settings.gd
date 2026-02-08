extends Node
## Player display preferences. Persists to user://settings.cfg.

enum DisplayPreference {
	JAPANESE,
	DUB,
}

signal display_preference_changed(preference: DisplayPreference)
signal use_game_names_changed(enabled: bool)

const _SAVE_PATH: String = "user://settings.cfg"
const _SECTION: String = "display"

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


func _ready() -> void:
	_load()


func _load() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load(_SAVE_PATH)
	if error != OK:
		_save()
		return
	display_preference = config.get_value(
		_SECTION, "display_preference", DisplayPreference.DUB
	) as DisplayPreference
	use_game_names = config.get_value(_SECTION, "use_game_names", true) as bool


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(_SECTION, "display_preference", display_preference)
	config.set_value(_SECTION, "use_game_names", use_game_names)
	config.save(_SAVE_PATH)
