class_name BattleEvolutionMenu
extends PanelContainer
## In-battle evolution selection overlay. Shows available evolutions with
## requirement checklists and projected stats. Supports warp toggle.


signal evolution_chosen(
	link_key: StringName, is_jogress: bool,
	is_warp: bool, warp_link_keys: Array[StringName],
)
signal back_pressed()

@onready var _title_label: Label = get_node(
	"MarginContainer/VBox/HeaderHBox/TitleLabel",
)
@onready var _warp_toggle: CheckButton = get_node(
	"MarginContainer/VBox/HeaderHBox/WarpToggle",
)
@onready var _back_button: Button = get_node(
	"MarginContainer/VBox/HeaderHBox/BackButton",
)
@onready var _current_sprite: TextureRect = get_node(
	"MarginContainer/VBox/ContentHBox/CurrentPanel/CurrentSprite",
)
@onready var _current_name: Label = get_node(
	"MarginContainer/VBox/ContentHBox/CurrentPanel/CurrentName",
)
@onready var _current_level: Label = get_node(
	"MarginContainer/VBox/ContentHBox/CurrentPanel/CurrentLevel",
)
@onready var _evo_cards: VBoxContainer = get_node(
	"MarginContainer/VBox/ContentHBox/EvolutionScroll/EvolutionCards",
)
@onready var _preview_sprite: TextureRect = get_node(
	"MarginContainer/VBox/ContentHBox/PreviewPanel/PreviewSprite",
)
@onready var _preview_name: Label = get_node(
	"MarginContainer/VBox/ContentHBox/PreviewPanel/PreviewName",
)
@onready var _preview_stats: VBoxContainer = get_node(
	"MarginContainer/VBox/ContentHBox/PreviewPanel/PreviewStatsVBox",
)
@onready var _evolve_button: Button = get_node(
	"MarginContainer/VBox/ContentHBox/PreviewPanel/EvolveButton",
)

var _digimon: DigimonState = null
var _side: SideState = null
var _inventory: InventoryState = null
var _evolution_links: Array[EvolutionLinkData] = []
var _warp_results: Array[Dictionary] = []
var _selected_link: EvolutionLinkData = null
var _selected_warp: Dictionary = {}
var _is_warp_mode: bool = false

const STAT_KEYS: Array[StringName] = [
	&"hp", &"energy", &"attack", &"defence",
	&"special_attack", &"special_defence", &"speed",
]

const STAT_DISPLAY_NAMES: Dictionary = {
	&"hp": "HP",
	&"energy": "Energy",
	&"attack": "Attack",
	&"defence": "Defence",
	&"special_attack": "Sp. Attack",
	&"special_defence": "Sp. Defence",
	&"speed": "Speed",
}


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_evolve_button.pressed.connect(_on_evolve_pressed)
	_warp_toggle.toggled.connect(_on_warp_toggled)


## Populate the menu with available evolutions.
func populate(
	digimon: DigimonState,
	side: SideState,
	inventory: InventoryState,
) -> void:
	_digimon = digimon
	_side = side
	_inventory = inventory
	_is_warp_mode = false
	_warp_toggle.button_pressed = false
	_selected_link = null
	_selected_warp = {}

	_title_label.text = Settings.get_evolution_noun()

	# Update current panel
	var data: DigimonData = Atlas.digimon.get(_digimon.key) as DigimonData
	if data:
		_current_name.text = data.display_name
		_current_sprite.texture = data.sprite_texture
		_current_sprite.flip_h = true
	else:
		_current_name.text = str(_digimon.key)
	_current_level.text = "Lv. %d" % _digimon.level

	# Find standard evolutions
	_evolution_links = EvolutionService.find_available_evolutions(_digimon)
	_warp_results = EvolutionService.find_warp_evolutions(
		_digimon, _inventory,
		_build_party_state(), null,
	)

	# Show/hide warp toggle based on whether warp results exist
	_warp_toggle.visible = not _warp_results.is_empty()

	_rebuild_cards()
	_clear_preview()


## Build a temporary PartyState from the side's reserves for jogress checks.
func _build_party_state() -> PartyState:
	var party := PartyState.new()
	party.members = []
	if _side != null:
		for reserve: DigimonState in _side.party:
			party.members.append(reserve)
		# Include active slot Digimon (except the evolving one)
		for slot: SlotState in _side.slots:
			if slot.digimon != null and not slot.digimon.is_fainted \
					and slot.digimon.source_state != _digimon:
				party.members.append(slot.digimon.source_state)
	return party


func _on_warp_toggled(toggled_on: bool) -> void:
	_is_warp_mode = toggled_on
	_selected_link = null
	_selected_warp = {}
	_rebuild_cards()
	_clear_preview()


func _rebuild_cards() -> void:
	for child: Node in _evo_cards.get_children():
		child.queue_free()

	if _is_warp_mode:
		_build_warp_cards()
	else:
		_build_standard_cards()


func _build_standard_cards() -> void:
	var party: PartyState = _build_party_state()

	for link: EvolutionLinkData in _evolution_links:
		var can_evo: bool = EvolutionChecker.can_evolve(
			link, _digimon, _inventory, party, null,
		)
		var card: VBoxContainer = _create_standard_card(link, can_evo)
		_evo_cards.add_child(card)


func _build_warp_cards() -> void:
	for warp: Dictionary in _warp_results:
		var card: VBoxContainer = _create_warp_card(warp)
		_evo_cards.add_child(card)


func _create_standard_card(
	link: EvolutionLinkData, can_evolve: bool,
) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_standard_card_clicked.bind(link))

	var target_data: DigimonData = Atlas.digimon.get(link.to_key) as DigimonData
	var target_name: String = target_data.display_name if target_data else str(link.to_key)

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = target_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var type_label := Label.new()
	type_label.text = Registry.evolution_type_labels.get(link.evolution_type, "Standard")
	type_label.add_theme_color_override("font_color", Color(0.443, 0.443, 0.478, 1))
	type_label.add_theme_font_size_override("font_size", 12)
	header.add_child(type_label)
	card.add_child(header)

	# Requirement checklist
	var reqs: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _digimon, _inventory,
	)
	for req: Dictionary in reqs:
		var req_label := Label.new()
		var met: bool = req.get("met", false)
		req_label.text = "%s %s" % ["[OK]" if met else "[X]", req.get("description", "")]
		req_label.add_theme_font_size_override("font_size", 12)
		req_label.add_theme_color_override(
			"font_color",
			Color(0.3, 0.85, 0.3, 1) if met else Color(0.85, 0.3, 0.3, 1),
		)
		card.add_child(req_label)

	if not can_evolve:
		card.modulate = Color(1, 1, 1, 0.6)

	var sep := HSeparator.new()
	card.add_child(sep)
	return card


func _create_warp_card(warp: Dictionary) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_warp_card_clicked.bind(warp))

	var final_key: StringName = warp.get("final_key", &"") as StringName
	var target_data: DigimonData = Atlas.digimon.get(final_key) as DigimonData
	var target_name: String = target_data.display_name if target_data else str(final_key)

	var chain: Array = warp.get("chain", [])
	var chain_text: String = "%d-step warp" % chain.size()

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = target_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var steps_label := Label.new()
	steps_label.text = chain_text
	steps_label.add_theme_color_override("font_color", Color(0.443, 0.443, 0.478, 1))
	steps_label.add_theme_font_size_override("font_size", 12)
	header.add_child(steps_label)
	card.add_child(header)

	var sep := HSeparator.new()
	card.add_child(sep)
	return card


func _on_standard_card_clicked(
	event: InputEvent, link: EvolutionLinkData,
) -> void:
	if event is not InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_select_standard(link)


func _on_warp_card_clicked(event: InputEvent, warp: Dictionary) -> void:
	if event is not InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_select_warp(warp)


func _select_standard(link: EvolutionLinkData) -> void:
	_selected_link = link
	_selected_warp = {}
	_show_preview(link.to_key)

	var party: PartyState = _build_party_state()
	var can_evo: bool = EvolutionChecker.can_evolve(
		link, _digimon, _inventory, party, null,
	)
	_evolve_button.text = Settings.get_evolve_imperative()
	_evolve_button.disabled = not can_evo
	_evolve_button.visible = true


func _select_warp(warp: Dictionary) -> void:
	_selected_link = null
	_selected_warp = warp
	var final_key: StringName = warp.get("final_key", &"") as StringName
	_show_preview(final_key)

	_evolve_button.text = "Warp " + Settings.get_evolve_imperative()
	_evolve_button.disabled = false
	_evolve_button.visible = true


func _show_preview(target_key: StringName) -> void:
	var target_data: DigimonData = Atlas.digimon.get(target_key) as DigimonData
	if target_data == null:
		_clear_preview()
		return

	_preview_name.text = target_data.display_name
	_preview_sprite.texture = target_data.sprite_texture
	_preview_sprite.flip_h = true

	# Show projected stats
	for child: Node in _preview_stats.get_children():
		child.queue_free()
	var projected := DigimonState.new()
	projected.key = target_key
	projected.level = _digimon.level
	projected.ivs = _digimon.ivs.duplicate()
	projected.tvs = _digimon.tvs.duplicate()
	projected.hyper_trained_ivs = _digimon.hyper_trained_ivs.duplicate()
	var stats: Dictionary = StatCalculator.calculate_all_stats(
		target_data, projected,
	)
	for stat_key: StringName in STAT_KEYS:
		var label := Label.new()
		label.text = "%s: %d" % [STAT_DISPLAY_NAMES.get(stat_key, ""), stats.get(stat_key, 0)]
		label.add_theme_font_size_override("font_size", 12)
		_preview_stats.add_child(label)


func _clear_preview() -> void:
	_preview_sprite.texture = null
	_preview_name.text = ""
	for child: Node in _preview_stats.get_children():
		child.queue_free()
	_selected_link = null
	_selected_warp = {}
	_evolve_button.visible = false


func _on_evolve_pressed() -> void:
	if _is_warp_mode and not _selected_warp.is_empty():
		var chain: Array = _selected_warp.get("chain", [])
		var warp_keys: Array[StringName] = []
		for link: Variant in chain:
			if link is EvolutionLinkData:
				warp_keys.append((link as EvolutionLinkData).key)
		evolution_chosen.emit(&"", false, true, warp_keys)
	elif _selected_link != null:
		var is_jogress: bool = not _selected_link.jogress_partner_keys.is_empty()
		evolution_chosen.emit(
			_selected_link.key, is_jogress, false, [] as Array[StringName],
		)
