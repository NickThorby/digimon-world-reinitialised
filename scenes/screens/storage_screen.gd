extends Control
## Storage Screen
##
## Purpose: Manage Digimon storage — deposit, withdraw, move, release.
##
## Context inputs (Game.screen_context):
##   mode: Registry.GameMode — TEST or STORY
##   free_mode: bool — if true, show Add Digimon button (TEST only)
##   return_scene: String — scene to navigate back to
##
## Context outputs (Game.screen_result):
##   None

const SUMMARY_SCREEN_PATH := "res://scenes/screens/summary_screen.tscn"
const STORAGE_SCREEN_PATH := "res://scenes/screens/storage_screen.tscn"
const EVOLUTION_SCREEN_PATH := "res://scenes/screens/evolution_screen.tscn"
const BAG_SCREEN_PATH := "res://scenes/screens/bag_screen.tscn"
const PICKER_SCENE_PATH := "res://scenes/battle/digimon_picker.tscn"
const SLOT_PANEL_SCENE := preload("res://ui/components/digimon_slot_panel.tscn")
const STORAGE_SLOT_SCENE := preload("res://ui/components/storage_slot.tscn")

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _LEFT := "MarginContainer/VBox/ContentHBox/PartyPanel"
const _RIGHT := "MarginContainer/VBox/ContentHBox/BoxPanel"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _party_header: Label = get_node(_LEFT + "/PartyHeader")
@onready var _party_list: VBoxContainer = get_node(_LEFT + "/PartyScroll/PartyList")
@onready var _prev_box_button: Button = get_node(_RIGHT + "/BoxHeader/PrevBoxButton")
@onready var _box_name_label: Label = get_node(_RIGHT + "/BoxHeader/BoxNameLabel")
@onready var _next_box_button: Button = get_node(_RIGHT + "/BoxHeader/NextBoxButton")
@onready var _box_grid: GridContainer = get_node(_RIGHT + "/BoxScroll/BoxGrid")
@onready var _add_button: Button = $MarginContainer/VBox/BottomBar/AddButton
@onready var _status_label: Label = $MarginContainer/VBox/BottomBar/StatusLabel

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _free_mode: bool = false
var _return_scene: String = ""
var _current_box: int = 0
var _box_count: int = 100

## Move mode state
var _move_source: Dictionary = {}  ## { "type": "party"/"box", "index"/"box"/"slot": ... }
var _is_moving: bool = false


func _ready() -> void:
	_read_context()

	if Game.state == null:
		return

	_handle_picker_return()

	_box_count = Game.state.storage.get_box_count()

	_update_party_panel()
	_update_box_panel()
	_configure_bottom_bar()
	_connect_signals()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_free_mode = ctx.get("free_mode", false)
	_return_scene = ctx.get("return_scene", "")


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_prev_box_button.pressed.connect(_on_prev_box)
	_next_box_button.pressed.connect(_on_next_box)
	_add_button.pressed.connect(_on_add_pressed)


func _configure_bottom_bar() -> void:
	_add_button.visible = _free_mode
	_status_label.text = ""


# --- Party panel ---


func _update_party_panel() -> void:
	for child: Node in _party_list.get_children():
		child.queue_free()

	if Game.state == null:
		return

	var members: Array[DigimonState] = Game.state.party.members
	_party_header.text = "Party (%d/6)" % members.size()

	for i: int in members.size():
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var data: DigimonData = Atlas.digimon.get(members[i].key) as DigimonData
		var name_text: String = data.display_name if data else str(members[i].key)
		btn.text = "%s Lv.%d" % [name_text, members[i].level]
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_party_slot_clicked.bind(i))
		if _is_moving and _move_source.get("type") == "party" \
				and _move_source.get("index") == i:
			btn.modulate = Color(0.024, 0.714, 0.831, 1)
		_party_list.add_child(btn)


# --- Box panel ---


func _update_box_panel() -> void:
	for child: Node in _box_grid.get_children():
		child.queue_free()

	if Game.state == null:
		return

	var storage: StorageState = Game.state.storage
	var box: Dictionary = storage.boxes[_current_box]
	var occupied: int = storage.get_box_occupied_count(_current_box)
	var slots: Array = box["slots"]
	_box_name_label.text = "%s (%d/%d)" % [box["name"], occupied, slots.size()]

	for slot_i: int in slots.size():
		var slot: StorageSlot = STORAGE_SLOT_SCENE.instantiate() as StorageSlot
		_box_grid.add_child(slot)
		slot.setup(_current_box, slot_i, slots[slot_i] as DigimonState)
		slot.slot_clicked.connect(_on_box_slot_clicked)
		if _is_moving and _move_source.get("type") == "box" \
				and _move_source.get("box") == _current_box \
				and _move_source.get("slot") == slot_i:
			slot.modulate = Color(0.024, 0.714, 0.831, 1)


# --- Box navigation ---


func _on_prev_box() -> void:
	_current_box -= 1
	if _current_box < 0:
		_current_box = _box_count - 1
	_update_box_panel()


func _on_next_box() -> void:
	_current_box += 1
	if _current_box >= _box_count:
		_current_box = 0
	_update_box_panel()


# --- Click handlers ---


func _on_party_slot_clicked(index: int) -> void:
	if Game.state == null:
		return

	if _is_moving:
		_complete_move_to_party(index)
		return

	_show_party_context_menu(index)


func _on_box_slot_clicked(box_index: int, slot_index: int) -> void:
	if Game.state == null:
		return

	if _is_moving:
		_complete_move_to_box(box_index, slot_index)
		return

	var digimon: DigimonState = Game.state.storage.get_digimon(box_index, slot_index)
	if digimon != null:
		_show_box_context_menu(box_index, slot_index, digimon)


# --- Context menus ---


func _show_party_context_menu(index: int) -> void:
	var popup := PopupMenu.new()
	popup.add_item("Summary", 0)
	popup.add_separator()
	popup.add_item("Move", 1)
	popup.add_separator()
	popup.add_item("Release", 2)
	# Guard: cannot release last party member
	if Game.state.party.members.size() <= 1:
		popup.set_item_disabled(popup.get_item_index(2), true)
		popup.set_item_tooltip(popup.get_item_index(2), "Cannot release last party member")

	add_child(popup)
	popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _navigate_to_summary_party(index)
			1: _start_move_from_party(index)
			2: _confirm_release_party(index)
		popup.queue_free()
	)
	popup.position = Vector2i(
		int(get_viewport().get_mouse_position().x),
		int(get_viewport().get_mouse_position().y),
	)
	popup.popup()


func _show_box_context_menu(
	box_index: int, slot_index: int, _digimon: DigimonState,
) -> void:
	var popup := PopupMenu.new()
	popup.add_item("Summary", 0)
	popup.add_separator()
	popup.add_item("Move", 1)
	popup.add_separator()
	popup.add_item("Release", 2)

	add_child(popup)
	popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _navigate_to_summary_box(box_index, slot_index)
			1: _start_move_from_box(box_index, slot_index)
			2: _confirm_release_box(box_index, slot_index)
		popup.queue_free()
	)
	popup.position = Vector2i(
		int(get_viewport().get_mouse_position().x),
		int(get_viewport().get_mouse_position().y),
	)
	popup.popup()


# --- Move mode ---


func _start_move_from_party(index: int) -> void:
	_is_moving = true
	_move_source = {"type": "party", "index": index}
	_status_label.text = "Select destination..."
	_update_party_panel()
	_update_box_panel()


func _start_move_from_box(box_index: int, slot_index: int) -> void:
	_is_moving = true
	_move_source = {"type": "box", "box": box_index, "slot": slot_index}
	_status_label.text = "Select destination..."
	_update_party_panel()
	_update_box_panel()


func _complete_move_to_party(target_index: int) -> void:
	if _move_source.get("type") == "party":
		# Swap within party
		var from_idx: int = _move_source.get("index", -1)
		if from_idx != target_index:
			var temp: DigimonState = Game.state.party.members[from_idx]
			Game.state.party.members[from_idx] = Game.state.party.members[target_index]
			Game.state.party.members[target_index] = temp
	elif _move_source.get("type") == "box":
		# Withdraw from box to party
		if Game.state.party.members.size() >= 6:
			_status_label.text = "Party is full!"
			_cancel_move()
			return
		var box_i: int = _move_source.get("box", 0)
		var slot_i: int = _move_source.get("slot", 0)
		var digimon: DigimonState = Game.state.storage.remove_digimon(box_i, slot_i)
		if digimon != null:
			Game.state.party.members.append(digimon)

	_cancel_move()


func _complete_move_to_box(box_index: int, slot_index: int) -> void:
	var target_digimon: DigimonState = Game.state.storage.get_digimon(
		box_index, slot_index,
	)

	if _move_source.get("type") == "party":
		# Deposit to box (guard: party must have >= 2)
		var from_idx: int = _move_source.get("index", -1)
		if target_digimon == null and Game.state.party.members.size() <= 1:
			_status_label.text = "Cannot deposit last party member!"
			_cancel_move()
			return
		var depositing: DigimonState = Game.state.party.members[from_idx]
		if target_digimon != null:
			# Swap party <-> box
			Game.state.party.members[from_idx] = target_digimon
			Game.state.storage.set_digimon(box_index, slot_index, depositing)
		else:
			# Deposit only
			Game.state.party.members.remove_at(from_idx)
			Game.state.storage.set_digimon(box_index, slot_index, depositing)
	elif _move_source.get("type") == "box":
		# Swap within box / across boxes
		var src_box: int = _move_source.get("box", 0)
		var src_slot: int = _move_source.get("slot", 0)
		if src_box == box_index and src_slot == slot_index:
			_cancel_move()
			return
		Game.state.storage.swap_digimon(src_box, src_slot, box_index, slot_index)

	_cancel_move()


func _cancel_move() -> void:
	_is_moving = false
	_move_source = {}
	_status_label.text = ""
	_update_party_panel()
	_update_box_panel()


# --- Release ---


func _confirm_release_party(index: int) -> void:
	if Game.state.party.members.size() <= 1:
		_status_label.text = "Cannot release last party member!"
		return

	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Release this Digimon permanently?"
	dialog.ok_button_text = "Release"
	dialog.confirmed.connect(func() -> void:
		Game.state.party.members.remove_at(index)
		_update_party_panel()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _confirm_release_box(box_index: int, slot_index: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Release this Digimon permanently?"
	dialog.ok_button_text = "Release"
	dialog.confirmed.connect(func() -> void:
		Game.state.storage.set_digimon(box_index, slot_index, null)
		_update_box_panel()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


# --- Navigation ---


func _navigate_to_summary_party(index: int) -> void:
	if index < 0 or index >= Game.state.party.members.size():
		return
	Game.screen_context = {
		"digimon": Game.state.party.members[index],
		"party_index": index,
		"editable": false,
		"return_scene": STORAGE_SCREEN_PATH,
		"mode": _mode,
	}
	SceneManager.change_scene(SUMMARY_SCREEN_PATH)


func _navigate_to_summary_box(box_index: int, slot_index: int) -> void:
	var digimon: DigimonState = Game.state.storage.get_digimon(box_index, slot_index)
	if digimon == null:
		return
	Game.screen_context = {
		"digimon": digimon,
		"editable": false,
		"return_scene": STORAGE_SCREEN_PATH,
		"mode": _mode,
	}
	SceneManager.change_scene(SUMMARY_SCREEN_PATH)


func _handle_picker_return() -> void:
	if Game.picker_context.is_empty():
		return

	_current_box = Game.picker_context.get("current_box", 0) as int

	if Game.picker_result is DigimonState:
		var digimon: DigimonState = Game.picker_result as DigimonState
		var slot_info: Dictionary = Game.state.storage.find_first_empty_slot()
		if not slot_info.is_empty():
			Game.state.storage.set_digimon(
				slot_info["box"], slot_info["slot"], digimon,
			)
			_current_box = slot_info["box"] as int

	Game.picker_context = {}
	Game.picker_result = null


func _on_add_pressed() -> void:
	if not _free_mode or Game.state == null:
		return
	var slot_info: Dictionary = Game.state.storage.find_first_empty_slot()
	if slot_info.is_empty():
		_status_label.text = "Storage is full!"
		return
	Game.screen_context = {
		"mode": _mode,
		"free_mode": _free_mode,
		"return_scene": _return_scene,
	}
	Game.picker_context = {
		"return_scene": STORAGE_SCREEN_PATH,
		"current_box": _current_box,
	}
	SceneManager.change_scene(PICKER_SCENE_PATH)


func _on_back_pressed() -> void:
	if _is_moving:
		_cancel_move()
		return
	if _return_scene != "":
		Game.screen_context = {"mode": _mode}
		SceneManager.change_scene(_return_scene)
