extends GutTest
## Unit tests for InventoryState — bits field and serialisation.


# --- bits field ---


func test_bits_default_zero() -> void:
	var inv := InventoryState.new()
	assert_eq(inv.bits, 0, "Default bits should be 0")


func test_bits_assignment() -> void:
	var inv := InventoryState.new()
	inv.bits = 5000
	assert_eq(inv.bits, 5000, "bits should be assignable")


# --- Serialisation ---


func test_serialisation_round_trip() -> void:
	var inv := InventoryState.new()
	inv.bits = 12345
	inv.items[&"test_potion"] = 10
	inv.items[&"test_energy_drink"] = 3

	var data: Dictionary = inv.to_dict()
	var restored: InventoryState = InventoryState.from_dict(data)

	assert_eq(restored.bits, 12345, "bits should persist through serialisation")
	assert_eq(int(restored.items.get(&"test_potion", 0)), 10,
		"Item quantities should persist")
	assert_eq(int(restored.items.get(&"test_energy_drink", 0)), 3,
		"Item quantities should persist")


func test_serialisation_key_is_bits() -> void:
	var inv := InventoryState.new()
	inv.bits = 999
	var data: Dictionary = inv.to_dict()
	assert_true(data.has("bits"), "Serialised key should be 'bits'")
	assert_false(data.has("money"), "Should not have old 'money' key")
	assert_eq(int(data["bits"]), 999, "bits value should match")


# --- Backward compatibility ---


func test_from_dict_reads_money_fallback() -> void:
	# Legacy save data uses "money" key
	var data: Dictionary = {
		"items": {},
		"money": 7777,
	}
	var restored: InventoryState = InventoryState.from_dict(data)
	assert_eq(restored.bits, 7777,
		"from_dict should read 'money' as fallback for 'bits'")


func test_from_dict_prefers_bits_over_money() -> void:
	# If both exist, "bits" should win
	var data: Dictionary = {
		"items": {},
		"bits": 5000,
		"money": 3000,
	}
	var restored: InventoryState = InventoryState.from_dict(data)
	assert_eq(restored.bits, 5000,
		"from_dict should prefer 'bits' over 'money' when both exist")


func test_from_dict_empty_defaults() -> void:
	var restored: InventoryState = InventoryState.from_dict({})
	assert_eq(restored.bits, 0, "Default bits from empty dict should be 0")
	assert_eq(restored.items.size(), 0, "Default items from empty dict should be empty")
