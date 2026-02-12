extends Control
## Shop Screen
##
## Purpose: Buy and sell items from a shop.
##
## Context inputs (Game.screen_context):
##   shop_key: StringName — key for the shop in Atlas.shops (or &"test_shop")
##   mode: Registry.GameMode — TEST or STORY
##   return_scene: String — scene to navigate back to
##
## Context outputs (Game.screen_result):
##   None

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _CONTENT := "MarginContainer/VBox/ContentHBox"
const _DETAIL := "MarginContainer/VBox/ContentHBox/DetailPanel"
const _QTY := "MarginContainer/VBox/ContentHBox/DetailPanel/QuantityRow"

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _title_label: Label = get_node(_HEADER + "/TitleLabel")
@onready var _bits_label: Label = get_node(_HEADER + "/BitsLabel")
@onready var _buy_tab: Button = $MarginContainer/VBox/TabRow/BuyTab
@onready var _sell_tab: Button = $MarginContainer/VBox/TabRow/SellTab
@onready var _item_list: VBoxContainer = get_node(
	_CONTENT + "/ItemListPanel/ItemListScroll/ItemList"
)
@onready var _item_name_label: Label = get_node(_DETAIL + "/ItemNameLabel")
@onready var _item_desc_label: Label = get_node(_DETAIL + "/ItemDescLabel")
@onready var _price_label: Label = get_node(_DETAIL + "/PriceLabel")
@onready var _qty_minus: Button = get_node(_QTY + "/QuantityMinus")
@onready var _qty_value: Label = get_node(_QTY + "/QuantityValue")
@onready var _qty_plus: Button = get_node(_QTY + "/QuantityPlus")
@onready var _total_label: Label = get_node(_QTY + "/TotalLabel")
@onready var _action_button: Button = get_node(_DETAIL + "/ActionButton")

var _mode: Registry.GameMode = Registry.GameMode.TEST
var _return_scene: String = ""
var _shop_key: StringName = &""
var _shop: ShopData = null
var _is_buying: bool = true
var _selected_item_key: StringName = &""
var _quantity: int = 1

## Buy tab item keys in display order (parallel to button list).
var _buy_item_keys: Array[StringName] = []
## Sell tab item keys in display order.
var _sell_item_keys: Array[StringName] = []


func _ready() -> void:
	_read_context()
	_load_shop()
	_update_bits_label()
	_configure_tabs()
	_build_buy_list()
	_clear_detail()
	_connect_signals()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_return_scene = ctx.get("return_scene", "")
	_shop_key = ctx.get("shop_key", &"") as StringName


func _load_shop() -> void:
	if _shop_key == &"test_shop":
		_shop = _build_test_shop()
	else:
		_shop = Atlas.shops.get(_shop_key) as ShopData
	if _shop:
		_title_label.text = _shop.name
	else:
		_title_label.text = "Shop"


func _build_test_shop() -> ShopData:
	var shop := ShopData.new()
	shop.key = &"test_shop"
	shop.name = "Test Shop"
	shop.buy_multiplier = 1.0
	shop.sell_multiplier = 0.5
	var stock: Array[Dictionary] = []
	for item_key: StringName in Atlas.items:
		stock.append({"item_key": item_key, "price": 0, "quantity": -1})
	shop.stock = stock
	return shop


func _update_bits_label() -> void:
	if Game.state:
		_bits_label.text = "%s Bits" % FormatUtils.format_bits(
			Game.state.inventory.bits
		)
	else:
		_bits_label.text = "0 Bits"


func _configure_tabs() -> void:
	_is_buying = true
	_buy_tab.button_pressed = true
	_sell_tab.button_pressed = false


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_buy_tab.pressed.connect(_on_buy_tab)
	_sell_tab.pressed.connect(_on_sell_tab)
	_qty_minus.pressed.connect(_on_qty_minus)
	_qty_plus.pressed.connect(_on_qty_plus)
	_action_button.pressed.connect(_on_action_pressed)


func _on_back_pressed() -> void:
	if _return_scene != "":
		Game.screen_context = {"mode": _mode}
		SceneManager.change_scene(_return_scene)


func _on_buy_tab() -> void:
	_is_buying = true
	_buy_tab.button_pressed = true
	_sell_tab.button_pressed = false
	_build_buy_list()
	_clear_detail()


func _on_sell_tab() -> void:
	_is_buying = false
	_buy_tab.button_pressed = false
	_sell_tab.button_pressed = true
	_build_sell_list()
	_clear_detail()


# --- Buy list ---


func _build_buy_list() -> void:
	_clear_item_list()
	_buy_item_keys.clear()

	if _shop == null:
		return

	for stock_entry: Dictionary in _shop.stock:
		var item_key: StringName = stock_entry.get("item_key", &"") as StringName
		var item_data: ItemData = Atlas.items.get(item_key) as ItemData
		if item_data == null:
			continue
		var price: int = _get_buy_price(stock_entry, item_data)
		_buy_item_keys.append(item_key)
		_add_item_button(item_data.name, price, _buy_item_keys.size() - 1)


func _get_buy_price(stock_entry: Dictionary, item_data: ItemData) -> int:
	var stock_price: int = stock_entry.get("price", 0)
	if stock_price > 0:
		return stock_price
	return floori(item_data.buy_price * _shop.buy_multiplier)


# --- Sell list ---


func _build_sell_list() -> void:
	_clear_item_list()
	_sell_item_keys.clear()

	if Game.state == null:
		return

	for item_key: StringName in Game.state.inventory.items:
		var quantity: int = Game.state.inventory.items[item_key] as int
		if quantity <= 0:
			continue
		var item_data: ItemData = Atlas.items.get(item_key) as ItemData
		if item_data == null:
			continue
		# Exclude KEY items from selling
		if item_data.category == Registry.ItemCategory.KEY:
			continue
		var sell_price: int = _get_sell_price(item_data)
		_sell_item_keys.append(item_key)
		_add_item_button(
			"%s (x%d)" % [item_data.name, quantity],
			sell_price,
			_sell_item_keys.size() - 1,
		)


func _get_sell_price(item_data: ItemData) -> int:
	if item_data.sell_price > 0:
		return item_data.sell_price
	return floori(item_data.buy_price * _shop.sell_multiplier)


# --- Item list helpers ---


func _clear_item_list() -> void:
	for child: Node in _item_list.get_children():
		child.queue_free()


func _add_item_button(display_name: String, price: int, index: int) -> void:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "%s — %d Bits" % [display_name, price] if price > 0 else display_name
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_item_selected.bind(index))
	_item_list.add_child(btn)


func _on_item_selected(index: int) -> void:
	_quantity = 1
	if _is_buying:
		if index < 0 or index >= _buy_item_keys.size():
			return
		_selected_item_key = _buy_item_keys[index]
	else:
		if index < 0 or index >= _sell_item_keys.size():
			return
		_selected_item_key = _sell_item_keys[index]
	_update_detail()


# --- Detail panel ---


func _clear_detail() -> void:
	_selected_item_key = &""
	_quantity = 1
	_item_name_label.text = ""
	_item_desc_label.text = ""
	_price_label.text = ""
	_qty_value.text = "1"
	_total_label.text = ""
	_action_button.disabled = true
	_action_button.text = "Buy" if _is_buying else "Sell"


func _update_detail() -> void:
	var item_data: ItemData = Atlas.items.get(_selected_item_key) as ItemData
	if item_data == null:
		_clear_detail()
		return

	_item_name_label.text = item_data.name
	_item_desc_label.text = item_data.description

	var unit_price: int = _get_current_unit_price(item_data)
	_price_label.text = "%d Bits each" % unit_price if unit_price > 0 else "Free"
	_qty_value.text = str(_quantity)

	var total_cost: int = unit_price * _quantity
	_total_label.text = "Total: %d" % total_cost if total_cost > 0 else ""

	if _is_buying:
		_action_button.text = "Buy"
		_action_button.disabled = not _can_buy(total_cost)
	else:
		_action_button.text = "Sell"
		_action_button.disabled = not _can_sell()


func _get_current_unit_price(item_data: ItemData) -> int:
	if _is_buying and _shop:
		for stock_entry: Dictionary in _shop.stock:
			if stock_entry.get("item_key", &"") as StringName == _selected_item_key:
				return _get_buy_price(stock_entry, item_data)
	elif not _is_buying and _shop:
		return _get_sell_price(item_data)
	return 0


func _can_buy(total_cost: int) -> bool:
	if Game.state == null:
		return false
	return Game.state.inventory.bits >= total_cost


func _can_sell() -> bool:
	if Game.state == null:
		return false
	var owned: int = Game.state.inventory.items.get(_selected_item_key, 0)
	return owned >= _quantity


# --- Quantity controls ---


func _on_qty_minus() -> void:
	if _quantity > 1:
		_quantity -= 1
		_update_detail()


func _on_qty_plus() -> void:
	_quantity += 1
	_update_detail()


# --- Buy / Sell action ---


func _on_action_pressed() -> void:
	if Game.state == null:
		return
	if _selected_item_key == &"":
		return

	if _is_buying:
		_execute_buy()
	else:
		_execute_sell()


func _execute_buy() -> void:
	var item_data: ItemData = Atlas.items.get(_selected_item_key) as ItemData
	if item_data == null:
		return

	var unit_price: int = _get_current_unit_price(item_data)
	var total_cost: int = unit_price * _quantity

	if Game.state.inventory.bits < total_cost:
		return

	Game.state.inventory.bits -= total_cost
	var current: int = Game.state.inventory.items.get(_selected_item_key, 0)
	Game.state.inventory.items[_selected_item_key] = current + _quantity

	_update_bits_label()
	_update_detail()


func _execute_sell() -> void:
	var item_data: ItemData = Atlas.items.get(_selected_item_key) as ItemData
	if item_data == null:
		return

	var owned: int = Game.state.inventory.items.get(_selected_item_key, 0)
	if owned < _quantity:
		return

	var unit_price: int = _get_sell_price(item_data)
	var total_revenue: int = unit_price * _quantity

	Game.state.inventory.bits += total_revenue
	var new_qty: int = owned - _quantity
	if new_qty <= 0:
		Game.state.inventory.items.erase(_selected_item_key)
	else:
		Game.state.inventory.items[_selected_item_key] = new_qty

	_update_bits_label()
	_quantity = 1
	_build_sell_list()
	_clear_detail()
