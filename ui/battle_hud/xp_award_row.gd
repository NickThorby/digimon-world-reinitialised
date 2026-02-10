class_name XPAwardRow
extends HBoxContainer
## Per-Digimon XP row with animated bar, sprite, and level info.


signal row_clicked(digimon_state: DigimonState)

@onready var _sprite_rect: TextureRect = $SpriteRect
@onready var _name_label: Label = $InfoVBox/NameRow/NameLabel
@onready var _level_label: Label = $InfoVBox/NameRow/LevelLabel
@onready var _xp_bar: ProgressBar = $InfoVBox/XPBar
@onready var _technique_label: Label = $InfoVBox/TechniqueLabel

var _digimon_state: DigimonState = null
var _award: Dictionary = {}
var _has_levelled_up: bool = false


## Set up the row for a Digimon that earned XP.
func setup(state: DigimonState, award: Dictionary) -> void:
	_digimon_state = state
	_award = award
	_has_levelled_up = int(award.get("levels_gained", 0)) > 0

	var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
	var display_name: String = data.display_name if data else str(state.key)

	_name_label.text = state.nickname if state.nickname != "" else display_name
	_level_label.text = "Lv. %d" % int(award.get("old_level", state.level))

	# Sprite
	if data != null and data.sprite_texture != null:
		_sprite_rect.texture = data.sprite_texture

	# XP bar: show old progress within old level
	var old_level: int = int(award.get("old_level", state.level))
	var old_experience: int = int(award.get("old_experience", state.experience))
	var growth_rate: Registry.GrowthRate = data.growth_rate \
		if data else Registry.GrowthRate.MEDIUM_FAST
	var xp_for_old_level: int = XPCalculator.total_xp_for_level(
		old_level, growth_rate,
	)
	var xp_for_next: int = XPCalculator.total_xp_for_level(
		old_level + 1, growth_rate,
	)
	var range_size: int = maxi(xp_for_next - xp_for_old_level, 1)
	_xp_bar.max_value = range_size
	_xp_bar.value = old_experience - xp_for_old_level

	# Technique label
	var new_techs: Array = award.get("new_techniques", []) as Array
	if new_techs.size() > 0:
		var tech_names: Array[String] = []
		for tech_key: Variant in new_techs:
			var tech: TechniqueData = Atlas.techniques.get(
				tech_key as StringName,
			) as TechniqueData
			tech_names.append(tech.display_name if tech else str(tech_key))
		_technique_label.text = "Learned: %s" % ", ".join(tech_names)
		_technique_label.visible = true

	# Click handler for stat delta popup
	if _has_levelled_up:
		gui_input.connect(_on_gui_input)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Set up a greyed-out row for a Digimon that got no XP.
func setup_no_xp(state: DigimonState) -> void:
	_digimon_state = state

	var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
	var display_name: String = data.display_name if data else str(state.key)

	_name_label.text = state.nickname if state.nickname != "" else display_name
	_level_label.text = "Lv. %d" % state.level

	if data != null and data.sprite_texture != null:
		_sprite_rect.texture = data.sprite_texture

	_xp_bar.value = 0
	_xp_bar.max_value = 1
	modulate = Color(0.5, 0.5, 0.5, 0.7)


## Animate the XP bar from old value to new value, handling level-ups.
func animate_xp_bar() -> void:
	if _award.is_empty():
		return

	var data: DigimonData = Atlas.digimon.get(
		_digimon_state.key,
	) as DigimonData
	if data == null:
		return

	var growth_rate: Registry.GrowthRate = data.growth_rate
	var old_level: int = int(_award.get("old_level", _digimon_state.level))
	var levels_gained: int = int(_award.get("levels_gained", 0))
	var new_level: int = old_level + levels_gained

	# Animate through each level-up
	for lvl: int in range(old_level, new_level):
		var xp_for_lvl: int = XPCalculator.total_xp_for_level(lvl, growth_rate)
		var xp_for_next: int = XPCalculator.total_xp_for_level(
			lvl + 1, growth_rate,
		)
		var range_size: int = maxi(xp_for_next - xp_for_lvl, 1)
		_xp_bar.max_value = range_size

		# Fill to max
		var tween: Tween = create_tween()
		tween.tween_property(_xp_bar, "value", range_size, 0.3)
		await tween.finished

		# Level-up flash
		_level_label.text = "Lv. %d" % (lvl + 1)
		await get_tree().create_timer(0.15).timeout

		# Reset bar for next level
		_xp_bar.value = 0

	# Final partial fill at new level
	var xp_for_new: int = XPCalculator.total_xp_for_level(
		new_level, growth_rate,
	)
	var xp_for_next_new: int = XPCalculator.total_xp_for_level(
		new_level + 1, growth_rate,
	)
	var final_range: int = maxi(xp_for_next_new - xp_for_new, 1)
	_xp_bar.max_value = final_range
	var final_value: int = _digimon_state.experience - xp_for_new

	var final_tween: Tween = create_tween()
	final_tween.tween_property(
		_xp_bar, "value", float(final_value), 0.3,
	)
	await final_tween.finished


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			row_clicked.emit(_digimon_state)
