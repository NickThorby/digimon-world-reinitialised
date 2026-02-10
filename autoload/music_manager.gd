extends Node
## Global music manager — plays looping background music with crossfade transitions.

const FADE_DURATION: float = 0.5

var _current_path: String = ""
var _player: AudioStreamPlayer = null
var _tween: Tween = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)


func play(stream_path: String) -> void:
	if stream_path == _current_path and _player.playing:
		return

	var stream: AudioStreamMP3 = load(stream_path) as AudioStreamMP3
	if stream == null:
		push_error("MusicManager: Failed to load '%s'" % stream_path)
		return
	stream.loop = true

	if _player.playing:
		_crossfade(stream, stream_path)
	else:
		_current_path = stream_path
		_player.stream = stream
		_player.volume_db = 0.0
		_player.play()


func stop() -> void:
	_kill_tween()
	_player.stop()
	_current_path = ""


func _crossfade(new_stream: AudioStreamMP3, new_path: String) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -40.0, FADE_DURATION)
	_tween.tween_callback(func() -> void:
		_current_path = new_path
		_player.stream = new_stream
		_player.volume_db = -40.0
		_player.play()
	)
	_tween.tween_property(_player, "volume_db", 0.0, FADE_DURATION)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
