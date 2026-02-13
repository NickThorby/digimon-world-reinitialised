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
@onready var _message_box: PanelContainer = $MarginContainer/VBox/MessageBox

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _select_mode: bool = false
var _select_filter: Callable = Callable()
var _select_prompt: String = ""
var _return_scene: String = ""
var _cancel_scene: String = ""
var _swap_from_index: int = -1
var _panels: Array[DigimonSlotPanel] = []
var _use_item_mode: bool = false
var _give_item_mode: bool = false
var _item_key: StringName = &""
var _bag_category: int = -1
var _bag_return_scene: String = ""
var _is_busy: bool = false


func _ready() -> void:
	_read_context()
	_handle_pending_give()
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
	_cancel_scene = ctx.get("cancel_scene", "")
	_use_item_mode = ctx.get("use_item_mode", false)
	_give_item_mode = ctx.get("give_item_mode", false)
	_item_key = StringName(str(ctx.get("item_key", "")))
	_bag_category = ctx.get("_bag_category", -1) as int
	_bag_return_scene = ctx.get("_bag_return_scene", "") as String


func _update_header() -> void:
	if _use_item_mode and _item_key != &"":
		var item_name: String = _get_item_display_name(_item_key)
		_title_label.text = "Use %s on which Digimon?" % item_name
	elif _give_item_mode and _item_key != &"":
		var item_name: String = _get_item_display_name(_item_key)
		_title_label.text = "Give %s to which Digimon?" % item_name
	elif _select_mode and _select_prompt != "":
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

	var show_energy: bool = _use_item_mode and _should_show_energy_bar()

	for i: int in Game.state.party.members.size():
		var member: DigimonState = Game.state.party.members[i]
		var panel: DigimonSlotPanel = SLOT_PANEL_SCENE.instantiate() as DigimonSlotPanel
		_slot_list.add_child(panel)
		panel.set_button_mode(DigimonSlotPanel.ButtonMode.CONTEXT_MENU)
		panel.set_sprite_flipped(true)
		panel.setup(i, member)

		if show_energy:
			panel.set_energy_bar_visible(true)

		# Grey out based on filter in select/use_item modes
		if (_select_mode or _use_item_mode) and _select_filter.is_valid():
			var passes: bool = _select_filter.call(member) as bool
			if not passes:
				panel.set_greyed_out(true)

		panel.slot_clicked.connect(_on_slot_clicked)
		panel.reorder_requested.connect(_on_reorder_requested)
		_panels.append(panel)


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	if _is_busy:
		return

	if _swap_from_index >= 0:
		_cancel_swap()
		return

	if _use_item_mode or _give_item_mode:
		_navigate_back_to_bag()
		return

	if _select_mode:
		Game.screen_result = null

	var target: String
	if _select_mode and _cancel_scene != "":
		target = _cancel_scene
	elif _return_scene != "":
		target = _return_scene
	else:
		target = "res://scenes/screens/mode_screen.tscn"
	Game.screen_context = {"mode": _mode}
	SceneManager.change_scene(target)


func _on_slot_clicked(index: int) -> void:
	if _is_busy:
		return
	if Game.state == null:
		return
	if index < 0 or index >= Game.state.party.members.size():
		return

	var member: DigimonState = Game.state.party.members[index]

	# Swap mode — complete the swap
	if _swap_from_index >= 0:
		_complete_swap(index)
		return

	# Use item mode
	if _use_item_mode:
		_handle_use_item(index, member)
		return

	# Give item mode
	if _give_item_mode:
		_handle_give_item(index, member)
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


func _handle_use_item(index: int, member: DigimonState) -> void:
	# Check filter
	if _select_filter.is_valid():
		var passes: bool = _select_filter.call(member) as bool
		if not passes:
			return

	_is_busy = true

	var item_data: ItemData = Atlas.items.get(_item_key) as ItemData
	if item_data == null:
		_is_busy = false
		return

	# Snapshot before
	var before: Dictionary = ItemMessageBuilder.snapshot(member)

	# Get max stats and apply
	var max_stats: Dictionary = ItemApplicator.get_max_stats(member)
	var applied: bool = ItemApplicator.apply(
		item_data, member, max_stats.max_hp, max_stats.max_energy,
	)

	# Consume from inventory if applied
	if applied and Game.state:
		var current_qty: int = Game.state.inventory.items.get(_item_key, 0) as int
		if current_qty <= 1:
			Game.state.inventory.items.erase(_item_key)
		else:
			Game.state.inventory.items[_item_key] = current_qty - 1

	# Build message
	var digimon_name: String = _get_digimon_display_name(member)
	var item_name: String = item_data.name if item_data.name != "" else str(_item_key)
	var message: String = ItemMessageBuilder.build_message(
		digimon_name, item_name, before, member, applied,
	)

	# Animate bars on the clicked panel
	if index < _panels.size():
		var panel: DigimonSlotPanel = _panels[index]
		if member.current_hp != before.get("current_hp", 0):
			panel.animate_hp_to(member.current_hp)
		if member.current_energy != before.get("current_energy", 0):
			panel.animate_energy_to(member.current_energy)

	# Show message
	_message_box.visible = true
	await _message_box.show_message(message)
	_message_box.visible = false

	# Refresh panel display (status, etc.)
	if index < _panels.size():
		_panels[index].refresh_display()

	# Check if stack remains and item was applied
	var remaining: int = 0
	if Game.state:
		remaining = Game.state.inventory.items.get(_item_key, 0) as int

	if applied and remaining > 0:
		# Stay on party screen for repeated use
		_is_busy = false
	else:
		_navigate_back_to_bag()


func _handle_give_item(index: int, member: DigimonState) -> void:
	_is_busy = true

	var item_data: ItemData = Atlas.items.get(_item_key) as ItemData
	if item_data == null:
		_is_busy = false
		return

	var digimon_name: String = _get_digimon_display_name(member)
	var item_name: String = item_data.name if item_data.name != "" else str(_item_key)

	# Reject if already holding the same item
	var already_held: bool = false
	if item_data.is_consumable:
		already_held = member.equipped_consumable_key == _item_key
	else:
		already_held = member.equipped_gear_key == _item_key

	if already_held:
		_message_box.visible = true
		await _message_box.show_message(
			"%s is already holding a %s." % [digimon_name, item_name],
		)
		_message_box.visible = false
		_is_busy = false
		return

	# Return old item to inventory if slot was occupied
	if item_data.is_consumable:
		if member.equipped_consumable_key != &"":
			_add_item_to_inventory(member.equipped_consumable_key)
		member.equipped_consumable_key = _item_key
	else:
		if member.equipped_gear_key != &"":
			_add_item_to_inventory(member.equipped_gear_key)
		member.equipped_gear_key = _item_key

	# Remove item from inventory
	if Game.state:
		var current_qty: int = Game.state.inventory.items.get(_item_key, 0) as int
		if current_qty <= 1:
			Game.state.inventory.items.erase(_item_key)
		else:
			Game.state.inventory.items[_item_key] = current_qty - 1

	# Show message
	_message_box.visible = true
	await _message_box.show_message("Gave %s to %s!" % [item_name, digimon_name])
	_message_box.visible = false

	_navigate_back_to_bag()


func _navigate_back_to_bag() -> void:
	Game.screen_context = {
		"mode": _mode,
		"_bag_category": _bag_category,
		"return_scene": _bag_return_scene,
	}
	SceneManager.change_scene(BAG_SCREEN_PATH)


func _get_digimon_display_name(member: DigimonState) -> String:
	if member.nickname != "":
		return member.nickname
	var data: DigimonData = Atlas.digimon.get(member.key) as DigimonData
	if data and data.display_name != "":
		return data.display_name
	return str(member.key)


func _get_item_display_name(key: StringName) -> String:
	var item_data: ItemData = Atlas.items.get(key) as ItemData
	if item_data and item_data.name != "":
		return item_data.name
	return str(key)


func _should_show_energy_bar() -> bool:
	var item_data: ItemData = Atlas.items.get(_item_key) as ItemData
	if item_data == null:
		return false
	for brick: Dictionary in item_data.bricks:
		var target: String = str(brick.get("target", ""))
		var brick_type: String = str(brick.get("type", ""))
		if target == "energy" or brick_type == "full_restore":
			return true
	return false


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
		"party_return_scene": _return_scene,
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


func _handle_pending_give() -> void:
	var ctx: Dictionary = Game.screen_context
	var give_to_index: int = ctx.get("give_to_index", -1) as int
	if give_to_index < 0:
		return

	# Returning from bag — always exit select mode and restore return scene
	_select_mode = false
	_return_scene = ctx.get("_party_return_scene", "") as String

	var result: Variant = Game.screen_result
	Game.screen_result = null
	if result == null or result is not Dictionary:
		return

	var result_dict: Dictionary = result as Dictionary
	var item_key: StringName = StringName(str(result_dict.get("item_key", "")))
	if item_key == &"":
		return

	if Game.state == null:
		return
	if give_to_index >= Game.state.party.members.size():
		return

	var member: DigimonState = Game.state.party.members[give_to_index]
	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	if item_data == null:
		return

	# Skip if already holding the same item
	if item_data.is_consumable and member.equipped_consumable_key == item_key:
		return
	if not item_data.is_consumable and member.equipped_gear_key == item_key:
		return

	# Return old item to inventory if slot was occupied
	if item_data.is_consumable:
		if member.equipped_consumable_key != &"":
			_add_item_to_inventory(member.equipped_consumable_key)
		member.equipped_consumable_key = item_key
	else:
		if member.equipped_gear_key != &"":
			_add_item_to_inventory(member.equipped_gear_key)
		member.equipped_gear_key = item_key

	# Remove item from inventory
	var current_qty: int = Game.state.inventory.items.get(item_key, 0) as int
	if current_qty <= 1:
		Game.state.inventory.items.erase(item_key)
	else:
		Game.state.inventory.items[item_key] = current_qty - 1


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
		"_party_return_scene": _return_scene,
	}
	SceneManager.change_scene(BAG_SCREEN_PATH)
