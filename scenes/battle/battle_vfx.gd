class_name BattleVFX
extends RefCounted
## Utility for spawning element-coloured particle effects during battle animations.
## Uses CPUParticles2D for cross-platform reliability with low particle counts.


## Spawn a one-shot burst of particles at a control's centre.
## Returns immediately — particles self-clean after lifetime.
func spawn_burst(
	parent: Control,
	element_key: StringName,
	amount: int = 12,
	lifetime: float = 0.4,
	spread: float = 60.0,
	speed: float = 80.0,
) -> void:
	if parent == null or not parent.is_inside_tree():
		return

	var colour: Color = _get_element_colour(element_key)
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.9
	particles.direction = Vector2.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.6
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, 40)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = colour
	particles.position = parent.size / 2.0

	parent.add_child(particles)
	_auto_free(particles, lifetime + 0.5)


## Spawn a continuously-emitting particle trail that tweens from user to target.
## Returns the travel duration so callers can await it.
func spawn_projectile(
	scene_root: Node,
	user_ctrl: Control,
	target_ctrl: Control,
	element_key: StringName,
	travel_duration: float = 0.35,
) -> float:
	if scene_root == null or user_ctrl == null or target_ctrl == null:
		return 0.0
	if not scene_root.is_inside_tree():
		return 0.0

	var colour: Color = _get_element_colour(element_key)
	var start_pos: Vector2 = user_ctrl.global_position + user_ctrl.size / 2.0
	var end_pos: Vector2 = target_ctrl.global_position + target_ctrl.size / 2.0

	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = 24
	particles.lifetime = 0.35
	particles.explosiveness = 0.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 40.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = colour
	particles.global_position = start_pos

	scene_root.add_child(particles)

	var tween: Tween = scene_root.get_tree().create_tween()
	tween.tween_property(
		particles, "global_position", end_pos, travel_duration,
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	_auto_free(particles, travel_duration + 0.5)
	return travel_duration


## Spawn lighter particles that drift gently from user towards target.
## Used for status-class techniques.
func spawn_status_particles(
	scene_root: Node,
	user_ctrl: Control,
	target_ctrl: Control,
	element_key: StringName,
) -> float:
	if scene_root == null or user_ctrl == null or target_ctrl == null:
		return 0.0
	if not scene_root.is_inside_tree():
		return 0.0

	var colour: Color = _get_element_colour(element_key)
	colour.a = 0.85
	var start_pos: Vector2 = user_ctrl.global_position + user_ctrl.size / 2.0
	var end_pos: Vector2 = target_ctrl.global_position + target_ctrl.size / 2.0

	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 0.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 25.0
	particles.gravity = Vector2(0, -10)
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 4.0
	particles.color = colour
	particles.global_position = start_pos

	scene_root.add_child(particles)

	var travel: float = 0.5
	var tween: Tween = scene_root.get_tree().create_tween()
	tween.tween_property(
		particles, "global_position", end_pos, travel,
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	_auto_free(particles, travel + 0.6)
	return travel


## Look up the colour for an element key, falling back to grey.
func _get_element_colour(element_key: StringName) -> Color:
	if element_key == &"" or not Registry.ELEMENT_COLOURS.has(element_key):
		return Registry.ELEMENT_COLOURS.get(&"null", Color(0.75, 0.75, 0.75))
	return Registry.ELEMENT_COLOURS[element_key] as Color


## Schedule a node for automatic cleanup after a delay.
func _auto_free(node: Node, delay: float) -> void:
	if not node.is_inside_tree():
		return
	var timer: SceneTreeTimer = node.get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)
