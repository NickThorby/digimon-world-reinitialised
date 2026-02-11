class_name BattlefieldDisplay
extends Node
## Manages battlefield sprite placeholders, positioning, hover/active bounces,
## targeting indicators, and digimon panel updates.


const DIGIMON_PANEL_SCENE := preload("res://ui/battle_hud/digimon_panel.tscn")

## Animation config for when a status is first applied (afflicted).
## Each entry has a colour (modulate tint) and movement type.
const STATUS_AFFLICTED_ANIMS: Dictionary = {
	&"poisoned": {"colour": Color(0.7, 0.3, 1.2), "movement": &"none"},
	&"badly_poisoned": {"colour": Color(0.7, 0.3, 1.2), "movement": &"none"},
	&"burned": {"colour": Color(1.4, 0.6, 0.2), "movement": &"none"},
	&"badly_burned": {"colour": Color(1.4, 0.6, 0.2), "movement": &"none"},
	&"frostbitten": {"colour": Color(0.5, 0.85, 1.4), "movement": &"none"},
	&"frozen": {"colour": Color(0.5, 0.85, 1.4), "movement": &"none"},
	&"paralysed": {"colour": Color(1.3, 1.2, 0.3), "movement": &"shake"},
	&"asleep": {"colour": Color(0.6, 0.6, 1.0), "movement": &"droop"},
	&"confused": {"colour": Color(1.0, 0.6, 0.9), "movement": &"shake"},
	&"flinched": {"colour": Color(1.3, 1.1, 0.3), "movement": &"shake"},
	&"bleeding": {"colour": Color(1.2, 0.15, 0.15), "movement": &"shake"},
	&"perishing": {"colour": Color(0.2, 0.2, 0.2), "movement": &"pulse"},
	&"exhausted": {"colour": Color(0.6, 0.5, 0.4), "movement": &"droop"},
	&"seeded": {"colour": Color(0.4, 1.0, 0.3), "movement": &"none"},
	&"dazed": {"colour": Color(1.0, 1.0, 0.5), "movement": &"none"},
	&"blinded": {"colour": Color(0.3, 0.3, 0.3), "movement": &"none"},
	&"trapped": {"colour": Color(0.8, 0.5, 0.2), "movement": &"none"},
	&"taunted": {"colour": Color(1.3, 0.4, 0.4), "movement": &"none"},
	&"disabled": {"colour": Color(0.5, 0.5, 0.5), "movement": &"none"},
	&"encored": {"colour": Color(1.0, 0.7, 1.2), "movement": &"none"},
	&"nullified": {"colour": Color(0.4, 0.4, 0.4), "movement": &"flicker"},
	&"reversed": {"colour": Color(0.9, 0.3, 1.2), "movement": &"none"},
	&"regenerating": {"colour": Color(0.4, 1.2, 0.5), "movement": &"none"},
	&"vitalised": {"colour": Color(0.5, 1.0, 1.3), "movement": &"none"},
}

## Animation config for DOT tick damage. Keyed by source_label from damage_dealt.
const STATUS_HURT_ANIMS: Dictionary = {
	&"burn": Color(1.4, 0.6, 0.2),
	&"frostbite": Color(0.5, 0.85, 1.4),
	&"poison": Color(0.7, 0.3, 1.2),
	&"seeded": Color(0.4, 1.0, 0.3),
	&"bleeding": Color(1.2, 0.15, 0.15),
	&"perishing": Color(0.2, 0.2, 0.2),
}

var _vfx: BattleVFX = BattleVFX.new()
var _battle: BattleState = null
var _near_side: HBoxContainer = null
var _far_side: HBoxContainer = null
var _ally_panels: HBoxContainer = null
var _foe_panels: HBoxContainer = null

# Panel maps: "side_slot" -> DigimonPanel
var _ally_panel_map: Dictionary = {}
var _foe_panel_map: Dictionary = {}

# Hover bounce tweens: "side_slot" -> Tween
var _hover_tweens: Dictionary = {}

# Active digimon bounce
var _active_bounce_tween: Tween = null
var _active_bounce_panel_tween: Tween = null
var _active_bounce_key: String = ""
var _active_panel_origin_y: float = 0.0

# Sprite-based targeting
var _target_indicators: Array[TargetIndicator] = []
var _valid_target_map: Dictionary = {}
var _is_targeting: bool = false

# Targeting callback
var _on_target_click: Callable = Callable()

# Phase reference (to block hover during execution)
var phase_ref: Callable = Callable()


func initialise(
	battle: BattleState,
	near_side: HBoxContainer,
	far_side: HBoxContainer,
	ally_panels: HBoxContainer,
	foe_panels: HBoxContainer,
) -> void:
	_battle = battle
	_near_side = near_side
	_far_side = far_side
	_ally_panels = ally_panels
	_foe_panels = foe_panels


## --- Panel Management ---


func setup_digimon_panels() -> void:
	for child: Node in _ally_panels.get_children():
		child.queue_free()
	for child: Node in _foe_panels.get_children():
		child.queue_free()

	_ally_panel_map.clear()
	_foe_panel_map.clear()

	for side: SideState in _battle.sides:
		var is_ally: bool = _battle.are_allies(0, side.side_index)
		for slot: SlotState in side.slots:
			var panel: DigimonPanel = DIGIMON_PANEL_SCENE.instantiate() as DigimonPanel
			var key: String = "%d_%d" % [side.side_index, slot.slot_index]

			if is_ally:
				_ally_panels.add_child(panel)
				_ally_panel_map[key] = panel
			else:
				_foe_panels.add_child(panel)
				_foe_panel_map[key] = panel


func update_all_panels() -> void:
	for side: SideState in _battle.sides:
		for slot: SlotState in side.slots:
			update_panel(side.side_index, slot.slot_index)


func update_panel_from_snapshot(
	side_index: int, slot_index: int, snapshot: Dictionary
) -> void:
	var panel: DigimonPanel = get_panel(side_index, slot_index)
	if panel == null:
		return

	if snapshot.is_empty():
		var digimon: BattleDigimonState = _battle.get_digimon_at(
			side_index, slot_index,
		)
		panel.update_from_battle_digimon(digimon)
	else:
		panel.update_from_snapshot(snapshot)


func update_panel(side_index: int, slot_index: int) -> void:
	var panel: DigimonPanel = get_panel(side_index, slot_index)
	if panel == null:
		return

	var digimon: BattleDigimonState = _battle.get_digimon_at(
		side_index, slot_index,
	)
	panel.modulate.a = 1.0 if digimon != null else 0.0
	panel.update_from_battle_digimon(digimon)


func set_panel_visible(side_index: int, slot_index: int, is_visible: bool) -> void:
	var panel: DigimonPanel = get_panel(side_index, slot_index)
	if panel != null:
		panel.modulate.a = 1.0 if is_visible else 0.0


func get_panel(side_index: int, slot_index: int) -> DigimonPanel:
	var key: String = "%d_%d" % [side_index, slot_index]
	if _ally_panel_map.has(key):
		return _ally_panel_map[key] as DigimonPanel
	if _foe_panel_map.has(key):
		return _foe_panel_map[key] as DigimonPanel
	return null


## --- Battlefield Placeholders ---


func position_battlefield(scene: Node2D) -> void:
	var vp_size: Vector2 = scene.get_viewport_rect().size
	_far_side.position = Vector2(vp_size.x * 0.50, vp_size.y * 0.18)
	_far_side.size = Vector2(vp_size.x * 0.35, vp_size.y * 0.25)
	_near_side.position = Vector2(vp_size.x * 0.08, vp_size.y * 0.38)
	_near_side.size = Vector2(vp_size.x * 0.35, vp_size.y * 0.25)


func setup_battlefield_placeholders() -> void:
	for child: Node in _near_side.get_children():
		child.queue_free()
	for child: Node in _far_side.get_children():
		child.queue_free()

	for side: SideState in _battle.sides:
		var is_ally: bool = _battle.are_allies(0, side.side_index)
		var container: HBoxContainer = _near_side if is_ally else _far_side
		var is_multi: bool = side.slots.size() > 1

		if is_multi:
			container.add_theme_constant_override("separation", 4)

		for slot: SlotState in side.slots:
			var vbox := VBoxContainer.new()
			var min_w: float = 64.0 if is_multi else 80.0
			vbox.custom_minimum_size = Vector2(min_w, 80)
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			# Size trait → scale multiplier
			var size_scale: float = 0.85  # Default to medium
			if slot.digimon != null and slot.digimon.data != null:
				match slot.digimon.data.size_trait:
					&"tiny": size_scale = 0.55
					&"small": size_scale = 0.7
					&"medium": size_scale = 0.85
					&"large": size_scale = 1.0
					&"huge": size_scale = 1.15
					&"gargantuan": size_scale = 1.3

			var base_size: float = 64.0
			var scaled_size: Vector2 = Vector2(
				base_size, base_size,
			) * size_scale

			var sprite_added: bool = false
			if slot.digimon != null and slot.digimon.data != null:
				var sprite_tex: Texture2D = null
				if "sprite_texture" in slot.digimon.data:
					sprite_tex = slot.digimon.data.sprite_texture
				if sprite_tex != null:
					var tex_rect := TextureRect.new()
					tex_rect.texture = sprite_tex
					tex_rect.custom_minimum_size = scaled_size
					tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
					tex_rect.expand_mode = \
						TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					tex_rect.stretch_mode = \
						TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex_rect.flip_h = not is_ally
					tex_rect.name = "SpriteRect"
					vbox.add_child(tex_rect)
					sprite_added = true

			if not sprite_added:
				var rect := ColorRect.new()
				rect.custom_minimum_size = scaled_size
				rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
				rect.color = Color(0.3, 0.7, 0.3) if is_ally \
					else Color(0.7, 0.3, 0.3)
				rect.name = "ColorRect"
				vbox.add_child(rect)

			vbox.name = "Slot_%d_%d" % [side.side_index, slot.slot_index]

			vbox.mouse_filter = Control.MOUSE_FILTER_STOP
			var si: int = side.side_index
			var sli: int = slot.slot_index
			vbox.mouse_entered.connect(
				_on_sprite_mouse_entered.bind(si, sli),
			)
			vbox.mouse_exited.connect(
				_on_sprite_mouse_exited.bind(si, sli),
			)
			vbox.gui_input.connect(
				_on_sprite_gui_input.bind(si, sli),
			)

			container.add_child(vbox)


func update_placeholder(side_index: int, slot_index: int) -> void:
	var is_ally: bool = _battle.are_allies(0, side_index)
	var container: HBoxContainer = _near_side if is_ally else _far_side
	var node_name: String = "Slot_%d_%d" % [side_index, slot_index]

	var vbox: Node = container.get_node_or_null(node_name)
	if vbox == null:
		return

	var digimon: BattleDigimonState = _battle.get_digimon_at(
		side_index, slot_index,
	)
	if digimon == null or digimon.data == null:
		return

	var old_sprite: Node = vbox.get_node_or_null("SpriteRect")
	var old_color: Node = vbox.get_node_or_null("ColorRect")

	var sprite_tex: Texture2D = null
	if "sprite_texture" in digimon.data:
		sprite_tex = digimon.data.sprite_texture

	if sprite_tex != null:
		if old_sprite is TextureRect:
			(old_sprite as TextureRect).texture = sprite_tex
			(old_sprite as TextureRect).flip_h = not is_ally
		elif old_color != null:
			old_color.queue_free()
			var tex_rect := TextureRect.new()
			tex_rect.texture = sprite_tex
			tex_rect.custom_minimum_size = Vector2(64, 64)
			tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.flip_h = not is_ally
			tex_rect.name = "SpriteRect"
			vbox.add_child(tex_rect)
			vbox.move_child(tex_rect, 0)


func get_battlefield_placeholder(
	side_index: int, slot_index: int
) -> Node:
	var is_ally: bool = _battle.are_allies(0, side_index)
	var container: HBoxContainer = _near_side if is_ally else _far_side
	var node_name: String = "Slot_%d_%d" % [side_index, slot_index]
	return container.get_node_or_null(node_name)


## --- Animations ---


func play_attack_animation(
	user_side: int,
	user_slot: int,
	technique_class: Registry.TechniqueClass,
	element_key: StringName = &"",
	target_side: int = -1,
	target_slot: int = -1,
) -> float:
	var placeholder: Node = get_battlefield_placeholder(user_side, user_slot)
	if placeholder == null:
		return 0.0

	var target_placeholder: Control = null
	if target_side >= 0 and target_slot >= 0:
		var t_node: Node = get_battlefield_placeholder(target_side, target_slot)
		if t_node is Control:
			target_placeholder = _get_sprite_child(t_node)
			if target_placeholder == null:
				target_placeholder = t_node as Control

	match technique_class:
		Registry.TechniqueClass.PHYSICAL:
			return _anim_physical_lunge(placeholder, element_key)
		Registry.TechniqueClass.SPECIAL:
			return _anim_special_flash(
				placeholder, element_key, target_placeholder,
			)
		Registry.TechniqueClass.STATUS:
			return _anim_status_tint(
				placeholder, element_key, target_placeholder,
			)
	return 0.0


func _anim_physical_lunge(
	placeholder: Node, element_key: StringName = &"",
) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var original_pos: Vector2 = ctrl.position
	var is_ally: bool = ctrl.get_parent() == _near_side
	var offset: Vector2 = Vector2(0, -20) if is_ally else Vector2(0, 20)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "position", original_pos + offset, 0.1)
	tween.tween_property(ctrl, "position", original_pos, 0.2)

	# Spawn element burst at user sprite
	if element_key != &"":
		var sprite: Control = _get_sprite_child(ctrl)
		if sprite != null:
			_vfx.spawn_burst(sprite, element_key)

	return 0.3


func _anim_special_flash(
	placeholder: Node,
	element_key: StringName = &"",
	target_ctrl: Control = null,
) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control

	# Element-tinted flash instead of plain white
	var flash_colour: Color = Color(2.0, 2.0, 2.0)
	if element_key != &"":
		var elem_col: Color = Registry.ELEMENT_COLOURS.get(
			element_key, Color.WHITE,
		) as Color
		flash_colour = Color(
			1.0 + elem_col.r, 1.0 + elem_col.g, 1.0 + elem_col.b,
		)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "modulate", flash_colour, 0.1)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.3)

	# Spawn projectile from user to target
	var duration: float = 0.4
	if element_key != &"" and target_ctrl != null:
		var user_sprite: Control = _get_sprite_child(ctrl)
		if user_sprite == null:
			user_sprite = ctrl
		var travel: float = _vfx.spawn_projectile(
			get_tree().current_scene, user_sprite, target_ctrl, element_key,
		)
		if travel > duration:
			duration = travel + 0.1

	return duration


func _anim_status_tint(
	placeholder: Node,
	element_key: StringName = &"",
	target_ctrl: Control = null,
) -> float:
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control

	# Element-tinted glow instead of generic yellow
	var tint_colour: Color = Color(1.2, 1.2, 0.4)
	if element_key != &"":
		var elem_col: Color = Registry.ELEMENT_COLOURS.get(
			element_key, Color.WHITE,
		) as Color
		tint_colour = Color(
			0.8 + elem_col.r * 0.4, 0.8 + elem_col.g * 0.4,
			0.8 + elem_col.b * 0.4,
		)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "modulate", tint_colour, 0.1)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.2)

	# Gentle particles drifting from user to target
	var duration: float = 0.3
	if element_key != &"" and target_ctrl != null:
		var user_sprite: Control = _get_sprite_child(ctrl)
		if user_sprite == null:
			user_sprite = ctrl
		var travel: float = _vfx.spawn_status_particles(
			get_tree().current_scene, user_sprite, target_ctrl, element_key,
		)
		if travel > duration:
			duration = travel + 0.1

	return duration


func anim_hit(side_index: int, slot_index: int) -> float:
	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "modulate", Color(1.4, 0.3, 0.3), 0.05)
	tween.tween_property(ctrl, "position", origin + Vector2(6, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(-6, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(4, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(-4, 0), 0.04)
	tween.tween_property(ctrl, "position", origin, 0.04)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.1)
	return 0.3


func anim_status_afflicted(
	side_index: int, slot_index: int, status_key: StringName,
) -> float:
	if not STATUS_AFFLICTED_ANIMS.has(status_key):
		return 0.0
	var config: Dictionary = STATUS_AFFLICTED_ANIMS[status_key] as Dictionary
	var colour: Color = config["colour"] as Color
	var movement: StringName = config["movement"] as StringName

	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = get_tree().create_tween()

	match movement:
		&"shake":
			tween.tween_property(ctrl, "modulate", colour, 0.05)
			tween.tween_property(
				ctrl, "position", origin + Vector2(3, 0), 0.04,
			)
			tween.tween_property(
				ctrl, "position", origin + Vector2(-3, 0), 0.04,
			)
			tween.tween_property(
				ctrl, "position", origin + Vector2(3, 0), 0.04,
			)
			tween.tween_property(ctrl, "position", origin, 0.04)
			tween.tween_property(ctrl, "modulate", Color.WHITE, 0.14)
			return 0.35

		&"droop":
			tween.tween_property(ctrl, "modulate", colour, 0.08)
			tween.tween_property(
				ctrl, "position", origin + Vector2(0, 4), 0.15,
			)
			tween.tween_property(ctrl, "position", origin, 0.1)
			tween.tween_property(ctrl, "modulate", Color.WHITE, 0.07)
			return 0.4

		&"pulse":
			ctrl.pivot_offset = ctrl.size / 2.0
			tween.tween_property(ctrl, "modulate", colour, 0.08)
			tween.tween_property(ctrl, "scale", Vector2(1.08, 1.08), 0.12)
			tween.tween_property(ctrl, "scale", Vector2.ONE, 0.12)
			tween.tween_property(ctrl, "modulate", Color.WHITE, 0.08)
			return 0.4

		&"flicker":
			tween.tween_property(ctrl, "modulate", colour, 0.04)
			tween.tween_property(ctrl, "modulate", Color.WHITE, 0.04)
			tween.tween_property(ctrl, "modulate", colour, 0.04)
			tween.tween_property(ctrl, "modulate", Color.WHITE, 0.04)
			tween.tween_property(ctrl, "modulate", colour, 0.04)
			tween.tween_property(ctrl, "modulate", Color.WHITE, 0.15)
			return 0.35

		_:  # "none" — colour flash only
			tween.tween_property(ctrl, "modulate", colour, 0.08)
			tween.tween_property(ctrl, "modulate", Color.WHITE, 0.27)
			return 0.35


func anim_status_hurt(
	side_index: int, slot_index: int, source_key: StringName,
) -> float:
	if not STATUS_HURT_ANIMS.has(source_key):
		return 0.0
	var colour: Color = STATUS_HURT_ANIMS[source_key] as Color

	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "modulate", colour, 0.05)
	tween.tween_property(ctrl, "position", origin + Vector2(6, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(-6, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(4, 0), 0.04)
	tween.tween_property(ctrl, "position", origin + Vector2(-4, 0), 0.04)
	tween.tween_property(ctrl, "position", origin, 0.04)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.1)
	return 0.3


func anim_stat_raise(side_index: int, slot_index: int) -> float:
	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "modulate", Color(0.4, 1.4, 0.4), 0.08)
	tween.tween_property(ctrl, "position", origin + Vector2(0, -6), 0.08)
	tween.tween_property(ctrl, "position", origin, 0.12)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.12)
	return 0.35


func anim_stat_lower(side_index: int, slot_index: int) -> float:
	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	var origin: Vector2 = ctrl.position

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "modulate", Color(1.4, 0.4, 0.4), 0.08)
	tween.tween_property(ctrl, "position", origin + Vector2(0, 6), 0.08)
	tween.tween_property(ctrl, "position", origin, 0.12)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.12)
	return 0.35


func anim_rest(side_index: int, slot_index: int) -> float:
	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control

	var glow := Color(0.5, 0.75, 1.4)  # Energy-blue tint
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "modulate", glow, 0.15)
	tween.tween_property(ctrl, "modulate", Color.WHITE, 0.25)
	return 0.4


func anim_switch_out(side_index: int, slot_index: int) -> float:
	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	ctrl.pivot_offset = ctrl.size / 2.0
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "scale", Vector2.ZERO, 0.25)
	return 0.25


func anim_switch_in(side_index: int, slot_index: int) -> float:
	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder is not Control:
		return 0.0
	var ctrl: Control = placeholder as Control
	ctrl.pivot_offset = ctrl.size / 2.0
	ctrl.scale = Vector2.ZERO
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ctrl, "scale", Vector2.ONE, 0.25)
	return 0.25


## --- Hover Bounce ---


func _get_sprite_child(vbox: Node) -> Control:
	var sprite: Node = vbox.get_node_or_null("SpriteRect")
	if sprite is Control:
		return sprite as Control
	sprite = vbox.get_node_or_null("ColorRect")
	if sprite is Control:
		return sprite as Control
	return null


func _on_sprite_mouse_entered(side_index: int, slot_index: int) -> void:
	if phase_ref.is_valid() and phase_ref.call() == 2:  # EXECUTING
		return

	var key: String = "%d_%d" % [side_index, slot_index]
	if key == _active_bounce_key:
		return

	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder == null:
		return

	var sprite: Control = _get_sprite_child(placeholder)
	if sprite == null:
		return

	if _hover_tweens.has(key) and _hover_tweens[key] is Tween:
		(_hover_tweens[key] as Tween).kill()

	var tween: Tween = get_tree().create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_hover_tweens[key] = tween


func _on_sprite_mouse_exited(side_index: int, slot_index: int) -> void:
	var key: String = "%d_%d" % [side_index, slot_index]
	if _hover_tweens.has(key) and _hover_tweens[key] is Tween:
		(_hover_tweens[key] as Tween).kill()
		_hover_tweens.erase(key)

	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder == null:
		return

	var sprite: Control = _get_sprite_child(placeholder)
	if sprite != null:
		sprite.position.y = 0.0


func _on_sprite_gui_input(
	event: InputEvent, side_index: int, slot_index: int
) -> void:
	if not _is_targeting:
		return
	if event is not InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var key: String = "%d_%d" % [side_index, slot_index]
	if _valid_target_map.has(key):
		var callback: Callable = _on_target_click
		exit_targeting_mode()
		if callback.is_valid():
			callback.call(side_index, slot_index)


## --- Active Digimon Bounce ---


func start_active_bounce(side_index: int, slot_index: int) -> void:
	stop_active_bounce()
	_active_bounce_key = "%d_%d" % [side_index, slot_index]

	var placeholder: Node = get_battlefield_placeholder(side_index, slot_index)
	if placeholder != null:
		var sprite: Control = _get_sprite_child(placeholder)
		if sprite != null:
			_active_bounce_tween = get_tree().create_tween().set_loops()
			_active_bounce_tween.tween_property(
				sprite, "position:y", -6.0, 0.2
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			_active_bounce_tween.tween_property(
				sprite, "position:y", 0.0, 0.2
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	var panel: DigimonPanel = get_panel(side_index, slot_index)
	if panel != null:
		_active_panel_origin_y = panel.position.y
		_active_bounce_panel_tween = get_tree().create_tween().set_loops()
		_active_bounce_panel_tween.tween_property(
			panel, "position:y", _active_panel_origin_y - 4.0, 0.25
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_active_bounce_panel_tween.tween_property(
			panel, "position:y", _active_panel_origin_y, 0.25
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func stop_active_bounce() -> void:
	if _active_bounce_tween != null:
		_active_bounce_tween.kill()
		_active_bounce_tween = null

	if _active_bounce_panel_tween != null:
		_active_bounce_panel_tween.kill()
		_active_bounce_panel_tween = null

	if _active_bounce_key != "":
		var parts: PackedStringArray = _active_bounce_key.split("_")
		if parts.size() == 2:
			var si: int = int(parts[0])
			var sli: int = int(parts[1])

			var placeholder: Node = get_battlefield_placeholder(si, sli)
			if placeholder != null:
				var sprite: Control = _get_sprite_child(placeholder)
				if sprite != null:
					sprite.position.y = 0.0

			var panel: DigimonPanel = get_panel(si, sli)
			if panel != null:
				panel.position.y = _active_panel_origin_y

		_active_bounce_key = ""


## --- Sprite-Based Targeting Mode ---


func enter_targeting_mode(
	user: BattleDigimonState,
	targets: Array[Dictionary],
	target_click_callback: Callable,
	target_back_button: Button,
	message_box: BattleMessageBox,
) -> void:
	_valid_target_map.clear()
	_is_targeting = true
	_on_target_click = target_click_callback
	message_box.show_prompt("Select a target...")

	for target: Dictionary in targets:
		var si: int = int(target["side"])
		var sli: int = int(target["slot"])
		var key: String = "%d_%d" % [si, sli]
		_valid_target_map[key] = true

		var is_foe: bool = _battle.are_foes(user.side_index, si)
		var indicator_colour: TargetIndicator.IndicatorColour = \
			TargetIndicator.IndicatorColour.FOE if is_foe else \
			TargetIndicator.IndicatorColour.ALLY

		var indicator: TargetIndicator = TargetIndicator.create(
			indicator_colour,
		)
		var placeholder: Node = get_battlefield_placeholder(si, sli)
		if placeholder != null:
			var sprite: Control = _get_sprite_child(placeholder)
			if sprite != null:
				sprite.add_child(indicator)
				_target_indicators.append(indicator)

	target_back_button.visible = true


func exit_targeting_mode() -> void:
	_is_targeting = false
	_valid_target_map.clear()
	_on_target_click = Callable()

	for indicator: TargetIndicator in _target_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	_target_indicators.clear()


func is_targeting() -> bool:
	return _is_targeting
