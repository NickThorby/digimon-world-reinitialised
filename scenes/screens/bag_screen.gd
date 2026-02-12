extends Control
## Bag Screen — view and manage the player's inventory.

const BAG_SCREEN_PATH := "res://scenes/screens/bag_screen.tscn"
const PARTY_SCREEN_PATH := "res://scenes/screens/party_screen.tscn"

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _DETAIL := "MarginContainer/VBox/ContentHBox/DetailPanel/DetailMargin/DetailVBox"
const _ACTIONS := "MarginContainer/VBox/ContentHBox/DetailPanel/DetailMargin/DetailVBox/ActionRow"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _tab_row: HBoxContainer = $MarginContainer/VBox/TabRow
@onready var _item_list_vbox: VBoxContainer = get_node(
	"MarginContainer/VBox/ContentHBox/ItemListPanel/ScrollContainer/ItemListVBox"
)
@onready var _item_name_label: Label = get_node(_DETAIL + "/ItemNameLabel")
@onready var _item_category_label: Label = get_node(_DETAIL + "/ItemCategoryLabel")
@onready var _item_description_label: Label = get_node(_DETAIL + "/ItemDescriptionLabel")
@onready var _buy_price_label: Label = get_node(
	_DETAIL + "/PriceRow/BuyPriceLabel"
)
@onready var _sell_price_label: Label = get_node(
	_DETAIL + "/PriceRow/SellPriceLabel"
)
@onready var _use_button: Button = get_node(_ACTIONS + "/UseButton")
@onready var _give_button: Button = get_node(_ACTIONS + "/GiveButton")
@onready var _toss_button: Button = get_node(_ACTIONS + "/TossButton")
@onready var _bits_label: Label = $MarginContainer/VBox/BottomBar/BitsLabel

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _select_mode: bool = false
var _select_filter: Callable = Callable()
var _select_prompt: String = ""
var _return_scene: String = ""
var _current_category: int = -1  # -1 = All
var _selected_item_key: StringName = &""
var _tab_buttons: Array[Button] = []
var _item_rows: Array[HBoxContainer] = []

const CYAN := Color(0.024, 0.714, 0.831, 1)
const MUTED := Color(0.443, 0.443, 0.478, 1)
const SELECTED_BG := Color(0.1, 0.1, 0.15, 1)


func _ready() -> void:
	_read_context()
	_handle_pending_use()
	_update_header()
	_build_tabs()
	_populate_item_list(_current_category)
	_update_bits_display()
	_clear_detail_panel()
	_connect_signals()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_select_mode = ctx.get("select_mode", false)
	_select_filter = ctx.get("select_filter", Callable())
	_select_prompt = ctx.get("select_prompt", "")
	_return_scene = ctx.get("return_scene", "")
	_current_category = ctx.get("_bag_category", -1)


func _handle_pending_use() -> void:
	var ctx: Dictionary = Game.screen_context
	var pending_key: Variant = ctx.get("_bag_pending_use", null)
	if pending_key == null:
		return

	var result: Variant = Game.screen_result
	if result == null or result is not Dictionary:
		return

	var result_dict: Dictionary = result as Dictionary
	var digimon: Variant = result_dict.get("digimon", null)
	if digimon is DigimonState:
		_apply_medicine(StringName(str(pending_key)), digimon as DigimonState)

	Game.screen_result = null


func _update_header() -> void:
	if _select_mode and _select_prompt != "":
		_title_label.text = _select_prompt
	else:
		_title_label.text = tr("Bag")


func _build_tabs() -> void:
	for child: Node in _tab_row.get_children():
		child.queue_free()
	_tab_buttons.clear()

	# "All" tab
	var all_btn := Button.new()
	all_btn.text = tr("All")
	all_btn.pressed.connect(_on_tab_pressed.bind(-1))
	_tab_row.add_child(all_btn)
	_tab_buttons.append(all_btn)

	# Category tabs
	for category_val: int in Registry.item_category_labels:
		var label_text: String = str(Registry.item_category_labels[category_val])
		var btn := Button.new()
		btn.text = label_text
		btn.pressed.connect(_on_tab_pressed.bind(category_val))
		_tab_row.add_child(btn)
		_tab_buttons.append(btn)

	_update_tab_highlight()


func _update_tab_highlight() -> void:
	for i: int in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var is_active: bool = false
		if i == 0:
			is_active = _current_category == -1
		else:
			# Category tabs start at index 1; value matches the keys
			var cat_keys: Array = Registry.item_category_labels.keys()
			if i - 1 < cat_keys.size():
				is_active = _current_category == cat_keys[i - 1]

		if is_active:
			btn.add_theme_color_override("font_color", CYAN)
		else:
			btn.remove_theme_color_override("font_color")


func _on_tab_pressed(category: int) -> void:
	_current_category = category
	_update_tab_highlight()
	_populate_item_list(category)
	_clear_detail_panel()


func _populate_item_list(category: int) -> void:
	for child: Node in _item_list_vbox.get_children():
		child.queue_free()
	_item_rows.clear()

	if Game.state == null:
		return

	var inventory: Dictionary = Game.state.inventory.items
	var sorted_keys: Array = inventory.keys()
	sorted_keys.sort()

	var any_items: bool = false

	for item_key: Variant in sorted_keys:
		var key: StringName = StringName(str(item_key))
		var quantity: int = inventory[item_key] as int
		if quantity <= 0:
			continue

		var item_data: ItemData = Atlas.items.get(key) as ItemData
		if item_data == null:
			continue

		# Filter by category
		if category >= 0 and item_data.category != category:
			continue

		# Filter by select_filter
		var greyed: bool = false
		if _select_mode and _select_filter.is_valid():
			var passes: bool = _select_filter.call(item_data) as bool
			if not passes:
				greyed = true

		any_items = true
		var row := _create_item_row(key, item_data, quantity, greyed)
		_item_list_vbox.add_child(row)
		_item_rows.append(row)

	if not any_items:
		var empty_label := Label.new()
		empty_label.text = tr("No items")
		empty_label.add_theme_color_override("font_color", MUTED)
		empty_label.add_theme_font_size_override("font_size", 14)
		_item_list_vbox.add_child(empty_label)


func _create_item_row(
	key: StringName,
	item_data: ItemData,
	quantity: int,
	greyed: bool,
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var name_label := Label.new()
	name_label.text = item_data.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var qty_label := Label.new()
	qty_label.text = "x%d" % quantity
	qty_label.add_theme_color_override("font_color", MUTED)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(qty_label)

	if greyed:
		row.modulate.a = 0.4

	row.gui_input.connect(_on_item_row_input.bind(key, greyed))
	return row


func _on_item_row_input(event: InputEvent, key: StringName, greyed: bool) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_item_selected(key, greyed)


func _on_item_selected(key: StringName, greyed: bool) -> void:
	if _select_mode:
		if greyed:
			return
		Game.screen_result = {"item_key": key}
		if _return_scene != "":
			SceneManager.change_scene(_return_scene)
		return

	_selected_item_key = key
	_update_detail_panel(key)


func _clear_detail_panel() -> void:
	_item_name_label.text = ""
	_item_category_label.text = ""
	_item_description_label.text = ""
	_buy_price_label.text = ""
	_sell_price_label.text = ""
	_use_button.visible = false
	_give_button.visible = false
	_toss_button.visible = false
	_selected_item_key = &""


func _update_detail_panel(key: StringName) -> void:
	var item_data: ItemData = Atlas.items.get(key) as ItemData
	if item_data == null:
		_clear_detail_panel()
		return

	_item_name_label.text = item_data.name
	_item_category_label.text = str(
		Registry.item_category_labels.get(item_data.category, "")
	)
	_item_description_label.text = item_data.description
	_buy_price_label.text = "Buy: %d" % item_data.buy_price if item_data.buy_price > 0 else ""
	_sell_price_label.text = "Sell: %d" % item_data.sell_price if item_data.sell_price > 0 else ""

	# Action buttons
	var can_use: bool = item_data.is_consumable and item_data.bricks.size() > 0
	_use_button.visible = true
	_use_button.disabled = not can_use

	_give_button.visible = true
	_give_button.disabled = true
	_give_button.tooltip_text = tr("Coming Soon")

	_toss_button.visible = true
	_toss_button.disabled = false


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_use_button.pressed.connect(_on_use_pressed)
	_toss_button.pressed.connect(_on_toss_pressed)


func _on_back_pressed() -> void:
	if _select_mode:
		Game.screen_result = null
	if _return_scene != "":
		Game.screen_context = {"mode": _mode}
		SceneManager.change_scene(_return_scene)


func _on_use_pressed() -> void:
	if _selected_item_key == &"":
		return
	var item_data: ItemData = Atlas.items.get(_selected_item_key) as ItemData
	if item_data == null:
		return

	# Build the filter for party selection
	var use_filter: Callable
	if item_data.is_revive:
		use_filter = func(d: DigimonState) -> bool: return d.current_hp <= 0
	else:
		use_filter = func(d: DigimonState) -> bool: return d.current_hp > 0

	# Navigate to Party Screen in select mode, persist Bag state for round-trip
	Game.screen_context = {
		"mode": _mode,
		"return_scene": BAG_SCREEN_PATH,
		"select_mode": true,
		"select_prompt": tr("Choose a Digimon"),
		"select_filter": use_filter,
		"_bag_pending_use": _selected_item_key,
		"_bag_category": _current_category,
	}
	SceneManager.change_scene(PARTY_SCREEN_PATH)


func _on_toss_pressed() -> void:
	if _selected_item_key == &"":
		return
	if Game.state == null:
		return

	var quantity: int = Game.state.inventory.items.get(_selected_item_key, 0) as int
	if quantity <= 0:
		return

	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("Toss %s? (x%d)") % [
		_get_item_display_name(_selected_item_key), quantity,
	]
	dialog.confirmed.connect(_on_toss_confirmed.bind(_selected_item_key))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_toss_confirmed(key: StringName) -> void:
	if Game.state == null:
		return

	# Remove all of this item
	if Game.state.inventory.items.has(key):
		Game.state.inventory.items.erase(key)

	_populate_item_list(_current_category)
	_clear_detail_panel()

	# Clean up the dialog
	for child: Node in get_children():
		if child is ConfirmationDialog:
			child.queue_free()


func _get_item_display_name(key: StringName) -> String:
	var item_data: ItemData = Atlas.items.get(key) as ItemData
	if item_data:
		return item_data.name
	return str(key)


func _update_bits_display() -> void:
	if Game.state:
		_bits_label.text = "%s Bits" % FormatUtils.format_bits(Game.state.inventory.bits)
	else:
		_bits_label.text = "0 Bits"


## Apply item bricks to a DigimonState (out-of-battle) and consume on success.
func _apply_medicine(item_key: StringName, digimon: DigimonState) -> void:
	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	if item_data == null:
		return

	var max_stats: Dictionary = ItemApplicator.get_max_stats(digimon)
	var applied: bool = ItemApplicator.apply(
		item_data, digimon, max_stats.max_hp, max_stats.max_energy,
	)

	if applied and Game.state:
		var current_qty: int = Game.state.inventory.items.get(item_key, 0) as int
		if current_qty <= 1:
			Game.state.inventory.items.erase(item_key)
		else:
			Game.state.inventory.items[item_key] = current_qty - 1
