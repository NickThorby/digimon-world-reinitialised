extends Control
## Evolution Screen
##
## Purpose: View available evolutions and evolve a Digimon.
##
## Context inputs (Game.screen_context):
##   party_index: int — index in party (-1 if from storage)
##   storage_box: int — box index (-1 if from party)
##   storage_slot: int — slot index (-1 if from party)
##   mode: Registry.GameMode — TEST or STORY
##   return_scene: String — scene to navigate back to
##
## Context outputs (Game.screen_result):
##   None

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _LEFT := "MarginContainer/VBox/ContentHBox/CurrentPanel"
const _CENTRE := "MarginContainer/VBox/ContentHBox/EvolutionListPanel"
const _RIGHT := "MarginContainer/VBox/ContentHBox/PreviewPanel"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _current_sprite: TextureRect = get_node(_LEFT + "/CurrentSpriteRect")
@onready var _current_name: Label = get_node(_LEFT + "/CurrentNameLabel")
@onready var _current_level: Label = get_node(_LEFT + "/CurrentLevelLabel")
@onready var _current_stats: VBoxContainer = get_node(_LEFT + "/CurrentStatsVBox")
@onready var _list_header: Label = get_node(_CENTRE + "/ListHeader")
@onready var _evo_cards: VBoxContainer = get_node(
	_CENTRE + "/EvolutionScroll/EvolutionCards"
)
@onready var _preview_sprite: TextureRect = get_node(_RIGHT + "/PreviewSpriteRect")
@onready var _preview_name: Label = get_node(_RIGHT + "/PreviewNameLabel")
@onready var _preview_stats: VBoxContainer = get_node(_RIGHT + "/PreviewStatsVBox")
@onready var _force_evolve_button: Button = $MarginContainer/VBox/BottomBar/ForceEvolveButton
@onready var _status_label: Label = $MarginContainer/VBox/BottomBar/StatusLabel

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _party_index: int = -1
var _storage_box: int = -1
var _storage_slot: int = -1
var _return_scene: String = ""
var _digimon: DigimonState = null
var _evolution_links: Array[EvolutionLinkData] = []
var _selected_link: EvolutionLinkData = null

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
	_read_context()
	_resolve_digimon()

	if _digimon == null:
		_status_label.text = "No Digimon selected"
		return

	_update_current_panel()
	_find_evolutions()
	_build_evolution_cards()
	_clear_preview()
	_configure_force_button()
	_connect_signals()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_party_index = ctx.get("party_index", -1)
	_storage_box = ctx.get("storage_box", -1)
	_storage_slot = ctx.get("storage_slot", -1)
	_return_scene = ctx.get("return_scene", "")


func _resolve_digimon() -> void:
	if Game.state == null:
		return
	if _party_index >= 0 and _party_index < Game.state.party.members.size():
		_digimon = Game.state.party.members[_party_index]
	elif _storage_box >= 0 and _storage_slot >= 0:
		_digimon = Game.state.storage.get_digimon(_storage_box, _storage_slot)


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_force_evolve_button.pressed.connect(_on_force_evolve)


func _configure_force_button() -> void:
	_force_evolve_button.visible = (_mode == Registry.GameMode.TEST)


# --- Current Digimon panel ---


func _update_current_panel() -> void:
	var data: DigimonData = Atlas.digimon.get(_digimon.key) as DigimonData
	if data:
		_current_name.text = data.display_name
		_current_sprite.texture = data.sprite_texture
		_current_sprite.flip_h = true
	else:
		_current_name.text = str(_digimon.key)
	_current_level.text = "Lv. %d" % _digimon.level
	_build_stat_display(_current_stats, data, _digimon)


func _build_stat_display(
	container: VBoxContainer, data: DigimonData, state: DigimonState,
) -> void:
	for child: Node in container.get_children():
		child.queue_free()
	if data == null or state == null:
		return
	var stats: Dictionary = StatCalculator.calculate_all_stats(data, state)
	for stat_key: StringName in STAT_KEYS:
		var label := Label.new()
		label.text = "%s: %d" % [STAT_DISPLAY_NAMES.get(stat_key, ""), stats.get(stat_key, 0)]
		label.add_theme_font_size_override("font_size", 13)
		container.add_child(label)


# --- Find evolutions ---


func _find_evolutions() -> void:
	_evolution_links.clear()
	for evo_key: StringName in Atlas.evolutions:
		var link: EvolutionLinkData = Atlas.evolutions[evo_key] as EvolutionLinkData
		if link and link.from_key == _digimon.key:
			_evolution_links.append(link)


# --- Build cards ---


func _build_evolution_cards() -> void:
	for child: Node in _evo_cards.get_children():
		child.queue_free()

	_list_header.text = "Available Evolutions (%d)" % _evolution_links.size()

	if _evolution_links.is_empty():
		var label := Label.new()
		label.text = "No evolutions available"
		label.add_theme_color_override(
			"font_color", Color(0.443, 0.443, 0.478, 1),
		)
		label.add_theme_font_size_override("font_size", 14)
		_evo_cards.add_child(label)
		return

	var inventory: InventoryState = Game.state.inventory if Game.state else InventoryState.new()

	for link: EvolutionLinkData in _evolution_links:
		var card := _create_evolution_card(link, inventory)
		_evo_cards.add_child(card)


func _create_evolution_card(
	link: EvolutionLinkData, inventory: InventoryState,
) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)

	var target_data: DigimonData = Atlas.digimon.get(link.to_key) as DigimonData
	var target_name: String = target_data.display_name if target_data else str(link.to_key)

	# Header row: name + evo type badge
	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = target_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var type_label := Label.new()
	type_label.text = Registry.evolution_type_labels.get(link.evolution_type, "Standard")
	type_label.add_theme_color_override(
		"font_color", Color(0.443, 0.443, 0.478, 1),
	)
	type_label.add_theme_font_size_override("font_size", 13)
	header.add_child(type_label)
	card.add_child(header)

	# Requirements checklist
	var reqs: Array[Dictionary] = EvolutionChecker.check_requirements(
		link, _digimon, inventory,
	)
	var can_evolve: bool = EvolutionChecker.can_evolve(link, _digimon, inventory)

	for req: Dictionary in reqs:
		var req_label := Label.new()
		var met: bool = req.get("met", false)
		var icon: String = "[OK]" if met else "[X]"
		req_label.text = "%s %s" % [icon, req.get("description", "")]
		req_label.add_theme_font_size_override("font_size", 13)
		if met:
			req_label.add_theme_color_override(
				"font_color", Color(0.3, 0.85, 0.3, 1),
			)
		else:
			req_label.add_theme_color_override(
				"font_color", Color(0.85, 0.3, 0.3, 1),
			)
		card.add_child(req_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	var evolve_btn := Button.new()
	evolve_btn.text = "Evolve!"
	evolve_btn.custom_minimum_size = Vector2(100, 32)
	evolve_btn.disabled = not can_evolve
	evolve_btn.pressed.connect(_on_evolve_pressed.bind(link))
	btn_row.add_child(evolve_btn)

	var preview_btn := Button.new()
	preview_btn.text = "Preview"
	preview_btn.custom_minimum_size = Vector2(80, 32)
	preview_btn.pressed.connect(_on_preview_pressed.bind(link))
	btn_row.add_child(preview_btn)

	card.add_child(btn_row)

	# Dim unmet cards
	if not can_evolve:
		card.modulate = Color(1, 1, 1, 0.6)

	# Separator
	var sep := HSeparator.new()
	card.add_child(sep)

	return card


# --- Preview ---


func _clear_preview() -> void:
	_preview_sprite.texture = null
	_preview_name.text = ""
	for child: Node in _preview_stats.get_children():
		child.queue_free()
	_selected_link = null


func _on_preview_pressed(link: EvolutionLinkData) -> void:
	_selected_link = link
	var target_data: DigimonData = Atlas.digimon.get(link.to_key) as DigimonData
	if target_data == null:
		_clear_preview()
		return

	_preview_name.text = target_data.display_name
	_preview_sprite.texture = target_data.sprite_texture
	_preview_sprite.flip_h = true

	# Show projected stats with current IVs/TVs
	var projected_state := DigimonState.new()
	projected_state.key = link.to_key
	projected_state.level = _digimon.level
	projected_state.ivs = _digimon.ivs.duplicate()
	projected_state.tvs = _digimon.tvs.duplicate()
	projected_state.hyper_trained_ivs = _digimon.hyper_trained_ivs.duplicate()
	_build_stat_display(_preview_stats, target_data, projected_state)


# --- Evolve ---


func _on_evolve_pressed(link: EvolutionLinkData) -> void:
	_execute_evolution(link)


func _on_force_evolve() -> void:
	if _selected_link != null:
		_execute_evolution(_selected_link)
	elif not _evolution_links.is_empty():
		_execute_evolution(_evolution_links[0])


func _execute_evolution(link: EvolutionLinkData) -> void:
	if _digimon == null or Game.state == null:
		return

	var old_data: DigimonData = Atlas.digimon.get(_digimon.key) as DigimonData
	var new_data: DigimonData = Atlas.digimon.get(link.to_key) as DigimonData
	if new_data == null:
		_status_label.text = "Evolution target not found!"
		return

	# Store old max HP/energy for proportional scaling
	var old_stats: Dictionary = StatCalculator.calculate_all_stats(old_data, _digimon) \
		if old_data else {}
	var old_max_hp: int = old_stats.get(&"hp", 1) as int
	var old_max_energy: int = old_stats.get(&"energy", 1) as int

	# Change species
	_digimon.key = link.to_key

	# Calculate new max HP/energy
	var new_stats: Dictionary = StatCalculator.calculate_all_stats(new_data, _digimon)
	var new_max_hp: int = new_stats.get(&"hp", 1) as int
	var new_max_energy: int = new_stats.get(&"energy", 1) as int

	# Proportional HP/energy scaling
	if old_max_hp > 0:
		_digimon.current_hp = maxi(
			floori(float(_digimon.current_hp) / float(old_max_hp) * float(new_max_hp)),
			1,
		)
	else:
		_digimon.current_hp = new_max_hp
	if old_max_energy > 0:
		_digimon.current_energy = maxi(
			floori(
				float(_digimon.current_energy) / float(old_max_energy) * float(new_max_energy)
			),
			1,
		)
	else:
		_digimon.current_energy = new_max_energy

	# Add innate techniques from new form
	var new_innate: Array[StringName] = new_data.get_innate_technique_keys()
	for tech_key: StringName in new_innate:
		if tech_key not in _digimon.known_technique_keys:
			_digimon.known_technique_keys.append(tech_key)

	# Consume required items (spirits, digimentals, x_antibody)
	_consume_evolution_items(link)

	# Refresh UI
	_update_current_panel()
	_find_evolutions()
	_build_evolution_cards()
	_clear_preview()
	_status_label.text = "Evolution complete!"


func _consume_evolution_items(link: EvolutionLinkData) -> void:
	if Game.state == null:
		return
	for req: Dictionary in link.requirements:
		var req_type: String = req.get("type", "")
		match req_type:
			"spirit":
				var item_key: StringName = StringName(req.get("spirit", ""))
				_remove_item(item_key, 1)
			"digimental":
				var item_key: StringName = StringName(req.get("digimental", ""))
				_remove_item(item_key, 1)
			"x_antibody":
				var amount: int = int(req.get("amount", 1))
				_remove_item(&"x_antibody", amount)


func _remove_item(item_key: StringName, amount: int) -> void:
	if item_key == &"" or Game.state == null:
		return
	var current: int = Game.state.inventory.items.get(item_key, 0)
	var new_qty: int = current - amount
	if new_qty <= 0:
		Game.state.inventory.items.erase(item_key)
	else:
		Game.state.inventory.items[item_key] = new_qty


func _on_back_pressed() -> void:
	if _return_scene != "":
		Game.screen_context = {"mode": _mode}
		SceneManager.change_scene(_return_scene)
