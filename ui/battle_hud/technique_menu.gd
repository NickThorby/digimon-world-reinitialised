class_name TechniqueMenu
extends PanelContainer
## Shows equipped techniques with element, cost, and power. Emits selection.


signal technique_chosen(technique_key: StringName)
signal back_pressed

@onready var _technique_container: VBoxContainer = %TechniqueContainer
@onready var _back_button: Button = %BackButton


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

		var button := Button.new()
		var label: String = "%s  [%s]  EN: %d  Pow: %d" % [
			tech.display_name,
			str(tech.element_key).capitalize() if tech.element_key != &"" else "Null",
			tech.energy_cost,
			tech.power,
		]
		button.text = label
		button.pressed.connect(
			func() -> void: technique_chosen.emit(tech_key)
		)

		# Disable if technique is disabled/encored wrong
		var disabled_key: StringName = digimon.volatiles.get(
			"disabled_technique_key", &""
		) as StringName
		if tech_key == disabled_key:
			button.disabled = true

		_technique_container.add_child(button)
