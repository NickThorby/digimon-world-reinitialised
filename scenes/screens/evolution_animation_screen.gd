extends Control
## Evolution Animation Screen
##
## Purpose: Cinematic evolution animation with message box dialogue and white-flash
## sprite transition using a shader.
##
## Context inputs (Game.screen_context):
##   old_digimon_key: StringName — original species key (for sprite)
##   new_digimon_key: StringName — evolved species key (for sprite)
##   old_name: String — display name before evolution
##   new_name: String — display name after evolution
##   mode: Registry.GameMode
##   party_index: int
##   storage_box: int
##   storage_slot: int
##   evolution_return_scene: String — the evolution screen's own return_scene

const EVOLUTION_SCREEN_PATH := "res://scenes/screens/evolution_screen.tscn"

const SIZE_SCALES: Dictionary = {
	&"tiny": 0.55,
	&"small": 0.7,
	&"medium": 0.85,
	&"large": 1.0,
	&"huge": 1.15,
	&"gargantuan": 1.3,
}

@onready var _sprite_rect: TextureRect = $MarginContainer/VBox/SpriteCenterContainer/SpriteRect
@onready var _message_box: BattleMessageBox = $MarginContainer/VBox/MessageBox

var _old_digimon_key: StringName = &""
var _new_digimon_key: StringName = &""
var _old_name: String = ""
var _new_name: String = ""
var _mode: Registry.GameMode = Registry.GameMode.TEST
var _party_index: int = -1
var _storage_box: int = -1
var _storage_slot: int = -1
var _evolution_return_scene: String = ""
var _is_transitioning: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	_read_context()
	_setup_sprite()
	MusicManager.play("res://assets/audio/music/38. Digivolution Theme.mp3")
	_run_animation()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_old_digimon_key = StringName(ctx.get("old_digimon_key", ""))
	_new_digimon_key = StringName(ctx.get("new_digimon_key", ""))
	_old_name = ctx.get("old_name", "") as String
	_new_name = ctx.get("new_name", "") as String
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_party_index = ctx.get("party_index", -1) as int
	_storage_box = ctx.get("storage_box", -1) as int
	_storage_slot = ctx.get("storage_slot", -1) as int
	_evolution_return_scene = ctx.get("evolution_return_scene", "") as String


func _setup_sprite() -> void:
	var data: DigimonData = Atlas.digimon.get(_old_digimon_key) as DigimonData
	if data:
		_sprite_rect.texture = data.sprite_texture
		_sprite_rect.flip_h = true
		_apply_sprite_size(data)


func _apply_sprite_size(data: DigimonData) -> void:
	var size_scale: float = SIZE_SCALES.get(data.size_trait, 0.85) as float
	var base_size: float = 256.0
	var scaled: float = base_size * size_scale
	_sprite_rect.custom_minimum_size = Vector2(scaled, scaled)


func _set_whiteness(value: float) -> void:
	var mat: ShaderMaterial = _sprite_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("whiteness", value)


func _run_animation() -> void:
	# Phase 1 — Opening message
	_message_box.visible = true
	var evolving_word: String = Settings.get_evolving_word()
	await _message_box.show_message("%s is %s!" % [_old_name, evolving_word])
	_message_box.visible = false

	# Phase 2 — White transition (sprite turns white via shader)
	_is_transitioning = true

	_active_tween = create_tween()
	_active_tween.tween_method(_set_whiteness, 0.0, 1.0, 1.0)
	await _active_tween.finished

	# Swap sprite to new Digimon while fully white
	var new_data: DigimonData = Atlas.digimon.get(_new_digimon_key) as DigimonData
	if new_data:
		_sprite_rect.texture = new_data.sprite_texture
		_sprite_rect.flip_h = true
		_apply_sprite_size(new_data)

	_active_tween = create_tween()
	_active_tween.tween_method(_set_whiteness, 1.0, 0.0, 1.0)
	await _active_tween.finished

	_is_transitioning = false
	_active_tween = null

	# Phase 3 — Completion message
	_message_box.visible = true
	var evolved_word: String = Settings.get_evolved_word()
	await _message_box.show_message(
		"%s %s to %s!" % [_old_name, evolved_word, _new_name],
	)
	_message_box.visible = false

	# Phase 4 — Return to evolution screen
	_navigate_back()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_transitioning:
		return

	var skip: bool = false
	if event.is_action_pressed("ui_accept"):
		skip = true
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			skip = true

	if skip:
		_skip_transition()
		get_viewport().set_input_as_handled()


func _skip_transition() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null

	# Set final state: new sprite visible, shader reset
	_set_whiteness(0.0)
	var new_data: DigimonData = Atlas.digimon.get(_new_digimon_key) as DigimonData
	if new_data:
		_sprite_rect.texture = new_data.sprite_texture
		_sprite_rect.flip_h = true
		_apply_sprite_size(new_data)

	_is_transitioning = false

	# Phase 3 — Completion message
	_message_box.visible = true
	var evolved_word: String = Settings.get_evolved_word()
	_message_box.show_message(
		"%s %s to %s!" % [_old_name, evolved_word, _new_name],
	)
	await _message_box.message_completed
	_message_box.visible = false

	# Phase 4 — Return
	_navigate_back()


func _navigate_back() -> void:
	Game.screen_context = {
		"from_evolution_animation": true,
		"mode": _mode,
		"party_index": _party_index,
		"storage_box": _storage_box,
		"storage_slot": _storage_slot,
		"return_scene": _evolution_return_scene,
	}
	SceneManager.change_scene(EVOLUTION_SCREEN_PATH)
