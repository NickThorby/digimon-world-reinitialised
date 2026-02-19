extends GutTest
## Unit tests for BattleEvolutionReverter.


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


func test_revert_single_evolution_restores_species() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var snapshot: Dictionary = digimon.to_dict()

	# Simulate evolution by changing key and adding history
	digimon.key = &"test_tank"
	digimon.evolution_history.append({
		"from_key": "test_agumon",
		"to_key": "test_tank",
		"evolution_type": Registry.EvolutionType.STANDARD,
		"evolution_item_key": "",
		"jogress_partners": [],
	})

	var evolutions: Array[Dictionary] = [{
		"source_state": digimon,
		"snapshot": snapshot,
	}]
	var party := PartyState.new()
	party.members = [digimon]
	var storage := StorageState.new()
	var inventory := InventoryState.new()

	BattleEvolutionReverter.revert_battle_evolutions(
		evolutions, party, storage, inventory,
	)

	assert_eq(
		digimon.key, &"test_agumon",
		"Species key should be reverted to pre-battle form",
	)
	assert_eq(
		digimon.evolution_history.size(), 0,
		"Evolution history should be restored from snapshot (empty)",
	)


func test_revert_preserves_hp_percentage() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var snapshot: Dictionary = digimon.to_dict()

	# Simulate evolution
	digimon.key = &"test_tank"
	digimon.evolution_history.append({
		"from_key": "test_agumon",
		"to_key": "test_tank",
		"evolution_type": Registry.EvolutionType.STANDARD,
		"evolution_item_key": "",
		"jogress_partners": [],
	})
	# Recalculate stats for new form
	var tank_data: DigimonData = Atlas.digimon.get(&"test_tank") as DigimonData
	var tank_stats: Dictionary = StatCalculator.calculate_all_stats(tank_data, digimon)
	var tank_max_hp: int = tank_stats.get(&"hp", 100) as int
	# Set HP to 50% of new form's max
	digimon.current_hp = tank_max_hp / 2

	var evolutions: Array[Dictionary] = [{
		"source_state": digimon,
		"snapshot": snapshot,
	}]
	var party := PartyState.new()
	party.members = [digimon]
	var storage := StorageState.new()
	var inventory := InventoryState.new()

	BattleEvolutionReverter.revert_battle_evolutions(
		evolutions, party, storage, inventory,
	)

	# After reversion, HP should be ~50% of the agumon form's max
	var agumon_data: DigimonData = Atlas.digimon.get(&"test_agumon") as DigimonData
	var agumon_stats: Dictionary = StatCalculator.calculate_all_stats(
		agumon_data, digimon,
	)
	var agumon_max_hp: int = agumon_stats.get(&"hp", 100) as int
	var expected_hp: int = maxi(floori(0.5 * float(agumon_max_hp)), 1)

	assert_almost_eq(
		float(digimon.current_hp), float(expected_hp), 2.0,
		"HP should be approximately 50%% of restored form's max",
	)


func test_revert_warp_chain_restores_original() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var snapshot: Dictionary = digimon.to_dict()

	# Simulate warp: agumon → tank → wall (two history entries)
	digimon.key = &"test_tank"
	digimon.evolution_history.append({
		"from_key": "test_agumon",
		"to_key": "test_tank",
		"evolution_type": Registry.EvolutionType.STANDARD,
		"evolution_item_key": "",
		"jogress_partners": [],
	})
	digimon.key = &"test_wall"
	digimon.evolution_history.append({
		"from_key": "test_tank",
		"to_key": "test_wall",
		"evolution_type": Registry.EvolutionType.STANDARD,
		"evolution_item_key": "",
		"jogress_partners": [],
	})

	var evolutions: Array[Dictionary] = [{
		"source_state": digimon,
		"snapshot": snapshot,
	}]
	var party := PartyState.new()
	party.members = [digimon]
	var storage := StorageState.new()
	var inventory := InventoryState.new()

	BattleEvolutionReverter.revert_battle_evolutions(
		evolutions, party, storage, inventory,
	)

	assert_eq(
		digimon.key, &"test_agumon",
		"Warp chain should be fully reverted to original species",
	)
	assert_eq(
		digimon.evolution_history.size(), 0,
		"All warp history entries should be removed",
	)


func test_revert_jogress_restores_partners_to_party() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_gabumon", 50,
	)
	var partner_snapshot: Dictionary = partner.to_dict()
	var snapshot: Dictionary = digimon.to_dict()

	# Simulate jogress: agumon + gabumon → wall
	digimon.key = &"test_wall"
	digimon.evolution_history.append({
		"from_key": "test_agumon",
		"to_key": "test_wall",
		"evolution_type": Registry.EvolutionType.JOGRESS,
		"evolution_item_key": "",
		"jogress_partners": [partner_snapshot],
	})

	var party := PartyState.new()
	party.members = [digimon]  # Partner was consumed — only result remains
	var storage := StorageState.new()
	var inventory := InventoryState.new()

	var evolutions: Array[Dictionary] = [{
		"source_state": digimon,
		"snapshot": snapshot,
	}]

	BattleEvolutionReverter.revert_battle_evolutions(
		evolutions, party, storage, inventory,
	)

	assert_eq(
		digimon.key, &"test_agumon",
		"Should revert to original species",
	)
	assert_eq(
		party.members.size(), 2,
		"Consumed jogress partner should be restored to party",
	)
	# Find the restored partner
	var found_partner: bool = false
	for member: DigimonState in party.members:
		if member.key == &"test_gabumon" and member != digimon:
			found_partner = true
	assert_true(found_partner, "Restored partner should be test_gabumon")


func test_revert_jogress_partners_to_storage_when_party_full() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var partner: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_gabumon", 50,
	)
	var partner_snapshot: Dictionary = partner.to_dict()
	var snapshot: Dictionary = digimon.to_dict()

	# Simulate jogress
	digimon.key = &"test_wall"
	digimon.evolution_history.append({
		"from_key": "test_agumon",
		"to_key": "test_wall",
		"evolution_type": Registry.EvolutionType.JOGRESS,
		"evolution_item_key": "",
		"jogress_partners": [partner_snapshot],
	})

	# Fill party to max (6)
	var party := PartyState.new()
	party.members = [digimon]
	for i: int in 5:
		party.members.append(
			TestBattleFactory.make_digimon_state(&"test_patamon", 10),
		)

	var storage := StorageState.new()
	var inventory := InventoryState.new()

	var evolutions: Array[Dictionary] = [{
		"source_state": digimon,
		"snapshot": snapshot,
	}]

	BattleEvolutionReverter.revert_battle_evolutions(
		evolutions, party, storage, inventory,
	)

	assert_eq(
		party.members.size(), 6,
		"Party should remain at max size",
	)
	# Partner should be in storage
	var slot_info: Dictionary = {}
	for box_i: int in storage.get_box_count():
		for slot_i: int in (storage.boxes[box_i]["slots"] as Array).size():
			var stored: DigimonState = storage.get_digimon(box_i, slot_i)
			if stored != null and stored.key == &"test_gabumon":
				slot_info = {"box": box_i, "slot": slot_i}
				break
		if not slot_info.is_empty():
			break
	assert_false(
		slot_info.is_empty(),
		"Partner should be placed in storage when party is full",
	)


func test_revert_returns_consumed_evolution_items() -> void:
	var digimon: DigimonState = TestBattleFactory.make_digimon_state(
		&"test_agumon", 50,
	)
	var snapshot: Dictionary = digimon.to_dict()

	# Simulate evolution that consumed an item
	digimon.key = &"test_speedster"
	digimon.evolution_item_key = &"test_digimental_courage"
	digimon.evolution_history.append({
		"from_key": "test_agumon",
		"to_key": "test_speedster",
		"evolution_type": Registry.EvolutionType.ARMOR,
		"evolution_item_key": "test_digimental_courage",
		"jogress_partners": [],
	})

	var party := PartyState.new()
	party.members = [digimon]
	var storage := StorageState.new()
	var inventory := InventoryState.new()
	inventory.items[&"test_digimental_courage"] = 0

	var evolutions: Array[Dictionary] = [{
		"source_state": digimon,
		"snapshot": snapshot,
	}]

	BattleEvolutionReverter.revert_battle_evolutions(
		evolutions, party, storage, inventory,
	)

	assert_eq(
		int(inventory.items.get(&"test_digimental_courage", 0)), 1,
		"Consumed evolution item should be returned to inventory",
	)
