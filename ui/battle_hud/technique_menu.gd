class_name TechniqueMenu
extends PanelContainer
## Shows equipped techniques with element, cost, and power. Emits selection.


signal technique_chosen(technique_key: StringName)
signal back_pressed

@onready var _technique_container: VBoxContainer = $VBox/ScrollContainer/TechniqueContainer
@onready var _back_button: Button = $VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## Populate with a Digimon's equipped techniques.
func populate(digimon: BattleDigimonState) -> void:
	# Clear existing buttons
	for child: Node in _technique_container.get_children():
		child.queue_free()

	for tech_key: StringName in digimon.equipped_technique_keys:
		var tech: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		if tech == null:
			continue

		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Element icon
		var element_enum: Variant = Registry.ELEMENT_KEY_MAP.get(tech.element_key)
		if element_enum != null:
			var icon_tex: Texture2D = Registry.ELEMENT_ICONS.get(
				element_enum as Registry.Element
			) as Texture2D
			if icon_tex != null:
				var icon := TextureRect.new()
				icon.texture = icon_tex
				icon.custom_minimum_size = Vector2(16, 16)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				hbox.add_child(icon)

		var button := Button.new()
		var label: String = "%s  EN: %d  Pow: %d" % [
			tech.display_name,
			tech.energy_cost,
			tech.power,
		]
		button.text = label
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(
			func() -> void: technique_chosen.emit(tech_key)
		)

		# Disable if technique is disabled/encored wrong
		var disabled_key: StringName = digimon.volatiles.get(
			"disabled_technique_key", &""
		) as StringName
		if tech_key == disabled_key:
			button.disabled = true

		hbox.add_child(button)
		_technique_container.add_child(hbox)
