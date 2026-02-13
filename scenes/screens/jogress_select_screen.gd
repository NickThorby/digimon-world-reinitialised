extends Control
## Jogress Partner Selection Screen
##
## Purpose: Select partner Digimon for Jogress (DNA) evolution.
##
## Context inputs (Game.screen_context):
##   link_key: StringName — evolution link key
##   digimon_unique_id: StringName — main Digimon's unique_id
##   party_index: int — index in party (-1 if from storage)
##   storage_box: int — box index (-1 if from party)
##   storage_slot: int — slot index (-1 if from party)
##   mode: Registry.GameMode — TEST or STORY
##   return_scene: String — the evolution screen's own return_scene

const _EVOLUTION_SCREEN_PATH := "res://scenes/screens/evolution_screen.tscn"
const _EVOLUTION_ANIMATION_PATH := "res://scenes/screens/evolution_animation_screen.tscn"
const _SLOT_PANEL_SCENE := preload("res://ui/components/digimon_slot_panel.tscn")

@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/BackButton
@onready var _title_label: Label = $MarginContainer/VBox/HeaderBar/TitleLabel
@onready var _content_vbox: VBoxContainer = $MarginContainer/VBox/ContentScroll/ContentVBox
@onready var _confirm_button: Button = $MarginContainer/VBox/BottomBar/ConfirmButton
@onready var _status_label: Label = $MarginContainer/VBox/BottomBar/StatusLabel

var _link: EvolutionLinkData = null
var _digimon: DigimonState = null
var _mode: Registry.GameMode = Registry.GameMode.TEST
var _party_index: int = -1
var _storage_box: int = -1
var _storage_slot: int = -1
var _return_scene: String = ""

## partner_key → candidate dict (or null if not yet selected)
var _selected_partners: Dictionary = {}
## partner_key → Array[Dictionary] of candidate locations
var _candidates_map: Dictionary = {}
## partner_key → Array[DigimonSlotPanel] for visual refresh
var _panel_map: Dictionary = {}


func _ready() -> void:
	_read_context()
	if _link == null or _digimon == null:
		_status_label.text = "Invalid context"
		return

	_title_label.text = "Select Jogress Partners"
	_build_partner_sections()
	_update_confirm_state()
	_back_button.pressed.connect(_on_back_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	var link_key: StringName = StringName(ctx.get("link_key", ""))
	_link = Atlas.evolutions.get(link_key) as EvolutionLinkData
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_party_index = ctx.get("party_index", -1) as int
	_storage_box = ctx.get("storage_box", -1) as int
	_storage_slot = ctx.get("storage_slot", -1) as int
	_return_scene = ctx.get("return_scene", "") as String

	# Resolve main Digimon
	var unique_id: StringName = StringName(ctx.get("digimon_unique_id", ""))
	if Game.state == null:
		return
	if _party_index >= 0 and _party_index < Game.state.party.members.size():
		var member: DigimonState = Game.state.party.members[_party_index]
		if member != null and member.unique_id == unique_id:
			_digimon = member
	elif _storage_box >= 0 and _storage_slot >= 0:
		var stored: DigimonState = Game.state.storage.get_digimon(_storage_box, _storage_slot)
		if stored != null and stored.unique_id == unique_id:
			_digimon = stored

	# Resolve candidates
	if _link != null and _digimon != null:
		_candidates_map = EvolutionChecker.find_jogress_candidates(
			_link, _digimon, Game.state.party, Game.state.storage,
		)
		for partner_key: StringName in _link.jogress_partner_keys:
			_selected_partners[partner_key] = null


func _build_partner_sections() -> void:
	for child: Node in _content_vbox.get_children():
		child.queue_free()

	for partner_key: StringName in _link.jogress_partner_keys:
		var partner_data: DigimonData = Atlas.digimon.get(partner_key) as DigimonData
		var display_name: String = partner_data.display_name if partner_data else str(partner_key)

		# Section header
		var header := Label.new()
		header.text = "Partner: %s" % display_name
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override(
			"font_color", Color(0.024, 0.714, 0.831, 1),
		)
		_content_vbox.add_child(header)

		var candidates: Array = _candidates_map.get(partner_key, [])
		if candidates.is_empty():
			var empty_label := Label.new()
			empty_label.text = "No eligible %s found" % display_name
			empty_label.add_theme_font_size_override("font_size", 14)
			empty_label.add_theme_color_override(
				"font_color", Color(0.85, 0.3, 0.3, 1),
			)
			_content_vbox.add_child(empty_label)
			_panel_map[partner_key] = [] as Array[DigimonSlotPanel]
			continue

		var panels: Array[DigimonSlotPanel] = []
		for i: int in candidates.size():
			var candidate: Dictionary = candidates[i]
			var digimon: DigimonState = candidate.get("digimon") as DigimonState
			if digimon == null:
				continue
			var panel: DigimonSlotPanel = _SLOT_PANEL_SCENE.instantiate() as DigimonSlotPanel
			panel.set_button_mode(DigimonSlotPanel.ButtonMode.CONTEXT_MENU)
			panel.setup(i, digimon)
			panel.slot_clicked.connect(
				_on_candidate_selected.bind(partner_key, candidate),
			)
			panels.append(panel)
			_content_vbox.add_child(panel)

		_panel_map[partner_key] = panels

		# Separator
		var sep := HSeparator.new()
		_content_vbox.add_child(sep)


func _on_candidate_selected(
	_index: int, partner_key: StringName, candidate: Dictionary,
) -> void:
	# Toggle selection — deselect if already selected, otherwise select
	var current: Variant = _selected_partners.get(partner_key)
	if current is Dictionary and current == candidate:
		_selected_partners[partner_key] = null
	else:
		_selected_partners[partner_key] = candidate

	_refresh_panel_highlights()
	_update_confirm_state()


func _refresh_panel_highlights() -> void:
	# Collect all selected unique_ids to grey out across sections
	var selected_ids: Array[StringName] = []
	for partner_key: StringName in _selected_partners:
		var sel: Variant = _selected_partners[partner_key]
		if sel is Dictionary:
			var d: DigimonState = (sel as Dictionary).get("digimon") as DigimonState
			if d != null:
				selected_ids.append(d.unique_id)

	for partner_key: StringName in _panel_map:
		var panels: Array = _panel_map[partner_key]
		var candidates: Array = _candidates_map.get(partner_key, [])
		var selected: Variant = _selected_partners.get(partner_key)

		for i: int in panels.size():
			var panel: DigimonSlotPanel = panels[i] as DigimonSlotPanel
			if panel == null:
				continue
			var candidate: Dictionary = candidates[i] as Dictionary
			var candidate_digimon: DigimonState = candidate.get("digimon") as DigimonState
			if candidate_digimon == null:
				continue

			var is_selected: bool = (
				selected is Dictionary and selected == candidate
			)
			if is_selected:
				# Highlight selected panel with cyan tint
				panel.modulate = Color(0.7, 1.0, 1.0, 1.0)
			elif candidate_digimon.unique_id in selected_ids:
				# Grey out candidates selected for other partner slots
				panel.set_greyed_out(true)
			else:
				panel.modulate = Color(1, 1, 1, 1)
				panel.set_greyed_out(false)


func _update_confirm_state() -> void:
	var all_selected: bool = true
	var selected_count: int = 0
	var total: int = _link.jogress_partner_keys.size()

	for partner_key: StringName in _link.jogress_partner_keys:
		if _selected_partners.get(partner_key) == null:
			all_selected = false
		else:
			selected_count += 1

	_confirm_button.disabled = not all_selected
	_status_label.text = "Selected %d / %d partners" % [selected_count, total]


func _on_confirm_pressed() -> void:
	if _digimon == null or _link == null or Game.state == null:
		return

	# 1. Store each selected partner's serialised state for de-evolution records
	for partner_key: StringName in _link.jogress_partner_keys:
		var candidate: Dictionary = _selected_partners[partner_key] as Dictionary
		var partner: DigimonState = candidate.get("digimon") as DigimonState
		if partner != null:
			_digimon.jogress_partners.append(partner.to_dict())

	# 2. Consume partners — collect removals then execute
	var party_removals: Array[int] = []
	for partner_key: StringName in _link.jogress_partner_keys:
		var candidate: Dictionary = _selected_partners[partner_key] as Dictionary
		var source: String = candidate.get("source", "") as String
		if source == "party":
			party_removals.append(candidate.get("party_index", -1) as int)
		elif source == "storage":
			var box: int = candidate.get("box", -1) as int
			var slot: int = candidate.get("slot", -1) as int
			Game.state.storage.remove_digimon(box, slot)

	# Remove party members in descending index order to avoid index shifts
	party_removals.sort()
	party_removals.reverse()
	for idx: int in party_removals:
		if idx >= 0 and idx < Game.state.party.members.size():
			Game.state.party.members.remove_at(idx)

	# 3. Mutate main Digimon — same logic as evolution_screen._execute_evolution
	var old_data: DigimonData = Atlas.digimon.get(_digimon.key) as DigimonData
	var new_data: DigimonData = Atlas.digimon.get(_link.to_key) as DigimonData
	if new_data == null:
		_status_label.text = "Evolution target not found!"
		return

	var old_key: StringName = _digimon.key
	var old_name: String = old_data.display_name if old_data else str(old_key)

	# Proportional HP/energy scaling
	var old_stats: Dictionary = StatCalculator.calculate_all_stats(old_data, _digimon) \
		if old_data else {}
	var old_max_hp: int = old_stats.get(&"hp", 1) as int
	var old_max_energy: int = old_stats.get(&"energy", 1) as int

	_digimon.key = _link.to_key

	var new_stats: Dictionary = StatCalculator.calculate_all_stats(new_data, _digimon)
	var new_max_hp: int = new_stats.get(&"hp", 1) as int
	var new_max_energy: int = new_stats.get(&"energy", 1) as int

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
	_consume_evolution_items(_link)

	# 4. Build participant keys for animation
	var participant_keys: Array[StringName] = [old_key]
	for partner_key: StringName in _link.jogress_partner_keys:
		var candidate: Dictionary = _selected_partners[partner_key] as Dictionary
		var partner: DigimonState = candidate.get("digimon") as DigimonState
		if partner != null:
			participant_keys.append(partner.key)

	# 5. Navigate to animation screen
	var new_name: String = new_data.display_name
	Game.screen_context = {
		"old_digimon_key": old_key,
		"new_digimon_key": _link.to_key,
		"old_name": old_name,
		"new_name": new_name,
		"mode": _mode,
		"party_index": _party_index,
		"storage_box": _storage_box,
		"storage_slot": _storage_slot,
		"evolution_return_scene": _return_scene,
		"is_jogress": true,
		"participant_keys": participant_keys,
	}
	SceneManager.change_scene(_EVOLUTION_ANIMATION_PATH)


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
	Game.screen_context = {
		"mode": _mode,
		"party_index": _party_index,
		"storage_box": _storage_box,
		"storage_slot": _storage_slot,
		"return_scene": _return_scene,
	}
	SceneManager.change_scene(_EVOLUTION_SCREEN_PATH)
