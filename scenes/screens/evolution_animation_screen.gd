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
##   is_jogress: bool — (optional) true for jogress multi-sprite animation
##   participant_keys: Array[StringName] — (optional) species keys for jogress sprites

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
var _is_jogress: bool = false
var _participant_keys: Array[StringName] = []
var _jogress_sprites: Array[TextureRect] = []


func _ready() -> void:
	_read_context()
	MusicManager.play("res://assets/audio/music/38. Digivolution Theme.mp3")
	if _is_jogress:
		_setup_jogress_sprites()
		_run_jogress_animation()
	else:
		_setup_sprite()
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
	_is_jogress = ctx.get("is_jogress", false) as bool
	for pk: Variant in ctx.get("participant_keys", []):
		_participant_keys.append(StringName(str(pk)))


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


func _setup_jogress_sprites() -> void:
	_sprite_rect.visible = false
	var container: CenterContainer = _sprite_rect.get_parent() as CenterContainer
	var shader_res: Shader = load("res://ui/shaders/white_flash.gdshader") as Shader

	# Create a Control to hold jogress sprites with manual positioning
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(holder)

	var count: int = _participant_keys.size()
	var base_size: float = 256.0
	var spacing: float = base_size * 0.8

	for i: int in count:
		var key: StringName = _participant_keys[i]
		var data: DigimonData = Atlas.digimon.get(key) as DigimonData
		var tex_rect := TextureRect.new()

		# Each sprite gets its own ShaderMaterial instance
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("whiteness", 0.0)
		tex_rect.material = mat

		if data:
			tex_rect.texture = data.sprite_texture
			tex_rect.flip_h = true
			var size_scale: float = SIZE_SCALES.get(data.size_trait, 0.85) as float
			var scaled: float = base_size * size_scale
			tex_rect.custom_minimum_size = Vector2(scaled, scaled)
		else:
			tex_rect.custom_minimum_size = Vector2(base_size, base_size)

		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Position sprites spread horizontally from centre
		var offset_x: float = (float(i) - float(count - 1) / 2.0) * spacing
		tex_rect.position = Vector2(offset_x, 0)
		tex_rect.set_anchors_preset(Control.PRESET_CENTER)

		holder.add_child(tex_rect)
		_jogress_sprites.append(tex_rect)


func _set_jogress_whiteness(value: float) -> void:
	for sprite: TextureRect in _jogress_sprites:
		var mat: ShaderMaterial = sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("whiteness", value)


func _run_jogress_animation() -> void:
	# Phase 1 — Opening message
	_message_box.visible = true
	var evolving_word: String = Settings.get_evolving_word()

	# Build participant names
	var names: Array[String] = []
	for key: StringName in _participant_keys:
		var data: DigimonData = Atlas.digimon.get(key) as DigimonData
		names.append(data.display_name if data else str(key))

	var names_text: String = ""
	if names.size() == 1:
		names_text = names[0]
	elif names.size() == 2:
		names_text = "%s and %s" % [names[0], names[1]]
	else:
		names_text = ", ".join(names.slice(0, -1)) + ", and " + names[-1]

	await _message_box.show_message("%s are %s!" % [names_text, evolving_word])
	_message_box.visible = false

	# Phase 2 — White transition (all sprites turn white)
	_is_transitioning = true

	_active_tween = create_tween()
	_active_tween.tween_method(_set_jogress_whiteness, 0.0, 1.0, 1.0)
	await _active_tween.finished

	# Phase 3 — Slide all sprites to centre
	_active_tween = create_tween()
	for sprite: TextureRect in _jogress_sprites:
		_active_tween.parallel().tween_property(
			sprite, "position", Vector2.ZERO, 0.8,
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await _active_tween.finished

	# Phase 4 — Swap: hide jogress sprites, show result sprite
	for sprite: TextureRect in _jogress_sprites:
		sprite.visible = false

	_sprite_rect.visible = true
	var new_data: DigimonData = Atlas.digimon.get(_new_digimon_key) as DigimonData
	if new_data:
		_sprite_rect.texture = new_data.sprite_texture
		_sprite_rect.flip_h = true
		_apply_sprite_size(new_data)
	_set_whiteness(1.0)

	# Phase 5 — Reveal result (fade from white)
	_active_tween = create_tween()
	_active_tween.tween_method(_set_whiteness, 1.0, 0.0, 1.0)
	await _active_tween.finished

	_is_transitioning = false
	_active_tween = null

	# Phase 6 — Completion message
	_message_box.visible = true
	var evolved_word: String = Settings.get_evolved_word()
	await _message_box.show_message(
		"%s %s to %s!" % [_old_name, evolved_word, _new_name],
	)
	_message_box.visible = false

	# Phase 7 — Return
	_navigate_back()


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

	# Hide jogress sprites if present
	if _is_jogress:
		for sprite: TextureRect in _jogress_sprites:
			sprite.visible = false
		_set_jogress_whiteness(0.0)
		_sprite_rect.visible = true

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
