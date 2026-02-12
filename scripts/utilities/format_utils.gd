class_name FormatUtils
extends RefCounted
## Shared formatting utilities used across multiple screens.


## Format an integer with comma separators (e.g. 1234567 -> "1,234,567").
static func format_bits(amount: int) -> String:
	var text: String = str(amount)
	var result: String = ""
	var count: int = 0
	for i: int in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result


## Format total seconds as "h:mm:ss" (e.g. 3661 -> "1:01:01").
static func format_play_time(seconds: int) -> String:
	@warning_ignore("integer_division")
	var h: int = seconds / 3600
	@warning_ignore("integer_division")
	var m: int = (seconds % 3600) / 60
	var s: int = seconds % 60
	return "%d:%02d:%02d" % [h, m, s]


## Format a Unix timestamp as "DD-MM-YYYY HH:MM", or "Unknown" if invalid.
static func format_saved_at(unix: float) -> String:
	if unix <= 0.0:
		return "Unknown"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix))
	return "%02d-%02d-%04d %02d:%02d" % [
		dt.get("day", 0),
		dt.get("month", 0),
		dt.get("year", 0),
		dt.get("hour", 0),
		dt.get("minute", 0),
	]


## Build "Name Lv.X, Name Lv.Y" from save metadata. Returns plain string.
static func build_party_text(meta: Dictionary) -> String:
	var keys: Array = meta.get("party_keys", [])
	var levels: Array = meta.get("party_levels", [])
	if keys.is_empty():
		return "No Digimon in party"

	var parts: Array[String] = []
	for i: int in keys.size():
		var key: StringName = StringName(str(keys[i]))
		var lvl: int = levels[i] if i < levels.size() else 1
		var digimon_data: DigimonData = Atlas.digimon.get(key)
		var display: String = digimon_data.display_name if digimon_data else str(key)
		parts.append("%s Lv.%d" % [display, lvl])
	return ", ".join(parts)
