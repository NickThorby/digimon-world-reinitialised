class_name BattleEvolutionAnimator
extends Node
## Plays in-battle evolution animations: fades HUD/other sprites, floats the
## evolving Digimon to screen centre, plays a white-flash texture swap, then
## floats back and fades everything in. Jogress partners converge at centre.


signal animation_finished()

const WHITE_FLASH_SHADER := preload("res://ui/shaders/white_flash.gdshader")

## Size-trait → scale multiplier (matches BattlefieldDisplay).
const SIZE_SCALES: Dictionary = {
	&"tiny": 0.55, &"small": 0.7, &"medium": 0.85,
	&"large": 1.0, &"huge": 1.15, &"gargantuan": 1.3,
}

var _display: BattlefieldDisplay = null
var _battle: BattleState = null
var _hud: Node = null
var _animation_layer: CanvasLayer = null


func initialise(
	display: BattlefieldDisplay,
	battle: BattleState,
	hud: Node = null,
) -> void:
	_display = display
	_battle = battle
	_hud = hud


## Play a standard or de-evolution animation.
func play_evolution(
	side_index: int,
	slot_index: int,
	_old_key: StringName,
	new_key: StringName,
) -> void:
	if _display == null:
		animation_finished.emit()
		return

	var placeholder: Node = _display.get_battlefield_placeholder(
		side_index, slot_index,
	)
	if placeholder == null:
		animation_finished.emit()
		return

	var sprite: Control = _get_sprite(placeholder)
	if sprite == null:
		animation_finished.emit()
		return

	var is_ally: bool = _battle.are_allies(0, side_index)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var centre: Vector2 = vp_size / 2.0

	# Get original sprite info
	var original_pos: Vector2 = sprite.global_position
	var sprite_size: Vector2 = sprite.size
	var original_flip: bool = false
	if sprite is TextureRect:
		original_flip = (sprite as TextureRect).flip_h

	# Create temp sprite in an overlay layer
	var temp: TextureRect = _create_temp_from_sprite(
		sprite, original_pos, sprite_size,
	)
	sprite.modulate.a = 0.0

	# Step 1: Fade out HUD + other sprites
	var fade_out: Tween = get_tree().create_tween()
	_tween_hud_alpha(fade_out, 0.0, 0.3)
	_tween_all_sprites_alpha(
		fade_out, 0.0, 0.3, side_index, slot_index,
	)
	await fade_out.finished

	# Step 2: Float to centre
	var target_pos: Vector2 = centre - sprite_size / 2.0
	var float_in: Tween = get_tree().create_tween()
	float_in.tween_property(temp, "position", target_pos, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await float_in.finished

	# Step 3: Flip for viewer (allies face right normally, flip to face left)
	if is_ally:
		temp.flip_h = true

	# Step 4: White flash in
	var mat: ShaderMaterial = _ensure_shader(temp)
	var flash_in: Tween = get_tree().create_tween()
	flash_in.tween_property(mat, "shader_parameter/whiteness", 1.0, 1.0)
	await flash_in.finished

	# Step 5: Swap texture
	var new_data: DigimonData = Atlas.digimon.get(new_key) as DigimonData
	if new_data != null and new_data.sprite_texture != null:
		temp.texture = new_data.sprite_texture
		var scale: float = SIZE_SCALES.get(
			new_data.size_trait, 0.85,
		) as float
		var new_size: Vector2 = Vector2(64.0, 64.0) * scale
		temp.custom_minimum_size = new_size
		temp.size = new_size
		temp.position = centre - new_size / 2.0
		sprite_size = new_size
	_display.update_placeholder(side_index, slot_index)

	# Step 6: White flash out
	var flash_out: Tween = get_tree().create_tween()
	flash_out.tween_property(mat, "shader_parameter/whiteness", 0.0, 1.0)
	await flash_out.finished

	# Step 7: Restore flip for float-back
	temp.flip_h = not is_ally

	# Step 8: Float back to original position
	var updated_sprite: Control = _get_sprite(placeholder)
	var back_pos: Vector2 = original_pos
	if updated_sprite != null:
		back_pos = updated_sprite.global_position
	var float_back: Tween = get_tree().create_tween()
	float_back.tween_property(temp, "position", back_pos, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await float_back.finished

	# Step 9: Show updated original, clean up temp
	if updated_sprite != null:
		updated_sprite.modulate.a = 1.0
		if updated_sprite.material is ShaderMaterial:
			(updated_sprite.material as ShaderMaterial).set_shader_parameter(
				"whiteness", 0.0,
			)
	temp.queue_free()

	# Step 10: Fade in HUD + other sprites
	var fade_in: Tween = get_tree().create_tween()
	_tween_hud_alpha(fade_in, 1.0, 0.3)
	_tween_all_sprites_alpha(
		fade_in, 1.0, 0.3, side_index, slot_index,
	)
	await fade_in.finished

	# Ensure original sprite is fully visible
	if updated_sprite != null:
		updated_sprite.modulate.a = 1.0
	_cleanup_animation_layer()
	animation_finished.emit()


## Play a jogress evolution animation.
func play_jogress_evolution(
	side_index: int,
	slot_index: int,
	_old_key: StringName,
	new_key: StringName,
	consumed_slots: Array[int],
	reserve_partner_keys: Array[StringName] = [],
) -> void:
	if _display == null:
		animation_finished.emit()
		return

	var placeholder: Node = _display.get_battlefield_placeholder(
		side_index, slot_index,
	)
	if placeholder == null:
		animation_finished.emit()
		return

	var sprite: Control = _get_sprite(placeholder)
	if sprite == null:
		animation_finished.emit()
		return

	var is_ally: bool = _battle.are_allies(0, side_index)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var centre: Vector2 = vp_size / 2.0

	# Get original sprite info
	var original_pos: Vector2 = sprite.global_position
	var sprite_size: Vector2 = sprite.size

	# Create temp for main evolving Digimon
	var temp_main: TextureRect = _create_temp_from_sprite(
		sprite, original_pos, sprite_size,
	)
	sprite.modulate.a = 0.0

	# Create temps for on-field consumed partners
	var temp_partners: Array[TextureRect] = []
	var partner_original_positions: Array[Vector2] = []
	for cs: int in consumed_slots:
		var p_ph: Node = _display.get_battlefield_placeholder(
			side_index, cs,
		)
		if p_ph == null:
			continue
		var p_sprite: Control = _get_sprite(p_ph)
		if p_sprite == null:
			continue
		var p_pos: Vector2 = p_sprite.global_position
		var p_size: Vector2 = p_sprite.size
		var p_temp: TextureRect = _create_temp_from_sprite(
			p_sprite, p_pos, p_size,
		)
		temp_partners.append(p_temp)
		partner_original_positions.append(p_pos)
		p_sprite.modulate.a = 0.0

	# Create temps for off-field (reserve) partners
	var off_screen_x: float = -80.0 if is_ally else vp_size.x + 10.0
	for rk: StringName in reserve_partner_keys:
		var p_data: DigimonData = Atlas.digimon.get(rk) as DigimonData
		if p_data == null or p_data.sprite_texture == null:
			continue
		var scale: float = SIZE_SCALES.get(
			p_data.size_trait, 0.85,
		) as float
		var p_size: Vector2 = Vector2(64.0, 64.0) * scale
		var start_pos: Vector2 = Vector2(
			off_screen_x, centre.y - p_size.y / 2.0,
		)
		var p_temp: TextureRect = _create_temp_sprite(
			p_data.sprite_texture, start_pos, p_size, not is_ally,
		)
		temp_partners.append(p_temp)
		partner_original_positions.append(start_pos)

	# Step 1: Fade out HUD + other sprites (exclude main + consumed)
	var fade_out: Tween = get_tree().create_tween()
	_tween_hud_alpha(fade_out, 0.0, 0.3)
	_tween_all_sprites_alpha(
		fade_out, 0.0, 0.3, side_index, slot_index, consumed_slots,
	)
	await fade_out.finished

	# Step 2: Float all participants to centre
	var target_pos: Vector2 = centre - sprite_size / 2.0
	var converge: Tween = get_tree().create_tween()
	converge.tween_property(temp_main, "position", target_pos, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	for p_temp: TextureRect in temp_partners:
		var p_target: Vector2 = centre - p_temp.size / 2.0
		converge.parallel().tween_property(
			p_temp, "position", p_target, 0.5,
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await converge.finished

	# Step 3: Flip all for viewer
	if is_ally:
		temp_main.flip_h = true
		for p_temp: TextureRect in temp_partners:
			p_temp.flip_h = true

	# Step 4: White flash in — all simultaneously
	var mat_main: ShaderMaterial = _ensure_shader(temp_main)
	var partner_mats: Array[ShaderMaterial] = []
	for p_temp: TextureRect in temp_partners:
		partner_mats.append(_ensure_shader(p_temp))

	var flash_in: Tween = get_tree().create_tween()
	flash_in.tween_property(
		mat_main, "shader_parameter/whiteness", 1.0, 1.0,
	)
	for pm: ShaderMaterial in partner_mats:
		flash_in.parallel().tween_property(
			pm, "shader_parameter/whiteness", 1.0, 1.0,
		)
	await flash_in.finished

	# Step 5: Hide partners, swap main texture to result
	for p_temp: TextureRect in temp_partners:
		p_temp.visible = false

	var new_data: DigimonData = Atlas.digimon.get(new_key) as DigimonData
	if new_data != null and new_data.sprite_texture != null:
		temp_main.texture = new_data.sprite_texture
		var scale: float = SIZE_SCALES.get(
			new_data.size_trait, 0.85,
		) as float
		var new_size: Vector2 = Vector2(64.0, 64.0) * scale
		temp_main.custom_minimum_size = new_size
		temp_main.size = new_size
		temp_main.position = centre - new_size / 2.0
	_display.update_placeholder(side_index, slot_index)

	# Step 6: White flash out
	var flash_out: Tween = get_tree().create_tween()
	flash_out.tween_property(
		mat_main, "shader_parameter/whiteness", 0.0, 1.0,
	)
	await flash_out.finished

	# Step 7: Restore flip for float-back
	temp_main.flip_h = not is_ally

	# Step 8: Float result back to main slot position
	var updated_sprite: Control = _get_sprite(placeholder)
	var back_pos: Vector2 = original_pos
	if updated_sprite != null:
		back_pos = updated_sprite.global_position
	var float_back: Tween = get_tree().create_tween()
	float_back.tween_property(temp_main, "position", back_pos, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await float_back.finished

	# Step 9: Show updated original, clean up temps
	if updated_sprite != null:
		updated_sprite.modulate.a = 1.0
		if updated_sprite.material is ShaderMaterial:
			(updated_sprite.material as ShaderMaterial).set_shader_parameter(
				"whiteness", 0.0,
			)
	temp_main.queue_free()
	for p_temp: TextureRect in temp_partners:
		if is_instance_valid(p_temp):
			p_temp.queue_free()

	# Hide consumed slot sprites (they were absorbed)
	for cs: int in consumed_slots:
		var cs_ph: Node = _display.get_battlefield_placeholder(
			side_index, cs,
		)
		if cs_ph != null:
			var cs_sprite: Control = _get_sprite(cs_ph)
			if cs_sprite != null:
				cs_sprite.modulate.a = 0.0

	# Step 10: Fade in HUD + other sprites
	var fade_in: Tween = get_tree().create_tween()
	_tween_hud_alpha(fade_in, 1.0, 0.3)
	_tween_all_sprites_alpha(
		fade_in, 1.0, 0.3, side_index, slot_index, consumed_slots,
	)
	await fade_in.finished

	# Ensure result sprite is visible
	if updated_sprite != null:
		updated_sprite.modulate.a = 1.0
	_cleanup_animation_layer()
	animation_finished.emit()


## --- Helpers ---


func _get_sprite(placeholder: Node) -> Control:
	var node: Node = placeholder.get_node_or_null("SpriteRect")
	if node is Control:
		return node as Control
	node = placeholder.get_node_or_null("ColorRect")
	if node is Control:
		return node as Control
	return null


func _ensure_shader(sprite: Control) -> ShaderMaterial:
	if sprite.material is ShaderMaterial:
		return sprite.material as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = WHITE_FLASH_SHADER
	mat.set_shader_parameter("whiteness", 0.0)
	sprite.material = mat
	return mat


func _get_or_create_layer() -> CanvasLayer:
	if _animation_layer != null and is_instance_valid(_animation_layer):
		return _animation_layer
	_animation_layer = CanvasLayer.new()
	_animation_layer.layer = 50
	add_child(_animation_layer)
	return _animation_layer


func _cleanup_animation_layer() -> void:
	if _animation_layer != null and is_instance_valid(_animation_layer):
		_animation_layer.queue_free()
		_animation_layer = null


## Create a temp TextureRect from an existing on-field sprite.
func _create_temp_from_sprite(
	source: Control,
	global_pos: Vector2,
	size: Vector2,
) -> TextureRect:
	var layer: CanvasLayer = _get_or_create_layer()
	var tex_rect := TextureRect.new()
	if source is TextureRect:
		var src: TextureRect = source as TextureRect
		tex_rect.texture = src.texture
		tex_rect.flip_h = src.flip_h
	tex_rect.custom_minimum_size = size
	tex_rect.size = size
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.position = global_pos
	layer.add_child(tex_rect)
	return tex_rect


## Create a temp TextureRect from a texture (for off-field partners).
func _create_temp_sprite(
	texture: Texture2D,
	pos: Vector2,
	size: Vector2,
	flip_h: bool,
) -> TextureRect:
	var layer: CanvasLayer = _get_or_create_layer()
	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.flip_h = flip_h
	tex_rect.custom_minimum_size = size
	tex_rect.size = size
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.position = pos
	layer.add_child(tex_rect)
	return tex_rect


## Tween all HUD children's modulate alpha.
func _tween_hud_alpha(
	tween: Tween,
	target_alpha: float,
	duration: float,
) -> void:
	if _hud == null:
		return
	for child: Node in _hud.get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(
				child as CanvasItem, "modulate:a",
				target_alpha, duration,
			)


## Tween all battlefield sprite alphas, optionally excluding specific slots.
func _tween_all_sprites_alpha(
	tween: Tween,
	target_alpha: float,
	duration: float,
	exclude_side: int = -1,
	exclude_slot: int = -1,
	also_exclude_slots: Array[int] = [],
) -> void:
	if _battle == null or _display == null:
		return
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			if side.side_index == exclude_side and (
				slot.slot_index == exclude_slot
				or slot.slot_index in also_exclude_slots
			):
				continue
			var ph: Node = _display.get_battlefield_placeholder(
				side.side_index, slot.slot_index,
			)
			if ph == null:
				continue
			var sp: Control = _get_sprite(ph)
			if sp != null:
				tween.parallel().tween_property(
					sp, "modulate:a", target_alpha, duration,
				)
