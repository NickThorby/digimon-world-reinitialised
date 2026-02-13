extends Control
## Test Functions Screen — debug/test actions for development.
##
## Context inputs (Game.screen_context):
##   mode: Registry.GameMode
##   return_scene: String — scene to return to on back

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _GRID := "MarginContainer/VBox/CentreWrap/ButtonGrid"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _heal_button: Button = get_node(_GRID + "/HealButton")
@onready var _grant_bits_button: Button = get_node(_GRID + "/GrantBitsButton")

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _return_scene: String = ""


func _ready() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_return_scene = ctx.get("return_scene", "")
	_connect_signals()


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_heal_button.pressed.connect(_on_heal_pressed)
	_grant_bits_button.pressed.connect(_on_grant_bits_pressed)


func _on_back_pressed() -> void:
	Game.screen_context = {"mode": _mode}
	if _return_scene != "":
		SceneManager.change_scene(_return_scene)


func _on_heal_pressed() -> void:
	if Game.state == null or Game.state.party.members.is_empty():
		return
	for member: DigimonState in Game.state.party.members:
		var data: DigimonData = Atlas.digimon.get(member.key) as DigimonData
		if data == null:
			continue
		var stats: Dictionary = StatCalculator.calculate_all_stats(data, member)
		var personality: PersonalityData = Atlas.personalities.get(
			member.get_effective_personality_key(),
		) as PersonalityData
		member.current_hp = StatCalculator.apply_personality(
			stats.get(&"hp", 1), &"hp", personality,
		)
		member.current_energy = StatCalculator.apply_personality(
			stats.get(&"energy", 1), &"energy", personality,
		)
		member.status_conditions.clear()


func _on_grant_bits_pressed() -> void:
	if Game.state == null:
		return
	var popup := PopupMenu.new()
	popup.add_item("+100 Bits", 100)
	popup.add_item("+1,000 Bits", 1000)
	popup.add_item("+10,000 Bits", 10000)
	add_child(popup)
	popup.id_pressed.connect(func(amount: int) -> void:
		Game.state.inventory.bits += amount
		popup.queue_free()
	)
	popup.popup_centered()
