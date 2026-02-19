class_name BattleJogressMenu
extends PanelContainer
## In-battle jogress partner selection overlay.
## Shows eligible partners from the side's party/active slots.


signal partners_confirmed(partner_indices: Array[int])
signal back_pressed()

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _partner_list: VBoxContainer = $VBox/PartnerScroll/PartnerList
@onready var _back_button: Button = $VBox/ButtonHBox/BackButton
@onready var _confirm_button: Button = $VBox/ButtonHBox/ConfirmButton

var _link: EvolutionLinkData = null
var _digimon: DigimonState = null
var _side: SideState = null
## partner_key -> { "selected_index": int, "candidates": Array[Dictionary] }
var _partner_selections: Dictionary = {}


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_confirm_button.pressed.connect(_on_confirm)


## Populate with candidates from the side's reserves and active slots.
func populate(
	link: EvolutionLinkData,
	digimon: DigimonState,
	side: SideState,
) -> void:
	_link = link
	_digimon = digimon
	_side = side
	_partner_selections.clear()

	_title_label.text = "Select Jogress Partners"

	for child: Node in _partner_list.get_children():
		child.queue_free()

	# Build candidate list per partner key using party-only
	var party := PartyState.new()
	party.members = []
	for reserve: DigimonState in side.party:
		party.members.append(reserve)
	# Include active slot Digimon (except the evolving one)
	for slot: SlotState in side.slots:
		if slot.digimon != null and not slot.digimon.is_fainted \
				and slot.digimon.source_state != digimon:
			party.members.append(slot.digimon.source_state)

	var all_candidates: Dictionary = EvolutionChecker.find_jogress_candidates(
		link, digimon, party, null,
	)

	for partner_key: StringName in link.jogress_partner_keys:
		var partner_data: DigimonData = Atlas.digimon.get(partner_key) as DigimonData
		var display_name: String = partner_data.display_name if partner_data \
			else str(partner_key)

		var section_label := Label.new()
		section_label.text = "Partner: %s" % display_name
		section_label.add_theme_font_size_override("font_size", 15)
		_partner_list.add_child(section_label)

		var candidates: Array = all_candidates.get(partner_key, []) as Array
		_partner_selections[partner_key] = {
			"selected_index": -1,
			"candidates": candidates,
		}

		if candidates.is_empty():
			var none_label := Label.new()
			none_label.text = "  No eligible partners"
			none_label.add_theme_color_override(
				"font_color", Color(0.85, 0.3, 0.3, 1),
			)
			none_label.add_theme_font_size_override("font_size", 13)
			_partner_list.add_child(none_label)
		else:
			for i: int in candidates.size():
				var candidate: Dictionary = candidates[i]
				var cand_digimon: DigimonState = candidate.get("digimon") as DigimonState
				if cand_digimon == null:
					continue
				var cand_data: DigimonData = Atlas.digimon.get(
					cand_digimon.key,
				) as DigimonData
				var cand_name: String = cand_data.display_name if cand_data \
					else str(cand_digimon.key)
				var btn := Button.new()
				btn.text = "  %s (Lv. %d)" % [cand_name, cand_digimon.level]
				btn.toggle_mode = true
				btn.pressed.connect(
					_on_candidate_selected.bind(partner_key, i),
				)
				_partner_list.add_child(btn)

		var sep := HSeparator.new()
		_partner_list.add_child(sep)

	_update_confirm_button()


func _on_candidate_selected(partner_key: StringName, index: int) -> void:
	if _partner_selections.has(partner_key):
		_partner_selections[partner_key]["selected_index"] = index
	_update_confirm_button()


func _update_confirm_button() -> void:
	var all_selected: bool = true
	for pkey: StringName in _partner_selections:
		var sel: Dictionary = _partner_selections[pkey]
		if int(sel.get("selected_index", -1)) < 0:
			all_selected = false
			break
	_confirm_button.disabled = not all_selected


func _on_confirm() -> void:
	var indices: Array[int] = []
	for pkey: StringName in _link.jogress_partner_keys:
		var sel: Dictionary = _partner_selections.get(pkey, {})
		var sel_idx: int = int(sel.get("selected_index", -1))
		var candidates: Array = sel.get("candidates", []) as Array
		if sel_idx >= 0 and sel_idx < candidates.size():
			var candidate: Dictionary = candidates[sel_idx]
			# Return party_index for reserve partners, slot_index for active
			var party_idx: int = int(candidate.get("party_index", -1))
			indices.append(party_idx)
	partners_confirmed.emit(indices)
