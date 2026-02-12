extends Control
## Party Screen — view and manage the player's active party.

const PARTY_SCREEN_PATH := "res://scenes/screens/party_screen.tscn"
const SUMMARY_SCREEN_PATH := "res://scenes/screens/summary_screen.tscn"
const BAG_SCREEN_PATH := "res://scenes/screens/bag_screen.tscn"
const EVOLUTION_SCREEN_PATH := "res://scenes/screens/evolution_screen.tscn"
const SLOT_PANEL_SCENE := preload("res://ui/components/digimon_slot_panel.tscn")

const _HEADER := "MarginContainer/VBox/HeaderBar"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _slot_list: VBoxContainer = $MarginContainer/VBox/ScrollContainer/SlotList

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _select_mode: bool = false
var _select_filter: Callable = Callable()
var _select_prompt: String = ""
var _return_scene: String = ""
var _swap_from_index: int = -1
var _panels: Array[DigimonSlotPanel] = []


func _ready() -> void:
	_read_context()
	_update_header()
	_build_slot_list()
	_connect_signals()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_select_mode = ctx.get("select_mode", false)
	_select_filter = ctx.get("select_filter", Callable())
	_select_prompt = ctx.get("select_prompt", "")
	_return_scene = ctx.get("return_scene", "")


func _update_header() -> void:
	if _select_mode and _select_prompt != "":
		_title_label.text = _select_prompt
	else:
		_title_label.text = tr("Party")


func _build_slot_list() -> void:
	for child: Node in _slot_list.get_children():
		child.queue_free()
	_panels.clear()

	if Game.state == null or Game.state.party.members.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("No Digimon in party")
		empty_label.add_theme_color_override(
			"font_color", Color(0.443, 0.443, 0.478, 1)
		)
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slot_list.add_child(empty_label)
		return

	for i: int in Game.state.party.members.size():
		var member: DigimonState = Game.state.party.members[i]
		var panel: DigimonSlotPanel = SLOT_PANEL_SCENE.instantiate() as DigimonSlotPanel
		_slot_list.add_child(panel)
		panel.set_button_mode(DigimonSlotPanel.ButtonMode.CONTEXT_MENU)
		panel.set_sprite_flipped(true)
		panel.setup(i, member)

		if _select_mode and _select_filter.is_valid():
			var passes: bool = _select_filter.call(member) as bool
			if not passes:
				panel.set_greyed_out(true)

		panel.slot_clicked.connect(_on_slot_clicked)
		panel.reorder_requested.connect(_on_reorder_requested)
		_panels.append(panel)


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	if _swap_from_index >= 0:
		_cancel_swap()
		return

	if _select_mode:
		Game.screen_result = null

	if _return_scene != "":
		Game.screen_context = {"mode": _mode}
		SceneManager.change_scene(_return_scene)


func _on_slot_clicked(index: int) -> void:
	if Game.state == null:
		return
	if index < 0 or index >= Game.state.party.members.size():
		return

	var member: DigimonState = Game.state.party.members[index]

	# Swap mode — complete the swap
	if _swap_from_index >= 0:
		_complete_swap(index)
		return

	# Select mode — return selection
	if _select_mode:
		if _select_filter.is_valid():
			var passes: bool = _select_filter.call(member) as bool
			if not passes:
				return
		Game.screen_result = {"party_index": index, "digimon": member}
		if _return_scene != "":
			SceneManager.change_scene(_return_scene)
		return

	# Normal mode — show context menu
	_show_context_menu(index)


func _show_context_menu(index: int) -> void:
	var popup := PopupMenu.new()
	popup.add_item(tr("Summary"), 0)
	popup.add_separator()

	# Item submenu
	var member: DigimonState = Game.state.party.members[index]
	var item_submenu := PopupMenu.new()
	item_submenu.name = "ItemSubmenu"

	var has_gear: bool = member.equipped_gear_key != &""
	var has_consumable: bool = member.equipped_consumable_key != &""

	item_submenu.add_item(tr("Take Gear"), 0)
	item_submenu.set_item_disabled(0, not has_gear)
	item_submenu.add_item(tr("Take Consumable"), 1)
	item_submenu.set_item_disabled(1, not has_consumable)
	item_submenu.add_separator()
	item_submenu.add_item(tr("Give Item"), 2)

	popup.add_child(item_submenu)
	popup.add_submenu_node_item(tr("Item"), item_submenu, 1)

	popup.add_separator()
	popup.add_item(tr("Switch"), 2)
	popup.add_separator()
	popup.add_item(tr("Evolution"), 3)

	add_child(popup)

	popup.id_pressed.connect(
		func(id: int) -> void:
			_on_context_menu_selected(index, id)
			popup.queue_free()
	)
	item_submenu.id_pressed.connect(
		func(id: int) -> void:
			_on_item_submenu_selected(index, id)
			popup.queue_free()
	)

	# Position near the clicked panel
	if index < _panels.size():
		var panel_rect: Rect2 = _panels[index].get_global_rect()
		popup.position = Vector2i(
			int(panel_rect.position.x + panel_rect.size.x),
			int(panel_rect.position.y),
		)
	popup.popup()


func _on_context_menu_selected(index: int, id: int) -> void:
	match id:
		0:  # Summary
			_navigate_to_summary(index)
		2:  # Switch
			_start_swap(index)
		3:  # Evolution
			_navigate_to_evolution(index)


func _on_item_submenu_selected(index: int, id: int) -> void:
	if Game.state == null:
		return
	if index < 0 or index >= Game.state.party.members.size():
		return

	var member: DigimonState = Game.state.party.members[index]

	match id:
		0:  # Take Gear
			if member.equipped_gear_key != &"":
				var gear_key: StringName = member.equipped_gear_key
				member.equipped_gear_key = &""
				_add_item_to_inventory(gear_key)
				_build_slot_list()
		1:  # Take Consumable
			if member.equipped_consumable_key != &"":
				var consumable_key: StringName = member.equipped_consumable_key
				member.equipped_consumable_key = &""
				_add_item_to_inventory(consumable_key)
				_build_slot_list()
		2:  # Give Item
			_navigate_to_give_item(index)


func _add_item_to_inventory(item_key: StringName) -> void:
	if Game.state == null:
		return
	var current: int = Game.state.inventory.items.get(item_key, 0) as int
	Game.state.inventory.items[item_key] = current + 1


func _navigate_to_summary(index: int) -> void:
	if Game.state == null:
		return
	if index < 0 or index >= Game.state.party.members.size():
		return

	Game.screen_context = {
		"digimon": Game.state.party.members[index],
		"party_index": index,
		"editable": true,
		"party_navigation": true,
		"return_scene": PARTY_SCREEN_PATH,
		"mode": _mode,
	}
	SceneManager.change_scene(SUMMARY_SCREEN_PATH)


func _start_swap(index: int) -> void:
	_swap_from_index = index
	_title_label.text = tr("Select Digimon to switch with")
	# Highlight the source panel
	for i: int in _panels.size():
		if i == index:
			_panels[i].modulate = Color(0.024, 0.714, 0.831, 1)
		else:
			_panels[i].modulate = Color.WHITE


func _complete_swap(target_index: int) -> void:
	if Game.state == null:
		return
	if _swap_from_index == target_index:
		_cancel_swap()
		return

	var members: Array[DigimonState] = Game.state.party.members
	if _swap_from_index < members.size() and target_index < members.size():
		var temp: DigimonState = members[_swap_from_index]
		members[_swap_from_index] = members[target_index]
		members[target_index] = temp

	_swap_from_index = -1
	_title_label.text = tr("Party")
	_build_slot_list()


func _cancel_swap() -> void:
	_swap_from_index = -1
	_title_label.text = tr("Party")
	for panel: DigimonSlotPanel in _panels:
		panel.modulate = Color.WHITE


func _on_reorder_requested(from_index: int, to_index: int) -> void:
	if Game.state == null:
		return
	var members: Array[DigimonState] = Game.state.party.members
	if from_index < 0 or from_index >= members.size():
		return
	if to_index < 0 or to_index >= members.size():
		return
	if from_index == to_index:
		return

	var temp: DigimonState = members[from_index]
	members[from_index] = members[to_index]
	members[to_index] = temp
	_build_slot_list()


func _navigate_to_evolution(index: int) -> void:
	if Game.state == null:
		return
	if index < 0 or index >= Game.state.party.members.size():
		return
	Game.screen_context = {
		"party_index": index,
		"storage_box": -1,
		"storage_slot": -1,
		"mode": _mode,
		"return_scene": PARTY_SCREEN_PATH,
	}
	SceneManager.change_scene(EVOLUTION_SCREEN_PATH)


func _navigate_to_give_item(index: int) -> void:
	if Game.state == null:
		return
	if index < 0 or index >= Game.state.party.members.size():
		return
	Game.screen_context = {
		"mode": _mode,
		"select_mode": true,
		"select_prompt": "Select item to give",
		"return_scene": PARTY_SCREEN_PATH,
		"give_to_index": index,
	}
	SceneManager.change_scene(BAG_SCREEN_PATH)
