class_name BattleEvolutionAnimator
extends Node
## Plays in-battle evolution animations using the white flash shader.


signal animation_finished()

const WHITE_FLASH_SHADER := preload("res://ui/shaders/white_flash.gdshader")

var _display: BattlefieldDisplay = null
var _battle: BattleState = null


func initialise(display: BattlefieldDisplay, battle: BattleState) -> void:
	_display = display
	_battle = battle


## Play a standard or de-evolution animation.
func play_evolution(
	side_index: int,
	slot_index: int,
	old_key: StringName,
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

	# Ensure shader material
	var mat: ShaderMaterial = _ensure_shader(sprite)

	# Fade other sprites
	_set_other_sprites_alpha(side_index, slot_index, 0.2)

	# White flash in
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "shader_parameter/whiteness", 1.0, 0.8)
	await tween.finished

	# Swap texture
	_display.update_placeholder(side_index, slot_index)

	# White flash out
	tween = get_tree().create_tween()
	tween.tween_property(mat, "shader_parameter/whiteness", 0.0, 0.8)
	await tween.finished

	# Re-apply shader to potentially new sprite
	sprite = _get_sprite(placeholder)
	if sprite != null and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter(
			"whiteness", 0.0,
		)

	# Restore other sprites
	_set_other_sprites_alpha(side_index, slot_index, 1.0)

	animation_finished.emit()


## Play a jogress evolution animation.
func play_jogress_evolution(
	side_index: int,
	slot_index: int,
	old_key: StringName,
	new_key: StringName,
	consumed_slots: Array[int],
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

	# Collect consumed partner sprites
	var partner_sprites: Array[Control] = []
	for cs: int in consumed_slots:
		var p_placeholder: Node = _display.get_battlefield_placeholder(
			side_index, cs,
		)
		if p_placeholder != null:
			var p_sprite: Control = _get_sprite(p_placeholder)
			if p_sprite != null:
				partner_sprites.append(p_sprite)

	# Fade other sprites (except participants)
	_set_other_sprites_alpha(side_index, slot_index, 0.2, consumed_slots)

	# Flash all participants simultaneously
	var mat: ShaderMaterial = _ensure_shader(sprite)
	var partner_mats: Array[ShaderMaterial] = []
	for ps: Control in partner_sprites:
		partner_mats.append(_ensure_shader(ps))

	var flash_in: Tween = get_tree().create_tween()
	flash_in.tween_property(mat, "shader_parameter/whiteness", 1.0, 0.8)
	for pm: ShaderMaterial in partner_mats:
		flash_in.parallel().tween_property(
			pm, "shader_parameter/whiteness", 1.0, 0.8,
		)
	await flash_in.finished

	# Hide partner sprites, update main sprite
	for ps: Control in partner_sprites:
		ps.visible = false
	_display.update_placeholder(side_index, slot_index)

	# Flash out
	sprite = _get_sprite(placeholder)
	if sprite != null:
		mat = _ensure_shader(sprite)
		var flash_out: Tween = get_tree().create_tween()
		flash_out.tween_property(mat, "shader_parameter/whiteness", 0.0, 0.8)
		await flash_out.finished

	# Restore other sprites
	_set_other_sprites_alpha(side_index, slot_index, 1.0)

	animation_finished.emit()


func _get_sprite(placeholder: Node) -> Control:
	var sprite: Node = placeholder.get_node_or_null("SpriteRect")
	if sprite is Control:
		return sprite as Control
	sprite = placeholder.get_node_or_null("ColorRect")
	if sprite is Control:
		return sprite as Control
	return null


func _ensure_shader(sprite: Control) -> ShaderMaterial:
	if sprite.material is ShaderMaterial:
		return sprite.material as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = WHITE_FLASH_SHADER
	mat.set_shader_parameter("whiteness", 0.0)
	sprite.material = mat
	return mat


func _set_other_sprites_alpha(
	exclude_side: int,
	exclude_slot: int,
	alpha: float,
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
			var placeholder: Node = _display.get_battlefield_placeholder(
				side.side_index, slot.slot_index,
			)
			if placeholder == null:
				continue
			var sprite: Control = _get_sprite(placeholder)
			if sprite != null:
				sprite.modulate.a = alpha
