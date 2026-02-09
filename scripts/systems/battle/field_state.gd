class_name FieldState
extends RefCounted
## Global field state — weather, terrain, and field-wide effects.


## Active weather: { "key": StringName, "duration": int, "setter_side": int } or empty.
var weather: Dictionary = {}

## Active terrain: { "key": StringName, "duration": int, "setter_side": int } or empty.
var terrain: Dictionary = {}

## Active global effects: [{ "key": StringName, "duration": int }]
var global_effects: Array[Dictionary] = []


func set_weather(key: StringName, duration: int, setter_side: int) -> void:
	weather = {"key": key, "duration": duration, "setter_side": setter_side}


func clear_weather() -> void:
	weather = {}


func has_weather(key: StringName = &"") -> bool:
	if weather.is_empty():
		return false
	if key == &"":
		return true
	return weather.get("key", &"") == key


func set_terrain(key: StringName, duration: int, setter_side: int) -> void:
	terrain = {"key": key, "duration": duration, "setter_side": setter_side}


func clear_terrain() -> void:
	terrain = {}


func has_terrain(key: StringName = &"") -> bool:
	if terrain.is_empty():
		return false
	if key == &"":
		return true
	return terrain.get("key", &"") == key


func add_global_effect(key: StringName, duration: int) -> void:
	# Don't duplicate
	for effect: Dictionary in global_effects:
		if effect.get("key", &"") == key:
			effect["duration"] = duration
			return
	global_effects.append({"key": key, "duration": duration})


func remove_global_effect(key: StringName) -> void:
	for i: int in range(global_effects.size() - 1, -1, -1):
		if global_effects[i].get("key", &"") == key:
			global_effects.remove_at(i)
			return


func has_global_effect(key: StringName) -> bool:
	for effect: Dictionary in global_effects:
		if effect.get("key", &"") == key:
			return true
	return false


## Tick all durations down by 1. Remove expired effects.
func tick_durations() -> Dictionary:
	var expired: Dictionary = {"weather": false, "terrain": false, "global_effects": []}

	if not weather.is_empty():
		weather["duration"] = int(weather.get("duration", 0)) - 1
		if int(weather.get("duration", 0)) <= 0:
			expired["weather"] = true
			weather = {}

	if not terrain.is_empty():
		terrain["duration"] = int(terrain.get("duration", 0)) - 1
		if int(terrain.get("duration", 0)) <= 0:
			expired["terrain"] = true
			terrain = {}

	for i: int in range(global_effects.size() - 1, -1, -1):
		global_effects[i]["duration"] = int(global_effects[i].get("duration", 0)) - 1
		if int(global_effects[i].get("duration", 0)) <= 0:
			expired["global_effects"].append(global_effects[i].get("key", &""))
			global_effects.remove_at(i)

	return expired
