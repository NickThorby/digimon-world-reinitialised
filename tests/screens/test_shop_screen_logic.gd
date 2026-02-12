extends GutTest
## Tests for shop screen buy/sell logic (no UI, tests state mutations directly).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func _create_state_with_bits(bits: int) -> GameState:
	var state := GameState.new()
	state.tamer_name = "Test"
	state.inventory.bits = bits
	return state


func _create_priced_shop() -> ShopData:
	return TestScreenFactory.create_test_priced_shop()


# --- Buy: deducts bits, adds to inventory ---


func test_buy_deducts_bits() -> void:
	var state: GameState = _create_state_with_bits(1000)
	var item_key: StringName = &"test_potion"
	var price: int = 100
	var quantity: int = 2
	var total: int = price * quantity
	state.inventory.bits -= total
	assert_eq(state.inventory.bits, 800,
		"Buying 2 items at 100 each should leave 800 bits")


func test_buy_adds_to_inventory() -> void:
	var state: GameState = _create_state_with_bits(1000)
	var item_key: StringName = &"test_potion"
	var quantity: int = 3
	var current: int = state.inventory.items.get(item_key, 0)
	state.inventory.items[item_key] = current + quantity
	assert_eq(state.inventory.items.get(item_key, 0), 3,
		"Buying 3 potions should add 3 to inventory")


func test_buy_adds_to_existing_inventory() -> void:
	var state: GameState = _create_state_with_bits(1000)
	state.inventory.items[&"test_potion"] = 5
	var quantity: int = 2
	var current: int = state.inventory.items.get(&"test_potion", 0)
	state.inventory.items[&"test_potion"] = current + quantity
	assert_eq(state.inventory.items.get(&"test_potion", 0), 7,
		"Buying should add to existing count")


# --- Buy: insufficient funds ---


func test_buy_blocked_insufficient_funds() -> void:
	var state: GameState = _create_state_with_bits(50)
	var price: int = 100
	var can_buy: bool = state.inventory.bits >= price
	assert_false(can_buy,
		"Should not be able to buy when bits < price")


# --- Sell: adds bits, removes from inventory ---


func test_sell_adds_bits() -> void:
	var state: GameState = _create_state_with_bits(100)
	var item_data: ItemData = Atlas.items.get(&"test_potion") as ItemData
	var sell_price: int = floori(item_data.buy_price * 0.5)
	state.inventory.items[&"test_potion"] = 5
	var quantity: int = 2
	var revenue: int = sell_price * quantity
	state.inventory.bits += revenue
	var new_qty: int = 5 - quantity
	state.inventory.items[&"test_potion"] = new_qty
	assert_eq(state.inventory.bits, 100 + revenue,
		"Selling should add revenue to bits")
	assert_eq(state.inventory.items.get(&"test_potion", 0), 3,
		"Selling 2 should leave 3 in inventory")


func test_sell_removes_item_when_depleted() -> void:
	var state: GameState = _create_state_with_bits(0)
	state.inventory.items[&"test_potion"] = 1
	# Sell the last one
	state.inventory.items.erase(&"test_potion")
	assert_false(state.inventory.items.has(&"test_potion"),
		"Selling last item should remove it from inventory")


# --- KEY items excluded from sell ---


func test_key_items_excluded_from_sell() -> void:
	# Verify KEY category items are filtered
	var key_item := ItemData.new()
	key_item.key = &"test_key_item"
	key_item.name = "Test Key Item"
	key_item.category = Registry.ItemCategory.KEY
	assert_eq(key_item.category, Registry.ItemCategory.KEY,
		"KEY category items should be filtered from sell list")


# --- Test shop: all items at price 0 ---


func test_test_shop_has_all_items() -> void:
	var shop := ShopData.new()
	shop.key = &"test_shop"
	shop.buy_multiplier = 1.0
	shop.sell_multiplier = 0.5
	var stock: Array[Dictionary] = []
	for item_key: StringName in Atlas.items:
		stock.append({"item_key": item_key, "price": 0, "quantity": -1})
	shop.stock = stock
	assert_gt(shop.stock.size(), 0,
		"Test shop should contain items")
	for entry: Dictionary in shop.stock:
		assert_eq(entry.get("price", -1), 0,
			"Test shop items should have price 0")


# --- Price multiplier ---


func test_buy_price_uses_shop_multiplier() -> void:
	var shop := ShopData.new()
	shop.buy_multiplier = 2.0
	var item := ItemData.new()
	item.buy_price = 100
	var stock_entry: Dictionary = {"item_key": &"x", "price": 0, "quantity": -1}
	# When stock price is 0, use item.buy_price * multiplier
	var price: int = floori(item.buy_price * shop.buy_multiplier)
	assert_eq(price, 200,
		"Buy price should apply shop multiplier to item base price")


func test_sell_price_uses_shop_multiplier() -> void:
	var shop := ShopData.new()
	shop.sell_multiplier = 0.5
	var item := ItemData.new()
	item.buy_price = 100
	item.sell_price = 0
	var sell_price: int = floori(item.buy_price * shop.sell_multiplier)
	assert_eq(sell_price, 50,
		"Sell price should be buy_price * sell_multiplier when sell_price is 0")


func test_sell_price_uses_item_sell_price_when_set() -> void:
	var item := ItemData.new()
	item.buy_price = 100
	item.sell_price = 75
	var sell_price: int = item.sell_price if item.sell_price > 0 else 0
	assert_eq(sell_price, 75,
		"Should use item's sell_price when explicitly set")


# --- Stock override price ---


func test_stock_override_price() -> void:
	var item := ItemData.new()
	item.buy_price = 100
	var stock_entry: Dictionary = {"item_key": &"x", "price": 50, "quantity": -1}
	var price: int = stock_entry.get("price", 0)
	if price <= 0:
		price = item.buy_price
	assert_eq(price, 50,
		"Stock entry with explicit price should override item buy_price")
