class_name TechniqueSwapPopup
extends PanelContainer
## Lets the player choose which equipped technique to forget when learning a new
## one at full capacity.


signal technique_chosen(forgotten_key: StringName)
signal kept_current

@onready var _prompt_label: Label = $VBox/PromptLabel
@onready var _technique_list: VBoxContainer = $VBox/ScrollContainer/TechniqueList
@onready var _dont_learn_button: Button = $VBox/DontLearnButton

var _new_technique_key: StringName = &""


func _ready() -> void:
	_dont_learn_button.pressed.connect(func() -> void: kept_current.emit())


## Set up the popup showing current equipped techniques + the new one.
func setup(state: DigimonState, new_technique_key: StringName) -> void:
	_new_technique_key = new_technique_key

	var new_tech: TechniqueData = Atlas.techniques.get(
		new_technique_key,
	) as TechniqueData
	var new_name: String = new_tech.display_name if new_tech else str(new_technique_key)
	_prompt_label.text = "Wants to learn %s!\nChoose a technique to forget:" % new_name

	# Clear list
	for child: Node in _technique_list.get_children():
		child.queue_free()

	# Show current equipped techniques (these can be forgotten)
	for tech_key: StringName in state.equipped_technique_keys:
		_add_technique_button(tech_key, false)

	# Show the new technique (highlighted)
	_add_technique_button(new_technique_key, true)

	visible = true


func _add_technique_button(tech_key: StringName, is_new: bool) -> void:
	var tech: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
	if tech == null:
		return

	var class_label: String = ""
	match tech.technique_class:
		Registry.TechniqueClass.PHYSICAL:
			class_label = "Physical"
		Registry.TechniqueClass.SPECIAL:
			class_label = "Special"
		Registry.TechniqueClass.STATUS:
			class_label = "Status"

	var element_str: String = str(tech.element_key).capitalize() \
		if tech.element_key != &"" else "Neutral"

	var button := Button.new()
	var text: String = "%s  [%s / %s]  Pow: %d  EN: %d" % [
		tech.display_name, element_str, class_label,
		tech.power, tech.energy_cost,
	]
	if is_new:
		text = "NEW: " + text
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = tech.description if tech.description != "" else ""

	if is_new:
		# Clicking the new technique does nothing (can't forget what you haven't equipped)
		button.disabled = true
	else:
		var key: StringName = tech_key
		button.pressed.connect(
			func() -> void: technique_chosen.emit(key)
		)

	_technique_list.add_child(button)
